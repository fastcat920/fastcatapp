import 'package:flutter/material.dart';

/// Compatibility shim for Flutter versions that do not provide
/// RoundedSuperellipseBorder.
///
/// It behaves like a rounded rectangle border, which is close enough for the
/// current app styling and keeps older SDKs compiling.
class RoundedSuperellipseBorder extends RoundedRectangleBorder {
  const RoundedSuperellipseBorder({
    super.side,
    required BorderRadiusGeometry borderRadius,
  }) : super(borderRadius: borderRadius);
}
