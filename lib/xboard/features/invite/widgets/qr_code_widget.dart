import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 200.0,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBg = backgroundColor ??
        (isDark ? theme.colorScheme.surfaceContainerLow : Colors.white);
    final effectiveBorderColor =
        isDark ? theme.colorScheme.outline : XbUiTokens.cardBorderLight;
    final muted = theme.colorScheme.onSurfaceVariant;

    if (data.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effectiveBorderColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code,
                size: 48,
                color: muted,
              ),
              const SizedBox(height: 8),
              Text(
                appLocalizations.noInvitationData,
                style: XbUiText.bodySmall(context, color: muted)
                    .copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: effectiveBorderColor),
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: effectiveBg,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor ?? theme.colorScheme.onSurface,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor ?? theme.colorScheme.onSurface,
        ),
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}
