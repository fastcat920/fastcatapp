import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_ext/window_ext.dart';
import 'package:window_manager/window_manager.dart';

class WindowManager extends ConsumerStatefulWidget {
  final Widget child;

  const WindowManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<WindowManager> createState() => _WindowContainerState();
}

class _WindowContainerState extends ConsumerState<WindowManager>
    with WindowListener, WindowExtListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      appSettingProvider.select((state) => state.autoLaunch),
      (prev, next) {
        if (prev != next) {
          debouncer.call(
            FunctionTag.autoLaunch,
            () {
              autoLaunch?.updateStatus(next);
            },
          );
        }
      },
    );
    windowExtManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    await globalState.appController.handleBackOrExit();
    super.onWindowClose();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    commonPrint.log("focus");
    render?.resume();
  }

  @override
  Future<void> onShouldTerminate() async {
    await globalState.appController.handleExit();
    super.onShouldTerminate();
  }

  @override
  Future<void> onWindowMoved() async {
    super.onWindowMoved();
    final offset = await windowManager.getPosition();
    ref.read(windowSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            top: offset.dy,
            left: offset.dx,
          ),
        );
  }

  @override
  Future<void> onWindowResized() async {
    super.onWindowResized();
    final size = await windowManager.getSize();
    ref.read(windowSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            width: size.width,
            height: size.height,
          ),
        );
  }

  @override
  void onWindowMinimize() async {
    globalState.appController.savePreferencesDebounce();
    commonPrint.log("minimize");
    render?.pause();
    super.onWindowMinimize();
  }

  @override
  void onWindowRestore() {
    commonPrint.log("restore");
    render?.resume();
    super.onWindowRestore();
  }

  @override
  Future<void> dispose() async {
    windowManager.removeListener(this);
    windowExtManager.removeListener(this);
    super.dispose();
  }
}

class WindowHeaderContainer extends StatelessWidget {
  final Widget child;

  const WindowHeaderContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, child) {
        final version = ref.watch(versionProvider);
        if (version <= 10 && Platform.isMacOS) {
          return child!;
        }
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: kHeaderHeight,
                ),
                Expanded(
                  flex: 1,
                  child: child!,
                ),
              ],
            ),
            const WindowHeader(),
          ],
        );
      },
      child: child,
    );
  }
}

class WindowHeader extends StatefulWidget {
  const WindowHeader({super.key});

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  final isPinNotifier = ValueNotifier<bool>(false);
  StreamSubscription<Map<String, dynamic>>? _configSub;

  @override
  void initState() {
    super.initState();
    _initNotifier();
    // 监听远程配置变化，配置加载完后刷新客服图标显示状态
    // WindowHeader 在 XBoardConfig 初始化之前就创建，直接访问 configChangeStream
    // 会触发 StateError('XBoardConfig not initialized')，导致启动即崩溃。
    // 延迟到初始化完成后再订阅。
    _initConfigListener();
  }

  void _initConfigListener() async {
    // 如果已初始化直接监听，否则轮询等待
    while (!XBoardConfig.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
    _configSub = XBoardConfig.configChangeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  _initNotifier() async {
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    isPinNotifier.dispose();
    super.dispose();
  }

  _updatePin() async {
    final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }


  _buildActions() {
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    const iconSize = 18.0;
    const btnSize = 32.0;
    return Row(
      children: [
        // 置顶
        SizedBox(
          width: btnSize,
          height: btnSize,
          child: IconButton(
            onPressed: () => _updatePin(),
            padding: EdgeInsets.zero,
            icon: ValueListenableBuilder(
              valueListenable: isPinNotifier,
              builder: (_, value, ___) {
                return Icon(
                  value ? Icons.push_pin : Icons.push_pin_outlined,
                  size: iconSize,
                  color:
                      value ? Theme.of(context).colorScheme.primary : iconColor,
                );
              },
            ),
          ),
        ),
        // 最小化
        SizedBox(
          width: btnSize,
          height: btnSize,
          child: IconButton(
            onPressed: () => windowManager.minimize(),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.remove, size: iconSize, color: iconColor),
          ),
        ),
        // 关闭
        SizedBox(
          width: btnSize,
          height: btnSize,
          child: IconButton(
            onPressed: () => globalState.appController.handleBackOrExit(),
            padding: EdgeInsets.zero,
            hoverColor: Colors.red.withValues(alpha: 0.1),
            icon: Icon(Icons.close, size: iconSize, color: iconColor),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Positioned(
            child: GestureDetector(
              onPanStart: (_) {
                windowManager.startDragging();
              },
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.centerLeft,
                height: kHeaderHeight,
              ),
            ),
          ),
          if (!Platform.isMacOS)
            Positioned(
              right: 0,
              child: _buildActions(),
            ),
        ],
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircleAvatar(
              foregroundImage: AssetImage("assets/images/icon.png"),
              backgroundColor: Colors.transparent,
            ),
          ),
          SizedBox(
            width: 8,
          ),
          Text(
            appName,
          ),
        ],
      ),
    );
  }
}
