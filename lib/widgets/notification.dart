import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextScaleNotification extends ConsumerStatefulWidget {
  final Widget child;
  final Function(TextScale textScale) onNotification;

  const TextScaleNotification({
    super.key,
    required this.child,
    required this.onNotification,
  });

  @override
  ConsumerState<TextScaleNotification> createState() =>
      _TextScaleNotificationState();
}

class _TextScaleNotificationState extends ConsumerState<TextScaleNotification> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      themeSettingProvider.select((state) => state.textScale),
      (prev, next) {
        if (prev != next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onNotification(next);
            }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
