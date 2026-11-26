import 'package:fl_clash/xboard/features/shared/styles/ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';

/// Shared vector indicator. A zero result means a test is in progress;
/// callers with a separate testing flag should normalize an idle zero to null.
class LatencyIndicator extends StatelessWidget {
  final int? delayValue;
  final bool timedOut;
  final VoidCallback? onTap;
  final bool isCompact;
  final bool showIcon;
  const LatencyIndicator(
      {super.key,
      required this.delayValue,
      this.timedOut = false,
      this.onTap,
      this.isCompact = false,
      this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final testing = delayValue == 0;
    final failed = delayValue != null && delayValue! < 0;
    final active =
        failed ? 1 : (delayValue != null && delayValue! >= 500 ? 2 : 3);
    final color = failed
        ? XbUiStatusColor.error(context)
        : active == 2
            ? XbUiStatusColor.pending(context)
            : XbUiStatusColor.success(context);
    final l10n = AppLocalizations.of(context);
    final label = switch ((testing, failed, timedOut)) {
      (true, _, _) => l10n.xboardTesting,
      (_, true, true) => l10n.xboardTimeout,
      (_, true, false) => l10n.xboardLatencyTestFailed,
      _ => l10n.xboardTestLatency,
    };
    final Widget icon = testing
        ? SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.7, color: theme.colorScheme.primary))
        : delayValue == null
            ? Icon(Icons.bolt_rounded,
                size: 22, color: theme.colorScheme.primary)
            : CustomPaint(
                size: const Size(26 * 2 / 3, 22 * 2 / 3),
                painter: LatencySignalPainter(
                    activeBars: active,
                    failed: failed,
                    color: color,
                    inactiveColor: theme.colorScheme.onSurface
                        .withValues(alpha: dark ? 0.22 : 0.14),
                    backgroundColor: theme.colorScheme.surface));
    final indicator = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: testing ? null : onTap,
      child: SizedBox(width: 32, height: 28, child: Center(child: icon)),
    );
    return Semantics(
      label: label,
      button: onTap != null && !testing,
      child: failed
          ? Tooltip(
              message: label, excludeFromSemantics: true, child: indicator)
          : indicator,
    );
  }
}

class LatencySignalPainter extends CustomPainter {
  const LatencySignalPainter(
      {required this.activeBars,
      required this.failed,
      required this.color,
      required this.inactiveColor,
      required this.backgroundColor});
  final int activeBars;
  final bool failed;
  final Color color, inactiveColor, backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final width = size.width * 0.21;
    for (var i = 0; i < 3; i++) {
      final height = size.height * (0.36 + i * 0.29);
      paint.color = i < activeBars ? color : inactiveColor;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  i * size.width * 0.33, size.height - height, width, height),
              Radius.circular(width * 0.42)),
          paint);
    }
    if (failed) {
      // Overlay the cross on the last two bars, keeping it inside the icon.
      final path = Path()
        ..moveTo(size.width * 0.53, size.height * 0.52)
        ..lineTo(size.width * 0.85, size.height * 0.89)
        ..moveTo(size.width * 0.85, size.height * 0.52)
        ..lineTo(size.width * 0.53, size.height * 0.89);
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * (4.5 / 26)
        ..color = backgroundColor;
      canvas.drawPath(path, paint);
      paint
        ..strokeWidth = size.width * (2.3 / 26)
        ..color = color;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(LatencySignalPainter oldDelegate) =>
      activeBars != oldDelegate.activeBars ||
      failed != oldDelegate.failed ||
      color != oldDelegate.color ||
      inactiveColor != oldDelegate.inactiveColor ||
      backgroundColor != oldDelegate.backgroundColor;
}

class LatencyQuality {
  static const int excellent = 50;
  static const int good = 100;
  static const int fair = 200;
  static const int poor = 500;
  static String getQualityLevel(int delay) {
    if (delay < 0) return '测速失败';
    if (delay <= excellent) return '优秀';
    if (delay <= good) return '良好';
    if (delay <= fair) return '一般';
    if (delay <= poor) return '较差';
    return '很差';
  }

  static String getQualityDescription(int delay) {
    if (delay < 0) return '测速失败，请重试';
    if (delay <= excellent) return '网络质量优秀，适合所有应用';
    if (delay <= good) return '网络质量良好，适合大多数应用';
    if (delay <= fair) return '网络质量一般，可用于基本应用';
    if (delay <= poor) return '网络质量较差，可能影响体验';
    return '网络质量很差，建议更换节点';
  }

  static IconData getQualityIcon(int delay) {
    if (delay < 0) return Icons.signal_wifi_off;
    if (delay <= excellent) return Icons.signal_wifi_4_bar;
    if (delay <= good) return Icons.signal_wifi_4_bar;
    if (delay <= fair) return Icons.signal_wifi_4_bar;
    if (delay <= poor) return Icons.signal_wifi_bad;
    return Icons.signal_wifi_0_bar;
  }
}
