import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the cards aligned with other mobile pages while distributing only
/// vertical space. A short viewport scrolls instead of shrinking tap targets.
class MobileHomeLayout extends StatelessWidget {
  const MobileHomeLayout({
    super.key,
    required this.information,
    required this.connection,
    required this.nodeSelector,
    required this.informationHeight,
    required this.connectionHeight,
    required this.nodeHeight,
  });

  final Widget information;
  final Widget connection;
  final Widget nodeSelector;
  final double informationHeight;
  final double connectionHeight;
  final double nodeHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const topInset = 12.0;
      const bottomInset = 24.0;
      const minimumGap = 24.0;
      final minimumHeight = topInset +
          informationHeight +
          minimumGap * 2 +
          connectionHeight +
          nodeHeight +
          bottomInset;
      return SingleChildScrollView(
        child: SizedBox(
          height: math.max(constraints.maxHeight, minimumHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, topInset, 16, bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: informationHeight, child: information),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: minimumGap),
                    child: Center(
                      child:
                          SizedBox(height: connectionHeight, child: connection),
                    ),
                  ),
                ),
                SizedBox(height: nodeHeight, child: nodeSelector),
              ],
            ),
          ),
        ),
      );
    });
  }
}
