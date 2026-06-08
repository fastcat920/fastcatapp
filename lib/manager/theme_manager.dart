import 'dart:math';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/measure.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeManager extends ConsumerStatefulWidget {
  final Widget child;

  const ThemeManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ThemeManager> createState() => _ThemeManagerState();
}

class _ThemeManagerState extends ConsumerState<ThemeManager> {
  Size? _lastReportedSize;
  Size? _pendingSize;
  bool _viewSizeUpdateScheduled = false;

  void _scheduleViewSizeUpdate(Size size) {
    if (_lastReportedSize == size && _pendingSize == null) return;
    _pendingSize = size;
    if (_viewSizeUpdateScheduled) return;
    _viewSizeUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewSizeUpdateScheduled = false;
      final nextSize = _pendingSize;
      _pendingSize = null;
      if (!mounted || nextSize == null || _lastReportedSize == nextSize) {
        return;
      }
      _lastReportedSize = nextSize;
      globalState.appController.updateViewSize(nextSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textScale = ref.read(
      themeSettingProvider.select((state) => state.textScale),
    );
    final double textScaleFactor = max(
      min(
        textScale.enable ? textScale.scale : defaultTextScaleFactor,
        maxTextScale,
      ),
      minTextScale,
    );

    globalState.measure = Measure.of(context, textScaleFactor);
    globalState.theme = CommonTheme.of(context, textScaleFactor);
    final padding = MediaQuery.of(context).padding;
    final height = MediaQuery.of(context).size.height;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          textScaleFactor,
        ),
        padding: padding.copyWith(
          top: padding.top > height * 0.3 ? 20.0 : padding.top,
        ),
      ),
      child: LayoutBuilder(
        builder: (_, container) {
          _scheduleViewSizeUpdate(
            Size(container.maxWidth, container.maxHeight),
          );
          return widget.child;
        },
      ),
    );
  }
}
