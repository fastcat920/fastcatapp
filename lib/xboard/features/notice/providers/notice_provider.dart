import 'notice_cache.dart';
import 'notice_bootstrap.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/core/content_locale.dart';
import 'package:fl_clash/state.dart';

import 'package:fl_clash/xboard/infrastructure/cache/content_cache_scope.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/notice_state.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';

const _kDismissedNoticeIdsKey = 'xboard_dismissed_notice_ids';
const _kNoticeCacheKey = 'xboard_notice_cache_v1';
const _kPopupShownIdsKey = 'xboard_popup_shown_notice_ids';
const _unchangedPopup = Object();

/// 公告状态
class NoticeState {
  final List<DomainNotice> notices;
  final bool isLoading;
  final bool hasSnapshot;
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
    this.hasSnapshot = false,
    this.error,
    this.dismissedIds = const {},
    this.popupShownIds = const {},
    this.popupNoticeId,
  });

  bool get isWaiting => isLoading || (!hasSnapshot && error == null);

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
    bool? hasSnapshot,
    String? error,
    Set<int>? dismissedIds,
    Set<int>? popupShownIds,
    Object? popupNoticeId = _unchangedPopup,
  }) {
    return NoticeState(
      notices: notices ?? this.notices,
      isLoading: isLoading ?? this.isLoading,
      hasSnapshot: hasSnapshot ?? this.hasSnapshot,
      error: error,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      popupShownIds: popupShownIds ?? this.popupShownIds,
      popupNoticeId: identical(popupNoticeId, _unchangedPopup)
          ? this.popupNoticeId
          : popupNoticeId as int?,
    );
  }
}

NoticeBootstrap? _eligibleBootstrap(Ref ref) {
  final initial = ref.read(initialNoticeBootstrapProvider);
  final user = ref.read(xboardUserProvider);
  if (initial == null ||
      !user.isAuthenticated ||
      user.email?.trim().toLowerCase() != initial.email ||
      xboardContentLocale(globalState.config.appSetting.locale) !=
          initial.locale) {
    return null;
  }
  return initial;
}

NoticeState _initialNoticeState(Ref ref) {
  final initial = _eligibleBootstrap(ref);
  if (initial == null) return const NoticeState(isLoading: true);
  final restored = NoticeState(
      notices: initial.record.notices,
      hasSnapshot: true,
      dismissedIds: initial.dismissed,
      popupShownIds: initial.shown);
  return restored.copyWith(
      popupNoticeId: restored.popupNotices.firstOrNull?.id);
}

