import 'package:flutter/material.dart';

class AdaptiveAmountText extends StatelessWidget {
  const AdaptiveAmountText({
    super.key,
    required this.value,
    required this.compactValue,
    this.style,
    this.textAlign,
  });

  final String value;
  final String compactValue;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
        final fullValueFits = !constraints.hasBoundedWidth ||
            _textWidth(context, value, effectiveStyle) <= constraints.maxWidth;
        final displayedValue = fullValueFits ? value : compactValue;
        final text = Text(
          displayedValue,
          maxLines: 1,
          textAlign: textAlign,
          style: style,
        );
        if (!constraints.hasBoundedWidth ||
            _textWidth(context, displayedValue, effectiveStyle) <=
                constraints.maxWidth) {
          return text;
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: text,
        );
      },
    );
  }

  double _textWidth(
    BuildContext context,
    String text,
    TextStyle effectiveStyle,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}
