import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/mihomo/mihomo.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/nodes/utils/node_country_resolver.dart';
import 'package:fl_clash/xboard/features/profile/providers/profile_import_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatNodesPage extends ConsumerStatefulWidget {
  const FastCatNodesPage({super.key, this.initialGroupName});

  final String? initialGroupName;

  @override
  ConsumerState<FastCatNodesPage> createState() => _FastCatNodesPageState();
}

class _FastCatNodesPageState extends ConsumerState<FastCatNodesPage> {
  // 66px visible card + 8px spacing between rows.
  static const double _itemExtent = 74;
  static const Duration _minimumTestingIndicatorDuration =
      Duration(milliseconds: 200);
  final ScrollController _scrollController = ScrollController();
  final FocusNode _selectedNodeFocusNode =
      FocusNode(debugLabel: 'selected-node');
  bool _selecting = false;
  bool _updating = false;
  bool _testing = false;
  final Set<String> _testingNodes = {};
  final Map<String, DateTime> _testingStartedAt = {};
  final Map<String, int> _testingGenerations = {};
  int _testingGeneration = 0;
  bool _didCenterSelectedNode = false;

  @override
  void dispose() {
    _selectedNodeFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(mihomoGroupsProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final visibleGroups = mode == Mode.global
        ? groups
            .where((group) => group.name == 'GLOBAL')
            .toList(growable: false)
        : groups
            .where((group) => !group.hidden && group.name != 'GLOBAL')
            .toList(growable: false);
    final currentName = mode == Mode.global
        ? 'GLOBAL'
        : widget.initialGroupName ??
            ref.read(coreGatewayProvider).getCurrentGroupName();
    final group =
        visibleGroups.where((item) => item.name == currentName).firstOrNull ??
            (visibleGroups.isEmpty ? null : visibleGroups.first);

    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(l10n.xboardNodeSelection),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _updating || _testing ? null : _runUpdate,
            icon: _updating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(l10n.xboardUpdateNodes),
          ),
          TextButton.icon(
            onPressed: _testing || _updating ? null : _runLatencyTest,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(l10n.xboardTestLatency),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildPageBody(group, mode),
    );
  }

