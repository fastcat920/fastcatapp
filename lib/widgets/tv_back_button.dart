import 'package:flutter/material.dart';
import 'tv_focusable.dart';

class TVBackButton extends StatelessWidget {
  const TVBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    void back() {
      Navigator.of(context).maybePop();
    }

    return Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
        child: TVFocusable(
            borderRadius: radius,
            onPressed: back,
            child: IconButton(
                onPressed: back,
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.10),
                    shape: RoundedRectangleBorder(borderRadius: radius)))));
  }
}
