import 'dart:async';
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/plan_state.dart';
import 'package:fl_clash/xboard/adapter/state/subscription_state.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:fl_clash/xboard/features/initialization/models/initialization_state.dart';
import 'package:fl_clash/xboard/services/services.dart';

// 初始化文件级日志器
const _logger = FileLogger('xboard_subscription_provider.dart');

class XBoardSubscriptionNotifier extends Notifier<List<DomainPlan>> {
  void _afterFrame(Future<void> Function() task) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>(task);
    });
  }

  void _scheduleLoadPlans() {
    _afterFrame(loadPlans);
  }

  void _scheduleLoadCachedPlans() {
    _afterFrame(_loadCachedPlans);
  }

  void _scheduleClearPlans() {
    _afterFrame(() async => _clearPlans());
  }

  @override
  List<DomainPlan> build() {
    // 监听初始化完成：init ready 后若已认证则加载套餐。
    // 关键：避免冷启动时 xboardSdkProvider 在域名竞速完成前被提前触发，
    // 导致失败并被 Riverpod (keepAlive:true) 永久缓存，使真正的初始化也失败。
    ref.listen<InitializationState>(initializationProvider, (prev, next) {
      if (next.isReady && prev?.isReady != true) {
        final auth = ref.read(xboardUserAuthProvider);
        if (auth.isAuthenticated) {
          _scheduleLoadPlans();
        }
      }
      // 初始化失败时，仍允许已登录用户展示本地缓存套餐，保证离线可见
      if (next.isFailed && prev?.isFailed != true) {
        final auth = ref.read(xboardUserAuthProvider);
        if (auth.isAuthenticated) {
          _scheduleLoadCachedPlans();
        }
      }
    });

    ref.listen(xboardUserAuthProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        // 只在初始化已完成时才立即加载；
        // 若尚未完成，由上面的 initializationProvider 监听器负责触发
        final initState = ref.read(initializationProvider);
        if (initState.isReady) {
          _scheduleLoadPlans();
        }
      } else if (!next.isAuthenticated) {
        _scheduleClearPlans();
      }
    });

    // 保底：只要已认证先加载缓存（离线可见），初始化就绪后再拉远程
    final currentAuth = ref.read(xboardUserAuthProvider);
    final initState = ref.read(initializationProvider);
    if (currentAuth.isAuthenticated) {
      _scheduleLoadCachedPlans();
    }
    if (currentAuth.isAuthenticated && initState.isReady) {
      _scheduleLoadPlans();
    }

    return const <DomainPlan>[];
  }

  Future<void> _loadCachedPlans() async {
    if (state.isNotEmpty) return;
    final result = await ref.read(storageServiceProvider).getDomainPlans();
    final cachedPlans = result.dataOrNull ?? const <DomainPlan>[];
    if (cachedPlans.isNotEmpty && state.isEmpty) {
      state = cachedPlans;
      ref.read(userUIStateProvider.notifier).state = UIState(
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> loadPlans() async {
    final userAuthState = ref.read(xboardUserAuthProvider);
    if (!userAuthState.isAuthenticated) {
      state = <DomainPlan>[];
      ref.read(userUIStateProvider.notifier).state = const UIState(
        errorMessage: '请先登录',
      );
      return;
    }
    // 缓存命中：已有数据且在 10 分钟内，跳过重新请求
    if (state.isNotEmpty && !needsRefresh) {
      _logger.info('套餐列表缓存有效（< 10min），跳过重新请求');
      return;
    }
    ref.read(userUIStateProvider.notifier).state =
        const UIState(isLoading: true);
    try {
      _logger.info('开始加载套餐列表...');
      final planModels = await ref.read(getPlansProvider.future);
      final plans = planModels.map(_mapPlan).toList();
      final visiblePlans = plans.where((plan) => plan.isVisible).toList();
      // 按 sort 字段排序（升序），null 值排在最后
      visiblePlans.sort((a, b) {
        if (a.sort == null && b.sort == null) return 0;
        if (a.sort == null) return 1;
        if (b.sort == null) return -1;
        return a.sort!.compareTo(b.sort!);
      });
      state = visiblePlans;
      unawaited(
        ref.read(storageServiceProvider).saveDomainPlans(visiblePlans),
      );
      ref.read(userUIStateProvider.notifier).state = UIState(
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      _logger.info('套餐列表加载成功，共 ${visiblePlans.length} 个可见套餐');
    } catch (e) {
      _logger.info('加载套餐列表失败: $e');
      ref.read(userUIStateProvider.notifier).state = UIState(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshPlans() async {
    _logger.info('强制刷新套餐列表（清除缓存）...');
    // 清除 lastUpdated，确保 loadPlans 跳过 10 分钟缓存检查
    ref.read(userUIStateProvider.notifier).state = const UIState();
    clearGetPlansCache();
    ref.invalidate(getPlansProvider);
    await loadPlans();
  }

  DomainPlan? getPlanById(int planId) {
    try {
      return state.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }

  Future<DomainPlan?> loadPlanById(int planId) async {
    final cachedPlan = getPlanById(planId);
    if (cachedPlan != null) return cachedPlan;

    try {
      final planModel = await ref.read(getPlanProvider(planId).future);
      if (planModel != null) return _mapPlan(planModel);
    } catch (e) {
      _logger.info('按 ID 加载套餐失败: planId=$planId, error=$e');
    }

    try {
      final subscription = await ref.read(getSubscriptionProvider.future);
      final currentPlan = _mapCurrentSubscriptionPlan(subscription, planId);
      if (currentPlan != null) {
        _logger.info('从当前订阅快照加载套餐成功: planId=$planId');
      }
      return currentPlan;
    } catch (e) {
      _logger.info('从当前订阅快照加载套餐失败: planId=$planId, error=$e');
      return null;
    }
  }

  List<DomainPlan> get plansWithPrice {
    return state.where((plan) => plan.hasPrice).toList();
  }

  List<DomainPlan> get recommendedPlans {
    return state
        .where((plan) => plan.isVisible && plan.hasPrice)
        .take(3)
        .toList();
  }

  void _clearPlans() {
    _logger.info('清空套餐列表');
    state = <DomainPlan>[];
    ref.read(userUIStateProvider.notifier).state = const UIState();
  }

  void clearError() {
    final uiState = ref.read(userUIStateProvider);
    if (uiState.errorMessage != null) {
      ref.read(userUIStateProvider.notifier).state = uiState.clearError();
    }
  }

  bool get needsRefresh {
    final uiState = ref.read(userUIStateProvider);
    if (uiState.lastUpdated == null) return true;
    final now = DateTime.now();
    final diff = now.difference(uiState.lastUpdated!);
    return diff.inMinutes > 10; // 10分钟后需要刷新
  }

  Future<void> autoRefreshIfNeeded() async {
    final uiState = ref.read(userUIStateProvider);
    if (state.isEmpty) {
      await _loadCachedPlans();
    }
    if (needsRefresh && !uiState.isLoading) {
      await refreshPlans();
    }
  }
}

final xboardSubscriptionProvider =
    NotifierProvider<XBoardSubscriptionNotifier, List<DomainPlan>>(
  XBoardSubscriptionNotifier.new,
);

final xboardPlanProvider = Provider.family<DomainPlan?, int>((ref, planId) {
  final plans = ref.watch(xboardSubscriptionProvider);
  try {
    return plans.firstWhere((plan) => plan.id == planId);
  } catch (e) {
    return null;
  }
});

final xboardPlansWithPriceProvider = Provider<List<DomainPlan>>((ref) {
  final plans = ref.watch(xboardSubscriptionProvider);
  return plans.where((plan) => plan.hasPrice).toList();
});

final xboardRecommendedPlansProvider = Provider<List<DomainPlan>>((ref) {
  final plans = ref.watch(xboardSubscriptionProvider);
  return plans
      .where((plan) => plan.isVisible && plan.hasPrice)
      .take(3)
      .toList();
});

/// 将套餐 content 字段转换为可读文本
/// content 可能是 JSON 数组（features 格式）或普通文本/Markdown
String? _parsePlanContent(String? content) {
  if (content == null || content.trim().isEmpty) return null;
  try {
    final dynamic parsed = jsonDecode(content);
    if (parsed is List) {
      return parsed.map((item) {
        final feature = (item['feature'] as String? ?? '').trim();
        final rawSupport = item['support'];
        final support = rawSupport is bool
            ? rawSupport
            : (rawSupport == 1 || rawSupport == true);
        return support ? '- $feature' : '- ~~$feature~~';
      }).join('\n');
    }
  } catch (_) {
    // 不是 JSON，原样返回
  }
  return content;
}

DomainPlan _mapPlan(PlanModel plan) {
  return DomainPlan(
    id: plan.id,
    name: plan.name,
    groupId: plan.groupId,
    transferQuota: plan.transferEnable.toInt(),
    description: _parsePlanContent(plan.content),
    tags: plan.tags ?? [],
    speedLimit: plan.speedLimit,
    deviceLimit: plan.deviceLimit,
    isVisible: plan.show,
    renewable: plan.renew,
    sort: plan.sort,
    onetimePrice: plan.onetimePrice,
    monthlyPrice: plan.monthPrice,
    quarterlyPrice: plan.quarterPrice,
    halfYearlyPrice: plan.halfYearPrice,
    yearlyPrice: plan.yearPrice,
    twoYearPrice: plan.twoYearPrice,
    threeYearPrice: plan.threeYearPrice,
    resetPrice: plan.resetPrice,
    createdAt: plan.createdAt != null
        ? DateTime.fromMillisecondsSinceEpoch(plan.createdAt! * 1000)
        : null,
    updatedAt: plan.updatedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(plan.updatedAt! * 1000)
        : null,
  );
}

DomainPlan? _mapCurrentSubscriptionPlan(
  SubscriptionModel subscription,
  int planId,
) {
  final plan = subscription.plan;
  final currentPlanId =
      _normalizePlanId(plan?.id) ?? _normalizePlanId(subscription.planId);
  if (currentPlanId == null || currentPlanId != planId || plan == null) {
    return null;
  }

  final hasPeriodPrice = _firstPositive([
        plan.monthPrice,
        plan.quarterPrice,
        plan.halfYearPrice,
        plan.yearPrice,
        plan.twoYearPrice,
        plan.threeYearPrice,
        plan.onetimePrice,
      ]) !=
      null;
  final fallbackPrice = hasPeriodPrice ? null : plan.price;

  return DomainPlan(
    id: currentPlanId,
    name: _nonEmpty(plan.name) ?? subscription.planName ?? '当前套餐',
    groupId: plan.groupId ?? 0,
    transferQuota: _resolvePlanTrafficQuota(
      plan.transferEnable,
      subscription.transferEnable,
    ),
    description: _parsePlanContent(plan.content ?? plan.description),
    tags: plan.tags ?? const [],
    speedLimit: plan.speedLimit ?? subscription.speedLimit,
    deviceLimit: plan.deviceLimit ?? subscription.deviceLimit,
    isVisible: plan.show ?? false,
    renewable: plan.renew ?? true,
    sort: plan.sort,
    onetimePrice: plan.onetimePrice,
    monthlyPrice: plan.monthPrice ?? fallbackPrice,
    quarterlyPrice: plan.quarterPrice,
    halfYearlyPrice: plan.halfYearPrice,
    yearlyPrice: plan.yearPrice,
    twoYearPrice: plan.twoYearPrice,
    threeYearPrice: plan.threeYearPrice,
    resetPrice: plan.resetPrice,
    metadata: {
      'source': 'current_subscription',
      if (plan.price != null) 'subscriptionPlanPrice': plan.price,
      if (plan.resetTrafficMethod != null)
        'resetTrafficMethod': plan.resetTrafficMethod,
    },
  );
}

int? _normalizePlanId(int? planId) =>
    planId != null && planId > 0 ? planId : null;

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

double? _firstPositive(Iterable<double?> values) {
  for (final value in values) {
    if (value != null && value > 0) return value;
  }
  return null;
}

int _resolvePlanTrafficQuota(int? planTransferEnable, int? subscriptionBytes) {
  if (planTransferEnable != null && planTransferEnable > 0) {
    return planTransferEnable;
  }
  if (subscriptionBytes == null || subscriptionBytes <= 0) return 0;
  final gb = subscriptionBytes / (1024 * 1024 * 1024);
  return gb <= 0 ? 0 : gb.round();
}
