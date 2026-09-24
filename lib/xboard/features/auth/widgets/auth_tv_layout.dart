import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

/// Shared Android TV sizing for authentication screens.
abstract final class AuthTvLayout {
  static const double contentMaxWidth = 360;
  static const double toolbarHeight = 60;
  static const double horizontalPadding = 24;
  static const double compactGap = 12;
  static const double sectionGap = 16;

  /// Authentication forms are intentionally denser than the rest of the TV UI.
  /// The application-level TV scaler is designed for dashboard content and makes
  /// multi-field forms too large at 720p.
  static Widget apply(BuildContext context, Widget child) {
    if (!system.isTV) return child;
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: child,
    );
  }
}
