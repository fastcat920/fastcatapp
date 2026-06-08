import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/xboard/widgets/navigation/desktop_navigation_rail.dart';
import 'package:fl_clash/xboard/widgets/navigation/mobile_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 适配性的 Shell 布局
/// 桌面端：侧边栏（主页/套餐/邀请/我的[/日志]）+ 内容区
/// 移动端：底部导航栏（主页/套餐/邀请/我的[/日志]）+ 内容区
class AdaptiveShellLayout extends ConsumerStatefulWidget {
  final StatefulNavigationShell child;

  const AdaptiveShellLayout({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AdaptiveShellLayout> createState() =>
      _AdaptiveShellLayoutState();
}

class _AdaptiveShellLayoutState extends ConsumerState<AdaptiveShellLayout> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      appSettingProvider.select((s) => s.logCapture),
      (prev, next) {
        if (prev == true && next == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final location = GoRouterState.of(context).uri.path;
            if (location.startsWith('/logs')) {
              context.go('/');
            }
          });
        }
      },
    );
  }

  void _onDestinationSelected(
      BuildContext context, int index, bool isDesktop, bool logCapture) {
    if (isDesktop) {
      // 桌面端索引动态调整：
      // Home(0) Plans(1) Invite(2) Mine(3) [Logs(4)]
      const inviteIdx = 2;
      const mineIdx = 3;
      const logsIdx = 4;

      if (index == 0) {
        context.go('/');
      } else if (index == 1) {
        context.go('/plans');
      } else if (index == inviteIdx) {
        context.go('/invite');
      } else if (index == mineIdx) {
        context.go('/mine');
      } else if (index == logsIdx && logCapture) {
        context.go('/logs');
      }
    } else {
      // 移动端：主页(0) 套餐(1) 邀请(2) 我的(3) [日志(4)]
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/plans');
          break;
        case 2:
          context.go('/invite');
          break;
        case 3:
          context.go('/mine');
          break;
        case 4:
          if (logCapture) context.go('/logs');
          break;
      }
    }
  }

  int _getCurrentIndex(BuildContext context, bool isDesktop, bool logCapture) {
    final location = GoRouterState.of(context).uri.path;

    if (isDesktop) {
      // 桌面端索引与 _onDestinationSelected 一致
      const inviteIdx = 2;
      const mineIdx = 3;
      const logsIdx = 4;

      if (location == '/') return 0;
      if (location.startsWith('/plans')) return 1;
      if (location.startsWith('/invite')) return inviteIdx;
      if (location.startsWith('/mine')) return mineIdx;
      if (location.startsWith('/logs') && logCapture) return logsIdx;
      return 0;
    } else {
      // 移动端导航高亮：主页(0) 套餐(1) 邀请(2) 我的(3) [日志(4)]
      if (location.startsWith('/plans')) return 1;
      if (location.startsWith('/invite')) return 2;
      if (location.startsWith('/mine')) return 3;
      if (location.startsWith('/logs') && logCapture) return 4;
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logCapture = ref.watch(
      appSettingProvider.select((s) => s.logCapture),
    );
    final size = MediaQuery.sizeOf(context);
    final useSideNavigation = size.width > size.height || system.isTV;
    final currentIndex =
        _getCurrentIndex(context, useSideNavigation, logCapture);

    if (useSideNavigation) {
      // 横向窗口/TV：侧边栏 + 内容区（无外层 Scaffold）
      return Row(
        children: [
          FocusTraversalGroup(
            child: DesktopNavigationRail(
              selectedIndex: currentIndex,
              logCapture: logCapture,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index, true, logCapture),
            ),
          ),
          Expanded(
            child: FocusTraversalGroup(
              child: widget.child,
            ),
          ),
        ],
      );
    } else {
      // 纵向窗口：Scaffold + 底部导航栏
      return Scaffold(
        body: widget.child,
        bottomNavigationBar: MobileNavigationBar(
          selectedIndex: currentIndex,
          logCapture: logCapture,
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, index, false, logCapture),
        ),
      );
    }
  }
}
