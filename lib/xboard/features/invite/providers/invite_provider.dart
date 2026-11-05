import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/invite_state.dart';
import 'package:fl_clash/xboard/adapter/state/user_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/utils/backend_message_mapper.dart';
import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/content_cache_scope.dart';

// 初始化文件级日志器
const _logger = FileLogger('invite_provider.dart');

String formatInviteAmount(double amount, {bool showDecimals = true}) {
  if (showDecimals) return '¥${amount.toStringAsFixed(2)}';
  return '¥${amount.truncate()}';
}

class InviteState {
  final DomainInvite? inviteData;
  final List<DomainCommission> commissionHistory;
  final DomainUser? userInfo;
  final bool isLoading;
  final bool isGenerating;
  final bool isLoadingHistory;
  final String? errorMessage;
  final int currentHistoryPage;
  final bool hasMoreHistory;
  final int historyPageSize;
  final bool isWithdrawConfigLoaded;
  final bool withdrawEnabled;
  final List<String> withdrawMethods;

  const InviteState({
    this.inviteData,
    this.commissionHistory = const [],
    this.userInfo,
    this.isLoading = false,
    this.isGenerating = false,
    this.isLoadingHistory = false,
    this.errorMessage,
    this.currentHistoryPage = 1,
    this.hasMoreHistory = true,
    this.historyPageSize = 10,
    this.isWithdrawConfigLoaded = false,
    this.withdrawEnabled = false,
    this.withdrawMethods = const [],
  });

  InviteState copyWith({
    DomainInvite? inviteData,
    List<DomainCommission>? commissionHistory,
    DomainUser? userInfo,
    bool? isLoading,
    bool? isGenerating,
    bool? isLoadingHistory,
    String? errorMessage,
    int? currentHistoryPage,
    bool? hasMoreHistory,
    int? historyPageSize,
    bool? isWithdrawConfigLoaded,
    bool? withdrawEnabled,
    List<String>? withdrawMethods,
  }) {
    return InviteState(
      inviteData: inviteData ?? this.inviteData,
      commissionHistory: commissionHistory ?? this.commissionHistory,
      userInfo: userInfo ?? this.userInfo,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      errorMessage: errorMessage,
      currentHistoryPage: currentHistoryPage ?? this.currentHistoryPage,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      historyPageSize: historyPageSize ?? this.historyPageSize,
      isWithdrawConfigLoaded:
          isWithdrawConfigLoaded ?? this.isWithdrawConfigLoaded,
      withdrawEnabled: withdrawEnabled ?? this.withdrawEnabled,
      withdrawMethods: withdrawMethods ?? this.withdrawMethods,
    );
  }

  bool get hasInviteData => inviteData != null;
  bool get hasActiveCodes =>
      inviteData?.codes.any((code) => code.isAvailable) ?? false;
  int get totalInvites => inviteData?.stats.invitedCount ?? 0;
  double get totalCommission => inviteData?.stats.totalCommission ?? 0.0;
  double get pendingCommission => inviteData?.stats.pendingCommission ?? 0.0;
  double get commissionRate => inviteData?.stats.commissionRate ?? 0.0;
  double get availableCommission {
    final commissionBalance = userInfo?.commissionBalanceInCents;
    if (commissionBalance != null) return commissionBalance / 100.0;
    return inviteData?.stats.availableCommission ?? 0.0;
  }

  double get walletBalance => (userInfo?.balanceInCents ?? 0) / 100.0;
  bool get isWithdrawEnabled => withdrawEnabled && withdrawMethods.isNotEmpty;
  String get formattedCommission => formatInviteAmount(totalCommission);
  String get wholeCommission =>
      formatInviteAmount(totalCommission, showDecimals: false);
  String get formattedPendingCommission =>
      formatInviteAmount(pendingCommission);
  String get wholePendingCommission =>
      formatInviteAmount(pendingCommission, showDecimals: false);
  String get formattedAvailableCommission {
    if (userInfo == null && inviteData == null) return '···';
    return formatInviteAmount(availableCommission);
  }

