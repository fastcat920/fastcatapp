import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/widgets.dart';
import 'plan_purchase_page.dart';
import '../widgets/plan_description_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlansView extends ConsumerStatefulWidget {
  const PlansView({super.key});
  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  DomainPlan? _selectedPlan; // 桌面端选中的套餐
  bool _hasCheckedUrlParams = false; // 标记是否已检查URL参数
  String? _initialPeriod; // URL参数传入的初始周期（如 reset_price）
  AppLocalizations get appLocalizations => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subscriptionNotifier =
          ref.read(xboardSubscriptionProvider.notifier);
      subscriptionNotifier.autoRefreshIfNeeded();

      // 检查URL参数中是否有planId
      _checkUrlParams();
    });
  }

  Future<void> _checkUrlParams() async {
    if (_hasCheckedUrlParams) return;
    _hasCheckedUrlParams = true;

    // 获取URL参数
    final state = GoRouterState.of(context);
    final planIdStr = state.uri.queryParameters['planId'];
    _initialPeriod = state.uri.queryParameters['period'];

    if (planIdStr != null) {
      final planId = int.tryParse(planIdStr);
      if (planId != null) {
        // 先从已加载列表查找，再按ID直拉（兼容“商店隐藏但可续费”套餐）
        final plans = ref.read(xboardSubscriptionProvider);
        DomainPlan? plan = plans.where((p) => p.id == planId).firstOrNull;
        plan ??= await ref
            .read(xboardSubscriptionProvider.notifier)
            .loadPlanById(planId);
        if (!mounted) return;

        if (plan != null) {
          final isDesktop = Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS ||
              system.isTV;
          if (isDesktop) {
            // 桌面端：在当前页直接切换到购买视图
            setState(() {
              _selectedPlan = plan;
            });
          } else {
            // 移动端：直接打开购买页
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlanPurchasePage(
                  plan: plan!,
                  initialPeriod: _initialPeriod,
                ),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _refreshPlans() async {
    final subscriptionNotifier = ref.read(xboardSubscriptionProvider.notifier);
    await subscriptionNotifier.refreshPlans();
  }

  void _backToPlans() {
    setState(() {
      _selectedPlan = null;
    });
  }

  String _formatPrice(double? price) {
    if (price == null) return '-';
    return '¥${price.toStringAsFixed(2)}';
  }

  String _formatTraffic(double transferEnable) {
    return '${transferEnable.toStringAsFixed(0)}GB';
  }

  String _getLowestPrice(DomainPlan plan) {
    List<double> prices = [];
    if (plan.monthlyPrice != null) prices.add(plan.monthlyPrice!);
    if (plan.quarterlyPrice != null) prices.add(plan.quarterlyPrice!);
    if (plan.halfYearlyPrice != null) prices.add(plan.halfYearlyPrice!);
    if (plan.yearlyPrice != null) prices.add(plan.yearlyPrice!);
    if (plan.twoYearPrice != null) prices.add(plan.twoYearPrice!);
    if (plan.threeYearPrice != null) prices.add(plan.threeYearPrice!);
    if (plan.onetimePrice != null) prices.add(plan.onetimePrice!);
    if (prices.isEmpty) return '-';
    final lowestPrice = prices.reduce((a, b) => a < b ? a : b);
    return _formatPrice(lowestPrice);
  }

  /// 获取最低价格对应的周期文字
  String _getLowestPricePeriod(DomainPlan plan) {
    double? lowest;
    String period = '';
    final entries = <double, String>{};
    if (plan.monthlyPrice != null) entries[plan.monthlyPrice!] = '月付';
    if (plan.quarterlyPrice != null) entries[plan.quarterlyPrice!] = '季付';
    if (plan.halfYearlyPrice != null) entries[plan.halfYearlyPrice!] = '半年付';
    if (plan.yearlyPrice != null) entries[plan.yearlyPrice!] = '年付';
    if (plan.twoYearPrice != null) entries[plan.twoYearPrice!] = '两年付';
    if (plan.threeYearPrice != null) entries[plan.threeYearPrice!] = '三年付';
    if (plan.onetimePrice != null) entries[plan.onetimePrice!] = '一次性';
    for (final e in entries.entries) {
      if (lowest == null || e.key < lowest) {
        lowest = e.key;
        period = e.value;
      }
    }
    return period;
  }

  String _getDeviceLimitText(DomainPlan plan) {
    if (plan.deviceLimit == null || plan.deviceLimit == 0) {
      return AppLocalizations.of(context).xboardUnlimited;
    }
    return '${plan.deviceLimit}台';
  }

  String _getSpeedLimitText(DomainPlan plan) {
    if (plan.speedLimit == null) {
      return AppLocalizations.of(context).xboardUnlimitedSpeed;
    }
    return '${plan.speedLimit} Mbps';
  }

  Widget _buildPlanCard(DomainPlan plan) {
    final isDesktop = Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS ||
        system.isTV;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final priceText = _getLowestPrice(plan);
    final periodText = _getLowestPricePeriod(plan);
    final trafficText = _formatTraffic(plan.transferQuota.toDouble());
    final speedText = _getSpeedLimitText(plan);
    final deviceText = _getDeviceLimitText(plan);

    final cardRadius = BorderRadius.circular(20);
    return Container(
      margin:
          isDesktop ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: cardRadius,
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.18)
              : const Color(0xFFEEF0F4),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF1565C0).withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 套餐名 ──
              Text(
                plan.name,
                style: XbUiText.sectionTitle(context).copyWith(
                  fontSize: isDesktop ? 20 : 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // ── 价格 + 周期 ──
              if (plan.hasPrice)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '¥ ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      priceText.replaceFirst('¥', ''),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ $periodText',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // ── 三个特性指标 ──
              Row(
                children: [
                  _buildFeatureBox(
                    icon: Icons.cloud_outlined,
                    value: trafficText,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _buildFeatureBox(
                    icon: Icons.speed_outlined,
                    value: speedText,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _buildFeatureBox(
                    icon: Icons.devices_outlined,
                    value: deviceText,
                    isDark: isDark,
                  ),
                ],
              ),
              // ── 描述 ──
              if (plan.description != null &&
                  plan.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                PlanDescriptionWidget(content: plan.description!),
              ],
              const SizedBox(height: 16),
              // ── 购买按钮 ──
              if (plan.hasPrice)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToPurchase(plan),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(appLocalizations.xboardBuyNow),
                    style: XbUiButton.filledPrimary(context).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                      elevation: const WidgetStatePropertyAll(0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBox({
    required IconData icon,
    required String value,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPurchase(DomainPlan plan) {
    final isDesktop = Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS ||
        system.isTV;

    if (isDesktop) {
      // 桌面端：内嵌显示
      setState(() {
        _selectedPlan = plan;
      });
    } else {
      // 移动端：使用 Navigator.push 导航，自动有返回按钮
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlanPurchasePage(plan: plan),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isLinux ||
        Platform.isWindows ||
        Platform.isMacOS ||
        system.isTV;
    final size = MediaQuery.sizeOf(context);
    final useSideNavigation = size.width > size.height || system.isTV;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final scaffold = Scaffold(
      backgroundColor: isDarkMode ? null : XbUiTokens.pageBackgroundLight,
      appBar: _selectedPlan != null && isDesktop
          // 桌面端购买页面：显示返回按钮的 AppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToPlans,
                tooltip: '返回',
              ),
              title: Text(appLocalizations.xboardPurchaseSubscription),
              elevation: 0,
              scrolledUnderElevation: 1,
            )
          // 套餐列表：移动端才显示 AppBar
          : isDesktop
              ? null
              : AppBar(
                  title: Text(appLocalizations.xboardPlans),
                  // 使用 push 路由后，自动显示返回按钮
                ),
      body: isDesktop && _selectedPlan != null
          // 桌面端：显示购买页面（嵌入模式，无 Scaffold）
          ? PlanPurchasePage(
              plan: _selectedPlan!,
              embedded: true,
              onBack: _backToPlans,
              initialPeriod: _initialPeriod,
            )
          // 显示套餐列表
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshPlans,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final allPlans = ref.watch(xboardSubscriptionProvider);
                        final plans = allPlans;
                        final uiState = ref.watch(userUIStateProvider);
                        if (uiState.isLoading && allPlans.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (uiState.errorMessage != null) {
                          return XbErrorState(
                            message: uiState.errorMessage!,
                            onRetry: _refreshPlans,
                          );
                        }
                        if (allPlans.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('暂无套餐信息',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey)),
                              ],
                            ),
                          );
                        }
                        if (isDesktop || useSideNavigation) {
                          final showHeader = isDesktop;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const gap = 12.0;
                                final colWidth = useSideNavigation
                                    ? (constraints.maxWidth - gap) / 2
                                    : constraints.maxWidth;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showHeader) ...[
                                      Row(
                                        children: [
                                          Text(
                                            appLocalizations.xboardPlans,
                                            style: XbUiText.pageTitle(context),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.refresh),
                                            onPressed: _refreshPlans,
                                            tooltip: appLocalizations.refresh,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Wrap(
                                      spacing: gap,
                                      runSpacing: gap,
                                      children: plans.map((plan) {
                                        return SizedBox(
                                          width: colWidth,
                                          child: _buildPlanCard(plan),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        } else {
                          return ListView.builder(
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
                            itemCount: plans.length,
                            itemBuilder: (context, index) =>
                                _buildPlanCard(plans[index]),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );

    return scaffold;
  }
}
