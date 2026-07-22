import 'package:flutter/material.dart';

/// Visual font-weight tokens tuned for Flutter's precise variable-font axis.
///
/// Flutter 3.41 maps [FontWeight] directly to a variable font's `wght` axis.
/// Keeping emphasized text one step below the old numeric declarations
/// restores the visual hierarchy used by earlier client builds.
abstract final class XbFontWeight {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w500;
  static const FontWeight bold = FontWeight.w600;
  static const FontWeight heavy = FontWeight.w700;
}