  Widget _buildPageBody(MihomoGroup? group, Mode mode) {
    final content = group == null
        ? LayoutBuilder(
            builder: (context, constraints) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).xboardNoAvailableNodes,
                    ),
                  ),
                ),
              ],
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final useFullLandscapeWidth = !system.isDesktop &&
                  constraints.maxWidth > constraints.maxHeight;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: useFullLandscapeWidth ? double.infinity : 760,
                  ),
                  child: _buildNodes(group, mode),
                ),
              );
            },
          );

    if (system.isDesktop || system.isTV) return content;
    return RefreshIndicator(
      key: const Key('nodes_pull_to_refresh'),
      onRefresh: _runUpdate,
      child: content,
    );
  }

  Widget _buildOverview(BuildContext context, Mode mode) {
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      elevation: XbUiCardStyle.elevation(context),
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.hub_outlined, color: primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: Localizations.localeOf(context).languageCode ==
                                  'zh'
                              ? '当前${l10n.xboardProxyMode}：'
                              : 'Current ${l10n.xboardProxyMode}: ',
                        ),
                        TextSpan(
                          text: switch (mode) {
                            Mode.rule => l10n.rule,
                            Mode.global => l10n.global,
                            Mode.direct => l10n.direct,
                          },
                          style: TextStyle(color: primary),
                        ),
                      ],
                    ),
                    style: XbUiText.cardTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch (mode) {
                      Mode.rule => l10n.xboardProxyModeRuleDescription,
                      Mode.global => l10n.xboardProxyModeGlobalDescription,
                      Mode.direct => l10n.xboardProxyModeDirectDescription,
                    },
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodes(MihomoGroup group, Mode mode) {
    final l10n = AppLocalizations.of(context);
    final nodes = group.nodes.toList();
    final selectedIndex =
        nodes.indexWhere((node) => node.name == group.selected);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
                ? 2
                : 1;
        _centerSelectedNode(selectedIndex, constraints.maxHeight, columns);
        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildOverview(context, mode)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: _itemExtent,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final node = nodes[index];
                    final selected = node.name == group.selected;
                    final primary = Theme.of(context).colorScheme.primary;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selected
                            ? primary.withValues(alpha: 0.08)
                            : XbUiCardStyle.background(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: selected
                                ? primary.withValues(alpha: 0.65)
                                : XbUiTokens.cardBorder(context),
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: XbPointerCursor(
                          enabled: !selected && !_selecting,
                          child: InkWell(
                            focusNode: system.isTV && selected
                                ? _selectedNodeFocusNode
                                : null,
                            autofocus: system.isTV && selected,
                            onTap: _selecting
                                ? null
                                : selected
                                    ? (system.isTV ? () {} : null)
                                    : () => _selectNode(group.name, node.name),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 21,
                                    color: selected
                                        ? primary
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                  const SizedBox(width: 9),
                                  EmojiText(
                                    NodeCountryResolver.resolveFlag(node.name),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          node.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: selected
                                                    ? XbFontWeight.semibold
                                                    : null,
                                              ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            _SmallTag(label: node.type),
                                            if (selected) ...[
                                              const SizedBox(width: 6),
                                              _SmallTag(
                                                label: l10n.xboardCurrentNode,
                                                color: primary,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _DelayBadge(
                                    node: node,
                                    testing: _testingNodes.contains(node.name),
                                    onTap: system.isTV || _testing || _updating
                                        ? null
                                        : () => _runSingleNodeLatencyTest(
                                              group.name,
                                              node.name,
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: nodes.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _centerSelectedNode(
    int selectedIndex,
    double viewportHeight,
    int columns,
  ) {
    if (_didCenterSelectedNode || selectedIndex < 0) return;
    _didCenterSelectedNode = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final selectedRow = selectedIndex ~/ columns;
      final target =
          selectedRow * _itemExtent - (viewportHeight - _itemExtent) / 2;
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
      if (system.isTV) {
        _requestSelectedNodeFocus();
      }
    });
  }

  void _requestSelectedNodeFocus([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_selectedNodeFocusNode.canRequestFocus) return;
      if (_selectedNodeFocusNode.context != null) {
        _selectedNodeFocusNode.requestFocus();
        return;
      }
      if (attempt < 2) {
        _requestSelectedNodeFocus(attempt + 1);
      }
    });
  }

  Future<void> _selectNode(String groupName, String nodeName) async {
    setState(() => _selecting = true);
    try {
      await ref.read(coreGatewayProvider).selectNode(
            groupName: groupName,
            nodeName: nodeName,
          );
      ref.invalidate(mihomoGroupsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _reloadNodes() async {
    final url = ref.read(subscriptionInfoProvider)?.subscribeUrl;
    if (url?.isNotEmpty == true) {
      await ref
          .read(profileImportProvider.notifier)
          .importSubscription(url!, forceRefresh: true);
      return;
    }
    final gateway = ref.read(coreGatewayProvider);
    await gateway.applyCurrentProfile();
    await gateway.refreshGroups();
  }

  Future<void> _runUpdate() async {
    if (_updating || _testing) return;
    setState(() => _updating = true);
    try {
      await _reloadNodes();
      ref.invalidate(mihomoGroupsProvider);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _runLatencyTest() async {
    final group = ref.read(mihomoGroupsProvider).where((item) {
      final mode = ref.read(patchClashConfigProvider).mode;
      final currentName = mode == Mode.global
          ? 'GLOBAL'
          : widget.initialGroupName ??
              ref.read(coreGatewayProvider).getCurrentGroupName();
      return item.name == currentName;
    }).firstOrNull;
    final names = group?.nodes.map((node) => node.name).toSet() ?? <String>{};
    _testing = true;
    _markNodesTesting(names);
    // Android FFI can return before Flutter paints the next frame. Ensure the
    // node delay area visibly enters its testing state first.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await autoLatencyService.testCurrentGroupNodes(
        maxNodes: 999,
        onResult: (nodeName) => unawaited(_finishNodeTesting(nodeName)),
      );
    } finally {
      if (mounted) {
        await Future.wait(names.map(_finishNodeTesting));
        if (mounted) setState(() => _testing = false);
      }
    }
  }

  Future<void> _runSingleNodeLatencyTest(
    String groupName,
    String nodeName,
  ) async {
    if (_testingNodes.contains(nodeName)) return;
    final sourceGroup = ref
        .read(groupsProvider)
        .where(
          (group) => group.name == groupName,
        )
        .firstOrNull;
    final proxy = sourceGroup?.all
        .where(
          (proxy) => proxy.name == nodeName,
        )
        .firstOrNull;
    if (proxy == null) return;
    _markNodesTesting({nodeName});
    await WidgetsBinding.instance.endOfFrame;
    try {
      await autoLatencyService.testProxy(proxy, forceTest: true);
    } finally {
      await _finishNodeTesting(nodeName);
    }
  }

  void _markNodesTesting(Set<String> names) {
    final generation = ++_testingGeneration;
    final startedAt = DateTime.now();
    setState(() {
      for (final name in names) {
        _testingNodes.add(name);
        _testingStartedAt[name] = startedAt;
        _testingGenerations[name] = generation;
      }
    });
  }

  Future<void> _finishNodeTesting(String nodeName) async {
    final generation = _testingGenerations[nodeName];
    final startedAt = _testingStartedAt[nodeName];
    if (generation == null || startedAt == null) return;
    final remaining =
        _minimumTestingIndicatorDuration - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted || _testingGenerations[nodeName] != generation) return;
    setState(() {
      _testingNodes.remove(nodeName);
      _testingStartedAt.remove(nodeName);
      _testingGenerations.remove(nodeName);
    });
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: effectiveColor,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _DelayBadge extends StatelessWidget {
  const _DelayBadge({
    required this.node,
    required this.testing,
    required this.onTap,
  });

  final MihomoNode node;
  final bool testing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget content;
    if (testing) {
      content = SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ));
      return _LatencyTapTarget(content: content, onTap: null);
    }
    final Color color;
    final String label;
    if (node.timedOut) {
      color = XbUiStatusColor.error(context);
      label = l10n.xboardTimeout;
    } else if (!node.hasDelay || node.delayMs == 0) {
      color = XbUiStatusColor.muted(context);
      label = '--';
    } else {
      color = node.delayMs! < 500
          ? XbUiStatusColor.success(context)
          : XbUiStatusColor.pending(context);
      label = '${node.delayMs}ms';
    }
    content = Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: XbFontWeight.semibold,
        color: color,
      ),
    );
    return _LatencyTapTarget(content: content, onTap: onTap);
  }
}

class _LatencyTapTarget extends StatelessWidget {
  const _LatencyTapTarget({required this.content, required this.onTap});

  final Widget content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (system.isTV) {
      return ExcludeFocus(
        child: SizedBox(
          width: 64,
          height: 42,
          child: Center(child: content),
        ),
      );
    }
    return Tooltip(
      message: AppLocalizations.of(context).xboardTestLatency,
      child: MouseRegion(
        cursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            height: 42,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
