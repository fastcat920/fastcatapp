import 'package:flutter/material.dart';

/// XBoard UI tokens for visual consistency across pages.
class XbUiTokens {
  XbUiTokens._();

  static const Color pageBackgroundLight = Color(0xFFFAFBFD);
  static const Color cardBorderLight = Color(0xFFEEF0F4);

  static const double radiusCard = 20;
  static const double radiusCardCompact = 14;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets listCardGapBottom10 = EdgeInsets.only(bottom: 10);
}

class XbUiCardStyle {
  XbUiCardStyle._();

  static RoundedRectangleBorder shape(
    BuildContext context, {
    double radius = XbUiTokens.radiusCard,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: isDark
          ? BorderSide.none
          : const BorderSide(color: XbUiTokens.cardBorderLight, width: 1),
    );
  }
}

class XbUiText {
  XbUiText._();

  static TextStyle pageTitle(BuildContext context) {
    return Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  }

  static TextStyle cardTitle(BuildContext context) {
    return Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  }

  static TextStyle bodySmall(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12, height: 1.4);
    return color == null ? base : base.copyWith(color: color);
  }
}

class XbUiDialog {
  XbUiDialog._();

  static ShapeBorder shape() => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      );

  static Color? background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? null : XbUiTokens.pageBackgroundLight;
  }

  static BorderSide? outlinedSide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? null : const BorderSide(color: XbUiTokens.cardBorderLight);
  }
}

class XbUiButton {
  XbUiButton._();

  static ButtonStyle filledPrimary(BuildContext context) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
    );
  }

  static ButtonStyle filledDanger(BuildContext context) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    );
  }

  static ButtonStyle outlinedNeutral(BuildContext context) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: XbUiDialog.outlinedSide(context),
    );
  }

  static ButtonStyle textChipPrimary(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class XbUiStatusColor {
  XbUiStatusColor._();

  static Color pending(BuildContext context) => Colors.orange;
  static Color pendingByTheme(ThemeData theme) => Colors.orange;
  static Color processing(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color processingByTheme(ThemeData theme) => theme.colorScheme.primary;
  static Color success(BuildContext context) => Colors.green;
  static Color successByTheme(ThemeData theme) => Colors.green;
  static Color error(BuildContext context) => Colors.red;
  static Color errorByTheme(ThemeData theme) => Colors.red;
  static Color info(BuildContext context) => Colors.blue;
  static Color infoByTheme(ThemeData theme) => Colors.blue;
  static Color offset(BuildContext context) => Colors.purple;
  static Color offsetByTheme(ThemeData theme) => Colors.purple;
  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
  static Color mutedByTheme(ThemeData theme) => theme.colorScheme.outline;
}
