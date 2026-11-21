import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';

class XbMenuTrailing extends StatelessWidget {
  const XbMenuTrailing({super.key, this.value, this.showChevron = true});

  final String? value;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(
            value!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (value != null && showChevron) const SizedBox(width: 4),
        if (showChevron)
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.onSurfaceVariant
                : XbUiTokens.chevronLight,
          ),
      ],
    );
  }
}
