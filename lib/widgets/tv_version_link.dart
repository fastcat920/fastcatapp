import 'package:flutter/material.dart';
import 'tv_focusable.dart';

class TVVersionLink extends StatelessWidget {
  const TVVersionLink(
      {super.key,
      required this.label,
      required this.hasUpdate,
      required this.onPressed});
  final String label;
  final bool hasUpdate;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Center(
      child: TVFocusable(
          key: const Key('tv-version-focus'),
          borderRadius: BorderRadius.circular(6),
          onPressed: onPressed,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Badge(
                  isLabelVisible: hasUpdate,
                  child: Text(label,
                      key: const Key('tv-current-version'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.72)))))));
}