/// 公告Provider
class NoticeNotifier extends StateNotifier<NoticeState> {
  NoticeNotifier(this._ref) : super(_initialNoticeState(_ref)) {
    final initial = _eligibleBootstrap(_ref);
    if (initial != null) {
      _scope = initial.scope;
      _legacyScope = initial.legacyScope;
      _hydratedScope = initial.scope;
      _lastFetchedAt = initial.record.savedAt;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>(() async {
        await fetchNotices();
      });
    });
  }

  void accountChanged(bool authenticated) {
    _scope = null;
    _legacyScope = null;
    _hydratedScope = null;
    _lastFetchedAt = null;
    state = NoticeState(isLoading: authenticated);
    // Account data is restored asynchronously on every platform. Retry when
    // identity arrives rather than relying on a one-shot startup timer.
    Future<void>(() async {
      if (mounted) await fetchNotices();
    });
  }

  final Ref _ref;
  String? _scope;
  String? _legacyScope;
  String? _hydratedScope;

  Future<String?> _currentScope() async {
    final user = _ref.read(xboardUserProvider);
    if (!user.isAuthenticated || user.email == null || user.email!.isEmpty) {
      return null;
    }
    final sources = await noticeSourceIdentity();
    return noticeCacheScope(
        sources: sources,
        email: user.email!,
        locale: xboardContentLocale(globalState.config.appSetting.locale));
  }

  Future<bool> _ensureScope() async {
    final scope = await _currentScope();
    if (!mounted) return false;
    if (scope != _scope) {
      _scope = scope;
      _legacyScope = await ContentCacheScope.current();
      _hydratedScope = null;
      _lastFetchedAt = null;
      state = const NoticeState(isLoading: true);
    }
    _legacyScope ??= await ContentCacheScope.current();
    return scope != null;
  }

  Future<bool> _isCurrent(String? scope) async {
    if (!mounted || scope == null || scope != _scope) return false;
    final current = await _currentScope();
    return mounted && scope == _scope && scope == current;
  }

  String? get currentScope => _scope;
  DateTime? _lastFetchedAt;
  Future<void>? _fetchInFlight;

  /// 启动时从 SharedPrefs 加载已关闭的公告 ID
  Future<void> _loadDismissedIds() async {
    try {
      final scope = _scope;
      final prefs = await SharedPreferences.getInstance();
      if (!await _isCurrent(scope)) return;
      final ids = prefs.getStringList('$_kDismissedNoticeIdsKey:$scope') ??
          prefs.getStringList('$_kDismissedNoticeIdsKey:$_legacyScope') ??
          [];
      final idSet = ids.map((e) => int.tryParse(e)).whereType<int>().toSet();
      if (prefs.getStringList('$_kDismissedNoticeIdsKey:$scope') == null &&
          idSet.isNotEmpty) {
        await prefs.setStringList('$_kDismissedNoticeIdsKey:$scope', ids);
      }
      if (!await _isCurrent(scope)) return;
      if (idSet.isNotEmpty) {
        state = state.copyWith(dismissedIds: idSet);
      }
    } catch (_) {}
  }

  /// 获取公告列表（5 分钟内有缓存时跳过重复请求）
  Future<void> fetchNotices({bool forceRefresh = false}) {
    final inFlight = _fetchInFlight;
    if (inFlight != null) {
      // A locale change can arrive while the previous-language request is
      // still running. Wait for it, then force a second request so the stale
      // response can never win the race or activate the five-minute cache.
      return _refreshAfterScopeCheck(inFlight);
    }

    final operation = _fetchNotices(forceRefresh: forceRefresh);
    _fetchInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_fetchInFlight, operation)) {
        _fetchInFlight = null;
      }
    });
  }

  Future<void> _refreshAfterScopeCheck(Future<void> operation) async {
    final requestedScope = await _currentScope();
    await operation;
    if (!mounted) return;
    if (requestedScope != _scope && requestedScope == await _currentScope()) {
      await fetchNotices(forceRefresh: true);
    }
  }

  Future<void> _fetchNotices({required bool forceRefresh}) async {
    if (!await _ensureScope()) {
      if (mounted) {
        state = state.copyWith(
            isLoading: _ref.read(xboardUserProvider).isAuthenticated &&
                !state.hasSnapshot);
      }
      return;
    }
    final scope = _scope;
    await _loadDismissedIds();
    await _loadPopupShownIds();
    // Restore persisted content before starting any network request. Refreshes
    // keep the current content visible, including when the request fails.
    await _loadCachedNotices();
    if (!await _isCurrent(scope)) return;
    // 缓存命中：已有数据且未超过 5 分钟，且不是强制刷新
    if (!forceRefresh &&
        state.hasSnapshot &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inMinutes < 5) {
      return;
    }

    state = state.copyWith(isLoading: !state.hasSnapshot, error: null);
    debugPrint('[弹窗] fetchNotices 开始加载公告...');

    try {
      if (forceRefresh) {
        clearGetNoticesCache();
        _ref.invalidate(getNoticesProvider);
      }
      final noticeModels = await _ref.read(getNoticesProvider.future);
      if (!await _isCurrent(scope)) return;
      final notices = noticeModels.map(_mapNotice).toList();
      _ref.read(serviceConnectivityProvider.notifier).reportRequestSuccess();
      _lastFetchedAt = DateTime.now();
      await _saveCachedNotices(notices);
      if (!await _isCurrent(scope)) return;
      final newState = state.copyWith(
        notices: notices,
        hasSnapshot: true,
        isLoading: false,
      );
      final popupList = newState.popupNotices;
      final popupId = popupList.firstOrNull?.id;
      if (state.hasSnapshot &&
          !state.isLoading &&
          state.error == null &&
          listEquals(state.notices, notices) &&
          state.popupNoticeId == popupId) {
        return;
      }
      state = newState.copyWith(
        popupNoticeId: popupList.isNotEmpty ? popupList.first.id : null,
      );
      debugPrint(
          '[弹窗] fetchNotices 完成，共 ${notices.length} 条公告, popupNoticeId=${popupList.isNotEmpty ? popupList.first.id : "null"}, popupShownIds=${newState.popupShownIds}');
    } catch (e) {
      if (!await _isCurrent(scope)) return;
      _ref.read(serviceConnectivityProvider.notifier).reportRequestFailure(e);
      await _loadCachedNotices();
      if (!await _isCurrent(scope)) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _loadCachedNotices() async {
    try {
      final scope = _scope;
      if (_hydratedScope == scope) return;
      final prefs = await SharedPreferences.getInstance();
      if (!await _isCurrent(scope)) return;
      _hydratedScope = scope;
      final raw = prefs.getString('$_kNoticeCacheKey:$scope') ??
          prefs.getString('$_kNoticeCacheKey:$_legacyScope');
      if (raw == null || raw.isEmpty) return;
      final cached = NoticeCacheRecord.decode(raw, DateTime.now());
      _lastFetchedAt = cached.savedAt;
      final notices = cached.notices;
      if (!state.hasSnapshot) {
        final restored = state.copyWith(
            notices: notices, hasSnapshot: true, isLoading: false);
        state = restored.copyWith(
            popupNoticeId: restored.popupNotices.firstOrNull?.id);
      }
    } catch (_) {}
  }

  Future<void> _saveCachedNotices(List<DomainNotice> notices) async {
    try {
      final scope = _scope;
      final prefs = await SharedPreferences.getInstance();
      if (!await _isCurrent(scope)) return;
      final record = NoticeCacheRecord(notices, DateTime.now());
      await prefs.setString('$_kNoticeCacheKey:$scope', record.encode());
      // Bound stale account/language caches. Old unscoped content must not leak.
      final scopedKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('$_kNoticeCacheKey:'))
          .toList();
      while (scopedKeys.length > 8) {
        final old =
            scopedKeys.firstWhere((key) => key != '$_kNoticeCacheKey:$scope');
        scopedKeys.remove(old);
        final oldScope = old.substring(_kNoticeCacheKey.length + 1);
        await prefs.remove(old);
        await prefs.remove('$_kDismissedNoticeIdsKey:$oldScope');
        await prefs.remove('$_kPopupShownIdsKey:$oldScope');
      }
      await prefs.remove(_kNoticeCacheKey);
    } catch (_) {}
  }

  /// 从 SharedPrefs 加载已弹窗的公告 ID
  Future<void> _loadPopupShownIds() async {
    try {
      final scope = _scope;
      final prefs = await SharedPreferences.getInstance();
      if (!await _isCurrent(scope)) return;
      final ids = prefs.getStringList('$_kPopupShownIdsKey:$scope') ??
          prefs.getStringList('$_kPopupShownIdsKey:$_legacyScope') ??
          [];
      final idSet = ids.map((e) => int.tryParse(e)).whereType<int>().toSet();
      if (prefs.getStringList('$_kPopupShownIdsKey:$scope') == null &&
          idSet.isNotEmpty) {
        await prefs.setStringList('$_kPopupShownIdsKey:$scope', ids);
      }
      if (!await _isCurrent(scope)) return;
      if (idSet.isNotEmpty) {
        state = state.copyWith(popupShownIds: idSet);
      }
      debugPrint('[弹窗] _loadPopupShownIds 加载完成: $idSet');
    } catch (e) {
      debugPrint('[弹窗] _loadPopupShownIds 失败: $e');
    }
  }

  /// 标记公告已弹窗（按 notice.id，持久化到 SharedPrefs）
  Future<void> markPopupShown(int noticeId, {String? expectedScope}) async {
    if (expectedScope != null && expectedScope != _scope) return;
    final newIds = Set<int>.from(state.popupShownIds)..add(noticeId);
    state = state.copyWith(
        popupShownIds: newIds,
        popupNoticeId:
            state.popupNoticeId == noticeId ? null : state.popupNoticeId);
    try {
      final scope = _scope;
      final prefs = await SharedPreferences.getInstance();
      if (!await _isCurrent(scope)) return;
      await prefs.setStringList(
        '$_kPopupShownIdsKey:$scope',
        newIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  /// 关闭公告横幅（按 notice.id，持久化到 SharedPrefs）
  Future<void> dismissBanner(int noticeId) async {
    final newIds = Set<int>.from(state.dismissedIds)..add(noticeId);
    state = state.copyWith(dismissedIds: newIds);
    try {
      final scope = _scope;
      final prefs = await SharedPreferences.getInstance();
      if (!await _isCurrent(scope)) return;
      await prefs.setStringList(
        '$_kDismissedNoticeIdsKey:$scope',
        newIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }
}

/// 公告Provider实例
final noticeProvider =
    StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  final notifier = NoticeNotifier(ref);
  ref.listen(
    xboardUserProvider.select(
        (user) => (user.isAuthenticated, user.email?.trim().toLowerCase())),
    (previous, next) => notifier.accountChanged(next.$1),
  );
  return notifier;
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
