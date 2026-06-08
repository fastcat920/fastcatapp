import 'package:flutter/material.dart';
class XBCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isSelected;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  const XBCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.isSelected = false,
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorderRadius = BorderRadius.circular(20);

    final bgColor = backgroundColor ??
        (isSelected
          ? (isDark ? colorScheme.primaryContainer : colorScheme.primaryContainer.withAlpha(77))
          : (isDark ? colorScheme.surfaceContainer : Colors.white));

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? defaultBorderRadius,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: colorScheme.primary.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        elevation: elevation ?? 0,
        borderRadius: borderRadius ?? defaultBorderRadius,
        color: bgColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? defaultBorderRadius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? defaultBorderRadius,
              border: isSelected
                  ? Border.all(
                      color: colorScheme.primary,
                      width: 2,
                    )
                  : (isDark ? null : Border.all(
                      color: const Color(0xFFEEF0F4),
                      width: 1,
                    )),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}