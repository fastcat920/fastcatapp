import 'package:flutter/material.dart';

/// Visual font-weight tokens tuned for Flutter's precise variable-font axis.
///
/// Flutter 3.44 maps [FontWeight] directly to a variable font's `wght` axis.
/// Keep every explicit emphasis level at w500 so variable system fonts do not
/// render selected labels, headings, prices, or rich text excessively heavy.
abstract final class XbFontWeight {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w500;
  static const FontWeight bold = FontWeight.w500;
  static const FontWeight heavy = FontWeight.w500;
}
