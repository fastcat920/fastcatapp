import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Insets inherited from the screen must be expressed relative to the embedded
/// chat rectangle. Space occupied by navigation has already been removed.
class CustomerServiceViewport extends StatelessWidget {
  const CustomerServiceViewport(
      {super.key, required this.consumed, required this.child});

  final EdgeInsets consumed;
  final Widget child;

  EdgeInsets _remaining(EdgeInsets value) => EdgeInsets.fromLTRB(
        math.max(0, value.left - consumed.left),
        math.max(0, value.top - consumed.top),
        math.max(0, value.right - consumed.right),
        math.max(0, value.bottom - consumed.bottom),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
        builder: (context, constraints) => MediaQuery(
              data: media.copyWith(
                size: constraints.biggest,
                padding: _remaining(media.padding),
                viewPadding: _remaining(media.viewPadding),
                viewInsets: _remaining(media.viewInsets),
                systemGestureInsets: _remaining(media.systemGestureInsets),
              ),
              child: child,
            ));
  }
}
