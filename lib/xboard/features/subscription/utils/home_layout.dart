import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

/// Whether the home page needs its compact layout before the root navigation
/// is removed. Keeping this calculation shared prevents the extra space from
/// making the announcement card reappear after navigation has been hidden.
bool shouldUseCompactHomeLayout(BuildContext context) {
  if (system.isTV) return true;
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    return false;
  }

  final mediaQuery = MediaQuery.of(context);
  final size = mediaQuery.size;
  if (size.width > size.height) {
    return size.height < 560;
  }

  // The home body's available height is reduced by the mobile navigation bar,
  // and by the app bar on normal-height portrait screens.
  final hasMobileAppBar = size.height >= 640;
  final contentHeight = size.height -
      68 -
      mediaQuery.padding.bottom -
      (hasMobileAppBar ? kToolbarHeight + mediaQuery.padding.top : 0);
  return contentHeight < 560;
}
