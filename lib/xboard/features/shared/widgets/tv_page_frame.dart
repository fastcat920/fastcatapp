import 'package:fl_clash/common/common.dart' show system;
import 'package:flutter/material.dart';

/// Secondary TV pages share the home page's content gutters and safe area.
/// Non-TV callers retain their own existing layout.
class TVPageFrame extends StatelessWidget {
  const TVPageFrame({super.key, required this.child});
  final Widget child;
  static double horizontalInset(double width) => width >= 1400 ? 33 : 25;
  @override
  Widget build(BuildContext context) {
    if (!system.isTV) return child;
    return SafeArea(
      top: false,
      child: LayoutBuilder(builder: (context, constraints) {
        final horizontal = horizontalInset(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 19, horizontal, 23),
          child: SizedBox(width: double.infinity, child: child),
        );
      }),
    );
  }
}
