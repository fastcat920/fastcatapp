import 'package:fl_clash/xboard/features/shared/styles/font_weights.dart';
import 'package:flutter/material.dart';

class XbPointerCursor extends StatelessWidget {
  const XbPointerCursor({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: child,
    );
  }
}

/// XBoard UI tokens for visual consistency across pages.
class XbUiTokens {
  XbUiTokens._();

  static const Color pageBackgroundLight = Color(0xFFFAFBFD);
  static const Color cardBorderLight = Color(0xFFEEF0F4);

  static const Color inputFillLight = Color(0xFFF5F7FA);
  static const Color dividerLight = Color(0xFFF0F2F5);
  static const Color tabBarBackgroundLight = Color(0xFFF0F4F8);
  static const Color chevronLight = Color(0xFFBCC3CE);

  /// Theme-aware page background.
  static Color pageBackground(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : pageBackgroundLight;
  }

  /// Theme-aware card border.
  static Color cardBorder(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.outline.withValues(alpha: 0.18)
        : cardBorderLight;
  }

  static const double radiusCard = 20;
  static const double radiusCardCompact = 14;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusXl = 24;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets listCardGapBottom10 = EdgeInsets.only(bottom: 10);
}

class XbUiCardStyle {
  XbUiCardStyle._();

  static Color background(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return isDark ? theme.colorScheme.surfaceContainerLow : Colors.white;
  }

  static Color? shadowColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? null
        : Colors.black.withValues(alpha: 0.08);
  }

  static double elevation(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? 0 : 1;
  }

  static RoundedRectangleBorder shape(
    BuildContext context, {
    double radius = XbUiTokens.radiusCard,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: isDark
          ? BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.14),
              width: 1,
            )
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
            ?.copyWith(fontWeight: XbFontWeight.bold) ??
        const TextStyle(fontSize: 20, fontWeight: XbFontWeight.bold);
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: XbFontWeight.semibold) ??
        const TextStyle(fontSize: 16, fontWeight: XbFontWeight.semibold);
  }

  static TextStyle cardTitle(BuildContext context) {
    return Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: XbFontWeight.semibold) ??
        const TextStyle(fontSize: 14, fontWeight: XbFontWeight.semibold);
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

  static ButtonStyle filledPrimary(
    BuildContext context, {
    bool busy = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      // A running action is non-interactive but should not look unavailable.
      // Its spinner and status label already communicate the temporary state.
      disabledBackgroundColor: busy ? colorScheme.primary : null,
      disabledForegroundColor: busy ? colorScheme.onPrimary : null,
    );
  }

  static ButtonStyle filledIconPrimary(
    BuildContext context, {
    bool busy = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      disabledBackgroundColor: busy ? colorScheme.primary : null,
      disabledForegroundColor: busy ? colorScheme.onPrimary : null,
    );
  }

  static ButtonStyle filledDanger(
    BuildContext context, {
    bool busy = false,
  }) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFFF44336),
      foregroundColor: Colors.white,
      disabledBackgroundColor: busy ? const Color(0xFFF44336) : null,
      disabledForegroundColor: busy ? Colors.white : null,
    );
  }

  static ButtonStyle outlinedNeutral(BuildContext context) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  static Color pending(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFFB74D)
          : const Color(0xFFFF9800);
  static Color pendingByTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFFFFB74D)
          : const Color(0xFFFF9800);
  static Color processing(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color processingByTheme(ThemeData theme) => theme.colorScheme.primary;
  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF66BB6A)
          : const Color(0xFF4CAF50);
  static Color successByTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFF66BB6A)
          : const Color(0xFF4CAF50);
  static Color error(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFEF5350)
          : const Color(0xFFF44336);
  static Color errorByTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFFEF5350)
          : const Color(0xFFF44336);
  static Color info(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF42A5F5)
          : const Color(0xFF2196F3);
  static Color infoByTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFF42A5F5)
          : const Color(0xFF2196F3);
  static Color offset(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFAB47BC)
          : const Color(0xFF9C27B0);
  static Color offsetByTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFFAB47BC)
          : const Color(0xFF9C27B0);
  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
  static Color mutedByTheme(ThemeData theme) => theme.colorScheme.outline;
}
