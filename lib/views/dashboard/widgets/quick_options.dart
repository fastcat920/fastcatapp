import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) {
              return _TunSheetContent(type: type);
            },
          );
        },
        info: Info(
          label: appLocalizations.tun,
          iconData: Icons.stacked_line_chart,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 4,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.adjustSize(-2)
                        .toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final enable = ref.watch(patchClashConfigProvider
                      .select((state) => state.tun.enable));
                  return Switch(
                    value: enable,
                    onChanged: (value) {
                      if (value) {
                        globalState.appController.resetTunAdminDenied();
                      }
                      ref.read(patchClashConfigProvider.notifier).updateState(
                            (state) => state.copyWith.tun(
                              enable: value,
                            ),
                          );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _TunSheetContent extends ConsumerStatefulWidget {
  const _TunSheetContent({required this.type});

  final SheetType type;

  @override
  ConsumerState<_TunSheetContent> createState() => _TunSheetContentState();
}

class _TunSheetContentState extends ConsumerState<_TunSheetContent> {
  @override
  void initState() {
    super.initState();
    // 在 initState 注册监听，避免 rebuild 丢失订阅
    ref.listen(
      patchClashConfigProvider.select((s) => s.tun.enable),
      (prev, next) {
        debugPrint('[TunSheet] TUN状态变化: $prev -> $next, mounted=$mounted');
        if (prev != next && mounted) {
          debugPrint('[TunSheet] 尝试关闭弹窗...');
          try {
            final nav = Navigator.of(context, rootNavigator: true);
            debugPrint('[TunSheet] Navigator found, popping...');
            nav.pop();
            debugPrint('[TunSheet] pop() 调用完成');
          } catch (e, stack) {
            debugPrint('[TunSheet] pop() 失败: $e');
            debugPrint('[TunSheet] 尝试 rootNavigator...');
            try {
              Navigator.of(context, rootNavigator: true).pop();
              debugPrint('[TunSheet] rootNavigator pop() 成功');
            } catch (e2) {
              debugPrint('[TunSheet] rootNavigator pop() 也失败: $e2');
            }
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSheetScaffold(
      type: widget.type,
      body: generateListView(
        generateSection(
          items: [
            if (system.isDesktop) const TUNItem(closeOnChanged: true),
            if (Platform.isMacOS) const AutoSetSystemDnsItem(),
            const TunStackItem(),
          ],
        ),
      ),
      title: appLocalizations.tun,
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                body: generateListView(
                  generateSection(
                    items: [
                      SystemProxyItem(),
                      BypassDomainItem(),
                    ],
                  ),
                ),
                title: appLocalizations.systemProxy,
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.systemProxy,
          iconData: Icons.shuffle,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 4,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.adjustSize(-2)
                        .toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final systemProxy = ref.watch(networkSettingProvider
                      .select((state) => state.systemProxy));
                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: systemProxy,
                    onChanged: (value) {
                      ref.read(networkSettingProvider.notifier).updateState(
                            (state) => state.copyWith(
                              systemProxy: value,
                            ),
                          );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                body: generateListView(
                  generateSection(
                    items: [
                      const VPNItem(),
                      const VpnSystemProxyItem(),
                      const TunStackItem(),
                    ],
                  ),
                ),
                title: "VPN",
              );
            },
          );
        },
        info: Info(
          label: "VPN",
          iconData: Icons.stacked_line_chart,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 4,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.adjustSize(-2)
                        .toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final enable = ref.watch(
                    vpnSettingProvider.select(
                      (state) => state.enable,
                    ),
                  );
                  return Switch(
                    value: enable,
                    onChanged: (value) {
                      ref.read(vpnSettingProvider.notifier).updateState(
                            (state) => state.copyWith(
                              enable: value,
                            ),
                          );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
