import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

/// Restores a usable D-pad focus target after a modal route is dismissed.
class TvFocusRestoration {
  TvFocusRestoration._();

  static FocusNode? _defaultFocusNode;

  static FocusNode? capture() {
    if (!system.isTV) return null;
    return FocusManager.instance.primaryFocus;
  }

  static void registerDefault(FocusNode node) {
    if (!system.isTV) return;
    _defaultFocusNode = node;
  }

  static void unregisterDefault(FocusNode node) {
    if (identical(_defaultFocusNode, node)) {
      _defaultFocusNode = null;
    }
  }

  static void restore(BuildContext context, FocusNode? previousFocus) {
    if (!system.isTV) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (_requestIfAvailable(previousFocus)) return;
      if (_requestIfAvailable(_defaultFocusNode)) return;
      FocusScope.of(context).nextFocus();
    });
  }

  static bool _requestIfAvailable(FocusNode? node) {
    if (node == null || node.context == null || !node.canRequestFocus) {
      return false;
    }
    node.requestFocus();
    return true;
  }
}
