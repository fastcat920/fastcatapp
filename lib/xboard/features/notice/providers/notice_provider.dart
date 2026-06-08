import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/notice_state.dart';

const _kDismissedNoticeIdsKey = 'xboard_dismissed_notice_ids';
const _kNoticeCacheKey = 'xboard_notice_cache_v1';
const _kPopupShownIdsKey = 'xboard_popup_shown_notice_ids';

/// 公告状态
class NoticeState {
  final List<DomainNotice> notices;
  final bool isLoading;
  final String? error;

  /// 已关闭的公告 ID 集合（基于 notice.id，重启后持久保留）
  final Set<int> dismissedIds;

  /// 已弹窗过的公告 ID 集合（基于 notice.id，重启后持久保留）
  final Set<int> popupShownIds;

  /// 待弹窗公告 ID（非 null 时触发弹窗，弹窗后清空）
  final int? popupNoticeId;

  const NoticeState({
    this.notices = const [],
    this.isLoading = false,
    this.error,
    this.dismissedIds = const {},
    this.popupShownIds = const {},
    this.popupNoticeId,
  });

  /// 获取可见的公告列表（排除已关闭 + isVisible=false 的）
  List<DomainNotice> get visibleNotices {
    return notices
        .where((n) => n.isVisible && !dismissedIds.contains(n.id))
        .toList();
  }

  /// 获取需要弹窗的公告（带"弹窗"标签、可见、未被弹窗过，按创建时间降序）
  List<DomainNotice> get popupNotices {
    return notices
        .where((n) =>
            n.isVisible &&
            n.tags.contains('弹窗') &&
            !popupShownIds.contains(n.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  NoticeState copyWith({
    List<DomainNotice>? notices,
    bool? isLoading,
    String? error,
    Set<int>? dismissedIds,
    Set<int>? popupShownIds,
    int? popupNoticeId,
  }) {
    return NoticeState(
      notices: notices ?? this.notices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      popupShownIds: popupShownIds ?? this.popupShownIds,
      popupNoticeId: popupNoticeId ?? this.popupNoticeId,
    );
  }
}

/// 公告Provider
class NoticeNotifier extends StateNotifier<NoticeState> {
  NoticeNotifier(this._ref) : super(const NoticeState()) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>(() async {
        await _loadDismissedIds();
        await _loadPopupShownIds();
        await _loadCachedNotices();
      });
    });
  }

  final Ref _ref;
  DateTime? _lastFetchedAt;

  /// 启动时从 SharedPrefs 加载已关闭的公告 ID
  Future<void> _loadDismissedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_kDismissedNoticeIdsKey) ?? [];
      final idSet = ids.map((e) => int.tryParse(e)).whereType<int>().toSet();
      if (idSet.isNotEmpty) {
        state = state.copyWith(dismissedIds: idSet);
      }
    } catch (_) {}
  }

  /// 获取公告列表（5 分钟内有缓存时跳过重复请求）
  Future<void> fetchNotices({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    // 缓存命中：已有数据且未超过 5 分钟，且不是强制刷新
    if (!forceRefresh &&
        state.notices.isNotEmpty &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inMinutes < 5) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    debugPrint('[弹窗] fetchNotices 开始加载公告...');

    try {
      if (forceRefresh) {
        clearGetNoticesCache();
        _ref.invalidate(getNoticesProvider);
      }
      final noticeModels = await _ref.read(getNoticesProvider.future);
      final notices = noticeModels.map(_mapNotice).toList();
      _lastFetchedAt = DateTime.now();
      await _saveCachedNotices(notices);
      final newState = state.copyWith(
        notices: notices,
        isLoading: false,
      );
      final popupList = newState.popupNotices;
      state = newState.copyWith(
        popupNoticeId: popupList.isNotEmpty ? popupList.first.id : null,
      );
      debugPrint(
          '[弹窗] fetchNotices 完成，共 ${notices.length} 条公告, popupNoticeId=${popupList.isNotEmpty ? popupList.first.id : "null"}, popupShownIds=${newState.popupShownIds}');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        popupNoticeId: null,
      );
    }
  }

  Future<void> _loadCachedNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNoticeCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final notices = decoded
          .whereType<Map>()
          .map((e) =>
              DomainNotice.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
      if (notices.isNotEmpty && state.notices.isEmpty) {
        state = state.copyWith(notices: notices);
        debugPrint('[弹窗] _loadCachedNotices 加载缓存: ${notices.length} 条');
      }
    } catch (_) {}
  }

  Future<void> _saveCachedNotices(List<DomainNotice> notices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = notices.map((e) => e.toJson()).toList();
      await prefs.setString(_kNoticeCacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  /// 从 SharedPrefs 加载已弹窗的公告 ID
  Future<void> _loadPopupShownIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_kPopupShownIdsKey) ?? [];
      final idSet = ids.map((e) => int.tryParse(e)).whereType<int>().toSet();
      if (idSet.isNotEmpty) {
        state = state.copyWith(popupShownIds: idSet);
      }
      debugPrint('[弹窗] _loadPopupShownIds 加载完成: $idSet');
    } catch (e) {
      debugPrint('[弹窗] _loadPopupShownIds 失败: $e');
    }
  }

  /// 标记公告已弹窗（按 notice.id，持久化到 SharedPrefs）
  Future<void> markPopupShown(int noticeId) async {
    final newIds = Set<int>.from(state.popupShownIds)..add(noticeId);
    state = state.copyWith(popupShownIds: newIds, popupNoticeId: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kPopupShownIdsKey,
        newIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  /// 关闭公告横幅（按 notice.id，持久化到 SharedPrefs）
  Future<void> dismissBanner(int noticeId) async {
    final newIds = Set<int>.from(state.dismissedIds)..add(noticeId);
    state = state.copyWith(dismissedIds: newIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kDismissedNoticeIdsKey,
        newIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }
}

/// 公告Provider实例
final noticeProvider =
    StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  return NoticeNotifier(ref);
});

DomainNotice _mapNotice(NoticeModel notice) {
  return DomainNotice(
    id: notice.id,
    title: notice.title,
    content: notice.content,
    imageUrls: notice.imgUrl != null && notice.imgUrl!.isNotEmpty
        ? [notice.imgUrl!]
        : [],
    tags: notice.tags ?? [],
    isVisible: notice.show,
    createdAt: DateTime.fromMillisecondsSinceEpoch(notice.createdAt * 1000),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(notice.updatedAt * 1000),
  );
}