  String get wholeAvailableCommission {
    if (userInfo == null && inviteData == null) return '···';
    return formatInviteAmount(availableCommission, showDecimals: false);
  }

  String get formattedWalletBalance {
    if (userInfo == null) return '···';
    return formatInviteAmount(walletBalance);
  }

  String get wholeWalletBalance {
    if (userInfo == null) return '···';
    return formatInviteAmount(walletBalance, showDecimals: false);
  }
}

class InviteNotifier extends Notifier<InviteState> {
  bool _disposed = false;
  bool _hasBuilt = false;

  bool _isCurrent(int epoch) =>
      !_disposed && ref.read(sessionEpochProvider) == epoch;

  @override
  InviteState build() {
    final epoch = ref.watch(sessionEpochProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // 用全局缓存的用户信息预填充余额，使余额卡片无需等邀请 API 即可立即展示
    final cachedUser = _hasBuilt ? null : ref.read(userInfoProvider);
    _hasBuilt = true;

    // 若 userInfoProvider 在之后才加载完成（首次启动极快进入），同步更新
    ref.listen<DomainUser?>(userInfoProvider, (_, next) {
      if (next != null && next != state.userInfo) {
        Future<void>(() {
          if (!_isCurrent(epoch)) return;
          state = state.copyWith(userInfo: next);
        });
      }
    });

    Future<void>(() async {
      try {
        if (_isCurrent(epoch)) await _loadCachedInviteState();
      } catch (error) {
        _logger.info('邀请缓存不可用，将使用在线数据: $error');
      }
    });
    return InviteState(
      userInfo: cachedUser, // 有缓存则余额卡片立即显示正确值
      isLoading:
          false, // 必须 false：loadInviteData() 内有 if(isLoading) return 防并发，
      // 若初始为 true 则首次调用会被自己挡住，永远无法加载
    );
  }

  Future<void> _loadCachedInviteState() async {
    final epoch = ref.read(sessionEpochProvider);
    if (state.hasInviteData) return;
    final scope = await ContentCacheScope.current();
    if (!_isCurrent(epoch) || scope == null) return;
    final storage = ref.read(storageServiceProvider);
    final results = await Future.wait([
      storage.getDomainInvite(scope: scope),
      storage.getDomainCommissionHistory(scope: scope),
    ]);
    if (!_isCurrent(epoch) || state.hasInviteData) return;
    final cachedInvite = results[0].dataOrNull as DomainInvite?;
    final cachedHistory =
        results[1].dataOrNull as List<DomainCommission>? ?? const [];
    if (cachedInvite == null && cachedHistory.isEmpty) {
      return;
    }
    state = state.copyWith(
      inviteData: cachedInvite,
      commissionHistory: cachedHistory,
      isLoading: false,
      isLoadingHistory: false,
      errorMessage: null,
      hasMoreHistory: cachedHistory.length >= state.historyPageSize,
    );
  }

  Future<void> loadInviteData() async {
    final epoch = ref.read(sessionEpochProvider);
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _logger.info('加载邀请信息...');
      ref.invalidate(getInviteInfoProvider);
      final inviteInfoModel = await ref.read(getInviteInfoProvider.future);
      if (!_isCurrent(epoch)) return;
      final inviteData = _mapInviteInfo(inviteInfoModel);

      state = state.copyWith(
        inviteData: inviteData,
        isLoading: false,
      );
      unawaited(_saveInviteCache(epoch, inviteData: inviteData));

      _logger.info('邀请信息加载成功');
    } catch (e) {
      if (!_isCurrent(epoch)) return;
      _logger.info('加载邀请信息失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadWithdrawConfig() async {
    final epoch = ref.read(sessionEpochProvider);
    final config = await _fetchWithdrawConfig();
    if (!_isCurrent(epoch)) return;
    state = state.copyWith(
      isWithdrawConfigLoaded: true,
      withdrawEnabled: config.enabled,
      withdrawMethods: config.enabled ? config.methods : const [],
    );
  }

  Future<void> loadCommissionHistory(
      {int page = 1, bool append = false}) async {
    final epoch = ref.read(sessionEpochProvider);
    if (state.isLoadingHistory) return;

    state = state.copyWith(isLoadingHistory: true);

    try {
      _logger.info('加载佣金历史... 页码: $page');
      final commissionList =
          await ref.read(getCommissionDetailsProvider(page: page).future);
      if (!_isCurrent(epoch)) return;
      final newHistory = commissionList.map(_mapCommission).toList();

      List<DomainCommission> updatedHistory;
      if (append && newHistory.isNotEmpty) {
        // 追加到现有列表
        updatedHistory = [...state.commissionHistory, ...newHistory];
      } else {
        // 替换整个列表
        updatedHistory = newHistory;
      }

      state = state.copyWith(
        commissionHistory: updatedHistory,
        currentHistoryPage: page,
        hasMoreHistory: newHistory.length >= state.historyPageSize,
        isLoadingHistory: false,
      );
      if (page == 1) {
        unawaited(_saveInviteCache(epoch, history: updatedHistory));
      }

      _logger.info('佣金历史加载成功: 第$page页，${newHistory.length} 条记录');
    } catch (e) {
      if (!_isCurrent(epoch)) return;
      _logger.info('加载佣金历史失败: $e');
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> loadNextHistoryPage() async {
    if (!state.hasMoreHistory || state.isLoadingHistory) return;
    await loadCommissionHistory(
        page: state.currentHistoryPage + 1, append: true);
  }

  Future<void> refreshCommissionHistory() async {
    await loadCommissionHistory(page: 1, append: false);
  }

  Future<void> loadUserInfo({bool forceRefresh = false}) async {
    final epoch = ref.read(sessionEpochProvider);
    try {
      _logger.info('加载用户信息...');
      if (forceRefresh) {
        clearGetUserInfoCache();
        ref.invalidate(getUserInfoProvider);
      }
      final userModel = await ref.read(getUserInfoProvider.future);
      if (!_isCurrent(epoch)) return;
      final userInfo = _mapUser(userModel);
      state = state.copyWith(userInfo: userInfo);
      ref.read(userInfoProvider.notifier).state = userInfo;
      unawaited(_saveUserCache(epoch, userInfo));
      _logger.info('用户信息加载成功: 钱包余额 ¥${userInfo.balanceInCents / 100.0}');
    } catch (e) {
      _logger.info('加载用户信息失败: $e');
    }
  }

  Future<DomainInviteCode?> generateInviteCode() async {
    final epoch = ref.read(sessionEpochProvider);
    if (state.isGenerating) return null;

    state = state.copyWith(isGenerating: true, errorMessage: null);

    try {
      _logger.info('生成邀请码...');
      final sdk = await ref.read(xboardSdkProvider.future);
      if (!_isCurrent(epoch)) return null;
      final codeString = await sdk.invite.generateInviteCode();
      if (!_isCurrent(epoch)) return null;

      // SDK returns String, we need to wrap it or reload data
      // Assuming generateInviteCode returns the code string
      // But DomainInviteCode is an object.
      // We should reload invite data to get the new code in the list.
      // 更新本地状态
      final newInviteCode = DomainInviteCode(
        code: codeString,
        status: 0,
        createdAt: DateTime.now(),
      );
      await loadInviteData();
      if (!_isCurrent(epoch)) return null;

      state = state.copyWith(isGenerating: false);
      _logger.info('邀请码生成成功');
      return newInviteCode;
    } catch (e) {
      if (!_isCurrent(epoch)) return null;
      _logger.info('生成邀请码失败: $e');
      final mapped = BackendMessageMapper.mapError(e);
      // 仅「创建数量上限」显示具体错误，其余原因统一用泛型提示
      final isLimitError = BackendMessageMapper.normalizeRaw(
            BackendMessageMapper.rawMessage(e),
          ).contains('创建数量上限') ||
          BackendMessageMapper.normalizeRaw(
            BackendMessageMapper.rawMessage(e),
          ).toLowerCase().contains('creation limit') ||
          BackendMessageMapper.normalizeRaw(
                BackendMessageMapper.rawMessage(e),
              ).toLowerCase().contains('maximum') &&
              BackendMessageMapper.normalizeRaw(
                BackendMessageMapper.rawMessage(e),
              ).toLowerCase().contains('invit');
      state = state.copyWith(
        isGenerating: false,
        errorMessage: isLimitError ? mapped : null,
      );
      return null;
    }
  }

  Future<bool> withdrawCommission({
    required int amountInCents,
    required String withdrawMethod,
    required String withdrawAccount,
  }) async {
    final epoch = ref.read(sessionEpochProvider);
    if (state.isLoading) return false;

    if (amountInCents <= 0 || amountInCents > 9007199254740991) {
      state = state.copyWith(
          errorMessage: appLocalizations.xboardInvalidWithdrawAmount);
      return false;
    }
    if (amountInCents > (state.availableCommission * 100).round()) {
      state = state.copyWith(
          errorMessage: appLocalizations.xboardWithdrawAmountExceeded(
        state.availableCommission.toStringAsFixed(2),
      ));
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _logger.info(
          '提现佣金: 方式=$withdrawMethod, 账号=${SensitiveMasker.maskText(withdrawAccount)}');
      final sdk = await ref.read(xboardSdkProvider.future);
      if (!_isCurrent(epoch)) return false;
      final success = await sdk.invite.withdrawCommission(
        amount: amountInCents / 100,
        method: withdrawMethod,
        params: {'account': withdrawAccount},
      );
      if (!_isCurrent(epoch)) return false;

      if (!success) {
        throw Exception(BackendMessageMapper.map(
          null,
          context: BackendMessageContext.withdraw,
        ));
      }

      // A successful withdrawal must not become "failed" merely because the
      // follow-up balance/history refresh failed, encouraging a second request.
      try {
        await _refreshAfterCommissionMutation();
        if (!_isCurrent(epoch)) return false;
      } catch (e) {
        if (!_isCurrent(epoch)) return false;
        _logger.warning('提现已提交，刷新佣金信息失败: $e');
        state = state.copyWith(isLoading: false, errorMessage: null);
      }
      _logger.info('提现申请提交成功');
      return true;
    } catch (e) {
      if (!_isCurrent(epoch)) return false;
      _logger.info('提现申请失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: BackendMessageMapper.mapError(
          e,
          context: BackendMessageContext.withdraw,
        ),
      );
      return false;
    }
  }

  Future<bool> transferCommission(double amount) async {
    final epoch = ref.read(sessionEpochProvider);
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _logger.info('划转佣金到钱包: ¥$amount');
      final sdk = await ref.read(xboardSdkProvider.future);
      if (!_isCurrent(epoch)) return false;
      final success = await sdk.invite.transferCommissionToBalance(amount);
      if (!_isCurrent(epoch)) return false;

      if (!success) {
        throw Exception(BackendMessageMapper.map(
          null,
          context: BackendMessageContext.transfer,
        ));
      }

      await _refreshAfterCommissionMutation();
      if (!_isCurrent(epoch)) return false;
      _logger.info('划转成功');
      return true;
    } catch (e) {
      if (!_isCurrent(epoch)) return false;
      _logger.info('划转失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: BackendMessageMapper.mapError(
          e,
          context: BackendMessageContext.transfer,
        ),
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<void> refresh() async {
    final epoch = ref.read(sessionEpochProvider);
    // 只做一次 isLoading 更新，避免多次 state 变更引起 UI 闪烁
    state = state.copyWith(
        isLoading: true, isLoadingHistory: true, errorMessage: null);
    try {
      ref.invalidate(getInviteInfoProvider);
      ref.invalidate(getCommissionDetailsProvider(page: 1));
      clearGetUserInfoCache();
      ref.invalidate(getUserInfoProvider);
      final results = await Future.wait([
        ref.read(getInviteInfoProvider.future),
        ref.read(getCommissionDetailsProvider(page: 1).future),
        ref.read(getUserInfoProvider.future),
        _fetchWithdrawConfig(),
      ]);
      if (!_isCurrent(epoch)) return;
      final inviteData = _mapInviteInfo(results[0] as InviteInfoModel);
      final newHistory = (results[1] as List<CommissionDetailModel>)
          .map(_mapCommission)
          .toList();
      final userInfo = _mapUser(results[2] as UserModel);
      final withdrawConfig = results[3] as _WithdrawConfig;
      // 并行拿到所有数据后做一次 state 更新，消除多次重建引起的闪烁
      ref.read(userInfoProvider.notifier).state = userInfo;
      state = InviteState(
        inviteData: inviteData,
        commissionHistory: newHistory,
        userInfo: userInfo,
        isLoading: false,
        isLoadingHistory: false,
        currentHistoryPage: 1,
        hasMoreHistory: newHistory.length >= state.historyPageSize,
        historyPageSize: state.historyPageSize,
        isWithdrawConfigLoaded: true,
        withdrawEnabled: withdrawConfig.enabled,
        withdrawMethods:
            withdrawConfig.enabled ? withdrawConfig.methods : const [],
      );
      unawaited(
          _saveInviteCache(epoch, inviteData: inviteData, history: newHistory));
    } catch (e) {
      if (!_isCurrent(epoch)) return;
      _logger.info('刷新邀请数据失败: $e');
      state = state.copyWith(
        isLoading: false,
        isLoadingHistory: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _refreshAfterCommissionMutation() async {
    final epoch = ref.read(sessionEpochProvider);
    ref.invalidate(getInviteInfoProvider);
    ref.invalidate(getCommissionDetailsProvider(page: 1));
    clearGetUserInfoCache();
    ref.invalidate(getUserInfoProvider);

    final results = await Future.wait([
      ref.read(getInviteInfoProvider.future),
      ref.read(getCommissionDetailsProvider(page: 1).future),
      ref.read(getUserInfoProvider.future),
    ]);
    if (!_isCurrent(epoch)) return;
    final inviteData = _mapInviteInfo(results[0] as InviteInfoModel);
    final newHistory = (results[1] as List<CommissionDetailModel>)
        .map(_mapCommission)
        .toList();
    final userInfo = _mapUser(results[2] as UserModel);

    ref.read(userInfoProvider.notifier).state = userInfo;
    state = state.copyWith(
      inviteData: inviteData,
      commissionHistory: newHistory,
      userInfo: userInfo,
      isLoading: false,
      isLoadingHistory: false,
      currentHistoryPage: 1,
      hasMoreHistory: newHistory.length >= state.historyPageSize,
      errorMessage: null,
    );

    unawaited(
        _saveInviteCache(epoch, inviteData: inviteData, history: newHistory));
  }

  Future<void> _saveInviteCache(int epoch,
      {DomainInvite? inviteData, List<DomainCommission>? history}) async {
    try {
      final scope = await ContentCacheScope.current();
      if (!_isCurrent(epoch) || scope == null) return;
      final storage = ref.read(storageServiceProvider);
      await Future.wait([
        if (inviteData != null)
          storage.saveDomainInvite(inviteData, scope: scope),
        if (history != null)
          storage.saveDomainCommissionHistory(history, scope: scope),
      ]);
    } catch (error) {
      _logger.info('保存邀请缓存失败: $error');
    }
  }

  Future<void> _saveUserCache(int epoch, DomainUser userInfo) async {
    try {
      final scope = await ContentCacheScope.account();
      if (!_isCurrent(epoch) || scope == null) return;
      await ref
          .read(storageServiceProvider)
          .saveDomainUser(userInfo, scope: scope);
    } catch (error) {
      _logger.info('保存用户缓存失败: $error');
    }
  }

  Future<_WithdrawConfig> _fetchWithdrawConfig() async {
    final epoch = ref.read(sessionEpochProvider);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      if (!_isCurrent(epoch)) {
        return const _WithdrawConfig(enabled: false, methods: []);
      }
      final resp = await sdk.httpService.getRequest('/user/comm/config');
      final data = resp['data'] as Map<String, dynamic>?;
      final enabled = _parseWithdrawEnabled(data?['withdraw_close']);
      final methods = (data?['withdraw_methods'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      _logger.info(
        '提现配置刷新完成: enabled=$enabled, methods=${methods.length}',
      );
      return _WithdrawConfig(enabled: enabled, methods: methods);
    } catch (e) {
      _logger.info('提现配置刷新失败，隐藏提现入口: $e');
      return const _WithdrawConfig(enabled: false, methods: []);
    }
  }
}

class _WithdrawConfig {
  final bool enabled;
  final List<String> methods;

  const _WithdrawConfig({
    required this.enabled,
    required this.methods,
  });
}

bool _parseWithdrawEnabled(Object? withdrawClose) {
  if (withdrawClose is num) return withdrawClose.toInt() == 0;
  if (withdrawClose is bool) return withdrawClose == false;
  if (withdrawClose is String) {
    final value = withdrawClose.trim().toLowerCase();
    if (value == '0' || value == 'false') return true;
    if (value == '1' || value == 'true') return false;
  }
  return false;
}

final inviteProvider = NotifierProvider<InviteNotifier, InviteState>(
  InviteNotifier.new,
);

extension InviteHelpers on WidgetRef {
  InviteState get inviteState => read(inviteProvider);
  InviteNotifier get inviteNotifier => read(inviteProvider.notifier);
}

DomainInvite _mapInviteInfo(InviteInfoModel info) {
  return DomainInvite(
    codes: info.codes.map(_mapInviteCode).toList(),
    stats: InviteStats(
      invitedCount: info.totalInvites,
      totalCommission: info.totalCommission / 100.0,
      pendingCommission: info.pendingCommission / 100.0,
      commissionRate: info.commissionRatePercent, // 已经是百分比，不需要再除以 100
      availableCommission: info.availableCommission / 100.0,
    ),
  );
}

DomainInviteCode _mapInviteCode(InviteCodeModel code) {
  return DomainInviteCode(
    code: code.code,
    status: code.status ? 1 : 0, // XBoard/V2Board: false=未使用(0=可用), true=已使用(1)
    createdAt: code.createdAt,
  );
}

DomainCommission _mapCommission(CommissionDetailModel item) {
  return DomainCommission(
    id: item.id,
    tradeNo: item.tradeNo,
    amount: item.getAmount / 100.0,
    status: item.commissionStatus, // 0=待确认,1=发放中,2=有效,3=无效
    createdAt: item.createdAt,
  );
}

DomainUser _mapUser(UserModel user) {
  return DomainUser(
    email: user.email,
    uuid: user.uuid,
    avatarUrl: user.avatarUrl,
    planId: user.planId,
    transferLimit: user.transferEnable.toInt(),
    uploadedBytes: 0,
    downloadedBytes: 0,
    balanceInCents: user.balance.toInt(),
    commissionBalanceInCents: user.commissionBalance.toInt(),
    expiredAt: user.expiredAt,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
    banned: user.banned,
    remindExpire: user.remindExpire,
    remindTraffic: user.remindTraffic,
    discount: user.discount,
    commissionRate: user.commissionRate,
    telegramId: user.telegramId,
    metadata: {'autoRenewal': user.autoRenewal},
  );
}

/// 面板站点 URL 缓存提供者（登录后从 /guest/comm/config 获取 app_url）
///
/// 邀请链接默认使用此 URL（面板后台「站点网址」），而非 API 域名。
/// keepAlive 确保只请求一次，后续读缓存。
final panelSiteUrlProvider = FutureProvider<String>((ref) async {
  try {
    final sdk = await ref.watch(xboardSdkProvider.future);
    final resp = await sdk.httpService.getRequest('/guest/comm/config');
    final data = resp['data'] as Map<String, dynamic>?;
    return data?['app_url'] as String? ?? '';
  } catch (_) {
    return '';
  }
});
