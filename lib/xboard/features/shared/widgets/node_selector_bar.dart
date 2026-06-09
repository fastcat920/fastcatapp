import 'dart:async';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/subscription/services/reset_traffic_order_flow.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_guard_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_status_service.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_status_dialog.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:go_router/go_router.dart';

class NodeSelectorBar extends ConsumerStatefulWidget {
  const NodeSelectorBar({super.key});
  @override
  ConsumerState<NodeSelectorBar> createState() => _NodeSelectorBarState();
}

class _NodeSelectorBarState extends ConsumerState<NodeSelectorBar> {
  String? _lastProxyName;
  bool _isFirstBuild = true;
  // 导入成功后的宽限期：等待 applyProfile 在后台完成（最长 60 秒）
  // 解决 Windows 便携版 ClashCore 启动慢时短暂显示"无可用节点"的问题
  bool _inPostImportGrace = false;
  Timer? _postImportGraceTimer;
  // 启动后等待导入开始的最长时间（防止永久卡在加载态）
  bool _startupGraceExpired = false;
  Timer? _startupGraceTimer;

  @override
  void initState() {
    super.initState();
    // 启动后最多等 15 秒，若导入仍未开始则不再显示加载态
    _startupGraceTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _startupGraceExpired = true);
    });
    ref.listenManual(
      profileImportProvider.select((s) => s.lastSuccessTime),
      (_, newTime) {
        if (newTime != null && ref.read(groupsProvider).isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _startPostImportGrace();
            }
          });
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      autoLatencyService.initialize(ref);
    });
  }

  void _startPostImportGrace() {
    _postImportGraceTimer?.cancel();
    if (!mounted) return;
    setState(() => _inPostImportGrace = true);
    _postImportGraceTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) setState(() => _inPostImportGrace = false);
    });
  }

  @override
  void dispose() {
    _postImportGraceTimer?.cancel();
    _startupGraceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final mode =
        ref.watch(patchClashConfigProvider.select((state) => state.mode));
    final blockStatus = subscriptionGuardService.checkBeforeConnect();
    if (blockStatus != null &&
        (blockStatus.type == SubscriptionStatusType.noSubscription ||
            blockStatus.type == SubscriptionStatusType.expired ||
            blockStatus.type == SubscriptionStatusType.exhausted)) {
      return _buildEmptyState(context);
    }

    if (groups.isEmpty) {
      final importState = ref.watch(profileImportProvider);
      if (importState.isImporting) {
        return _buildLoadingState(context);
      }
      // 登录后缓存数据仍在后台加载时（lastResult==null），
      // 若本地没有任何 profile 文件且订阅信息未就绪或有订阅 URL，
      // 继续显示加载态，避免导入启动前短暂闪现"无可用节点"。
      // 但若本地已有 profile（上次成功导入），则不卡在 loading，
      // 直接显示"无节点"，避免永久卡死。
      // 启动宽限期（15s）过后也不再卡在此处，防止永久 loading。
      if (importState.lastResult == null && !_startupGraceExpired) {
        final profiles = ref.watch(profilesProvider);
        if (profiles.isEmpty) {
          final subscriptionInfo = ref.watch(subscriptionInfoProvider);
          if (subscriptionInfo == null ||
              subscriptionInfo.subscribeUrl.isNotEmpty) {
            return _buildLoadingState(context);
          }
        }
      }
      // 若本次会话刚刚成功导入（宽限期内），applyProfile 可能还在后台运行，
      // 继续显示加载态，避免节点加载完成前短暂显示"无可用节点"。
      // 这对 Windows 便携版尤其重要：ClashCore 启动较慢时，
      // applyProfile 会等待 socketCompleter 就绪后才能执行。
      // 宽限期最长 60 秒，到期后若仍无节点则显示"无可用节点"。
      if (_inPostImportGrace) {
        return _buildLoadingState(context);
      }
      return _buildEmptyState(context);
    }
    Group? currentGroup;
    Proxy? currentProxy;
    if (mode == Mode.global) {
      currentGroup = groups.firstWhere(
        (group) => group.name == GroupName.GLOBAL.name,
        orElse: () => groups.first,
      );
    } else if (mode == Mode.rule) {
      for (final group in groups) {
        if (group.hidden == true) continue;
        if (group.name == GroupName.GLOBAL.name) continue;
        final selectedProxyName = selectedMap[group.name];
        if (selectedProxyName != null && selectedProxyName.isNotEmpty) {
          final referencedGroup = groups.firstWhere(
            (g) => g.name == selectedProxyName,
            orElse: () => group, // 如果没找到引用的组，就使用当前组
          );
          if (referencedGroup.name == selectedProxyName &&
              referencedGroup.type == GroupType.URLTest) {
            currentGroup = referencedGroup;
            break;
          } else {
            currentGroup = group;
            break;
          }
        }
      }
      if (currentGroup == null) {
        currentGroup = groups.firstWhere(
          (group) =>
              group.hidden != true && group.name != GroupName.GLOBAL.name,
          orElse: () => groups.first,
        );
        if (currentGroup.now != null && currentGroup.now!.isNotEmpty) {
          final nowValue = currentGroup.now!;
          final referencedGroup = groups.firstWhere(
            (g) => g.name == nowValue,
            orElse: () => currentGroup!,
          );
          if (referencedGroup.name == nowValue &&
              referencedGroup.type == GroupType.URLTest) {
            currentGroup = referencedGroup;
          }
        }
      }
    }
    if (currentGroup == null || currentGroup.all.isEmpty) {
      return _buildEmptyState(context);
    }
    final selectedProxyName = selectedMap[currentGroup.name] ?? '';
    String realNodeName;
    // 是否选中了 URLTest 组（自动选择）：显示组名，但延迟用实际节点
    final bool isAutoSelect = currentGroup.type == GroupType.URLTest;
    if (isAutoSelect) {
      realNodeName = currentGroup.now ?? '';
    } else {
      realNodeName = currentGroup.getCurrentSelectedName(selectedProxyName);
    }
    if (realNodeName.isNotEmpty) {
      currentProxy = currentGroup.all.firstWhere(
        (proxy) => proxy.name == realNodeName,
        orElse: () => currentGroup!.all.first,
      );
    } else {
      currentProxy = currentGroup.all.first;
    }
    _checkNodeChange(currentProxy);
    // 自动选择时显示组名（如"自动选择"），延迟用实际节点的
    final displayName = isAutoSelect ? currentGroup.name : currentProxy.name;
    return _buildProxyDisplay(context, currentGroup, currentProxy,
        displayName: displayName);
  }

  Widget _buildProxyDisplay(BuildContext context, Group group, Proxy proxy,
      {String? displayName}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardRadius = BorderRadius.circular(XbUiTokens.radiusCard);
    return TVFocusable(
      borderRadius: cardRadius,
      onPressed: () => _handleOpenProxiesView(context),
      child: Material(
        color: isDark ? colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: cardRadius,
        child: InkWell(
          onTap: () => _handleOpenProxiesView(context),
          borderRadius: cardRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: cardRadius,
              border: Border.all(
                color: isDark
                    ? colorScheme.outline.withValues(alpha: 0.18)
                    : XbUiTokens.cardBorderLight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.language,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).xboardNodeSelection,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName ?? proxy.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _DelayBadge(proxyName: proxy.name),
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : const Color(0xFF9CA3B4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(XbUiTokens.radiusCard),
        border: isDark ? null : Border.all(color: XbUiTokens.cardBorderLight),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(XbUiTokens.radiusCardCompact),
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).xboardImportingSubscription,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).xboardPleaseWait,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(XbUiTokens.radiusCard),
        border: isDark ? null : Border.all(color: XbUiTokens.cardBorderLight),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(XbUiTokens.radiusCardCompact),
            ),
            child: Icon(
              Icons.wifi_off,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).xboardNoAvailableNodes,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _handleOpenProxiesView(context),
            style: XbUiButton.filledPrimary(context).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(56, 30)),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10)),
            ),
            child: const Text(
              '切换',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _openProxiesView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CommonScaffold(
          backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
          title: AppLocalizations.of(ctx).xboardProxy,
          actions: [
            Consumer(
              builder: (_, ref, __) {
                final isImporting =
                    ref.watch(profileImportProvider).isImporting;
                return TextButton.icon(
                  onPressed: isImporting
                      ? null
                      : () {
                          final url =
                              ref.read(subscriptionInfoProvider)?.subscribeUrl;
                          if (url != null && url.isNotEmpty) {
                            ref
                                .read(profileImportProvider.notifier)
                                .importSubscription(url, forceRefresh: true);
                          }
                        },
                  icon: isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context).xboardUpdateNodes),
                );
              },
            ),
            TextButton.icon(
              onPressed: () {
                autoLatencyService.testCurrentGroupNodes(maxNodes: 999);
              },
              icon: const Icon(Icons.network_check),
              label: Text(AppLocalizations.of(context).xboardTestLatency),
            ),
          ],
          body: Container(
            color: isDark ? null : XbUiTokens.pageBackgroundLight,
            child: const _AutoPopProxiesView(),
          ),
        ),
      ),
    );
  }

  Future<void> _handleOpenProxiesView(BuildContext context) async {
    final blockStatus = subscriptionGuardService.checkBeforeConnect();
    if (blockStatus != null &&
        (blockStatus.type == SubscriptionStatusType.noSubscription ||
            blockStatus.type == SubscriptionStatusType.expired ||
            blockStatus.type == SubscriptionStatusType.exhausted)) {
      await SubscriptionStatusDialog.show(
        context,
        blockStatus,
        onPurchase: () => GoRouter.of(context).go('/plans'),
        onResetTraffic: blockStatus.type == SubscriptionStatusType.exhausted
            ? () => showResetTrafficOrderDialog(context: context, ref: ref)
            : null,
        onRefresh: () {
          ref.read(xboardUserProvider.notifier).refreshSubscriptionInfo();
        },
      );
      return;
    }
    if (!context.mounted) return;
    _openProxiesView(context);
  }

  void _checkNodeChange(Proxy currentProxy) {
    if (_isFirstBuild) {
      _lastProxyName = currentProxy.name;
      _isFirstBuild = false;
      return;
    }
    if (_lastProxyName != currentProxy.name) {
      _lastProxyName = currentProxy.name;
    }
  }
}

/// 节点列表视图：选择节点后自动返回上一页
class _AutoPopProxiesView extends ConsumerStatefulWidget {
  const _AutoPopProxiesView();

  @override
  ConsumerState<_AutoPopProxiesView> createState() =>
      _AutoPopProxiesViewState();
}

class _AutoPopProxiesViewState extends ConsumerState<_AutoPopProxiesView> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(selectedMapProvider, (previous, next) {
      if (previous != null && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ProxiesView();
  }
}

/// 节点延迟徽章：订阅 delayDataSourceProvider，延迟变化时局部刷新
class _DelayBadge extends ConsumerWidget {
  final String proxyName;
  const _DelayBadge({required this.proxyName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(getDelayProvider(proxyName: proxyName));
    if (delay == null) return const SizedBox.shrink();

    // delay == -1: 实际超时; delay == 0: 尚未测试/测速中, 不显示徽章
    if (delay <= 0) return const SizedBox.shrink();
    final Color color = delay < 500
        ? XbUiStatusColor.success(context)
        : XbUiStatusColor.pending(context);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(XbUiTokens.radiusCardCompact),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${delay}ms',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
