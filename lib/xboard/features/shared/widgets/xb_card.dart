import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

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
    final defaultBorderRadius = BorderRadius.circular(20);
    final shape = XbUiCardStyle.shape(context);
    final shadowColor = XbUiCardStyle.shadowColor(context);

    final bgColor = backgroundColor ??
        (isSelected
            ? colorScheme.primaryContainer
            : XbUiCardStyle.background(context));

    return XbPointerCursor(
      enabled: onTap != null,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? defaultBorderRadius,
          boxShadow: shadowColor == null
              ? null
              : [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          elevation: elevation ?? 0,
          borderRadius: borderRadius ?? defaultBorderRadius,
          color: bgColor,
          clipBehavior: Clip.antiAlias,
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
                    : Border.all(
                        color: shape.side.color,
                        width: shape.side.width,
                      ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
