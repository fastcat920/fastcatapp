import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';

/// Actions shared by the empty/error states of the home node selector.
class NodeRecoveryActions extends StatelessWidget {
  const NodeRecoveryActions({
    super.key,
    required this.isBusy,
    required this.onReload,
    required this.onSwitch,
  });

  final bool isBusy;
  final VoidCallback onReload;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reload = isBusy ? null : onReload;
    final switchNode = isBusy ? null : onSwitch;
    final reloadStyle = XbUiButton.textChipPrimary(context);
    final switchStyle = XbUiButton.filledPrimary(context).copyWith(
      minimumSize: const WidgetStatePropertyAll(Size(56, 30)),
      padding:
          const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
    );

    ButtonStyle tvStyle(ButtonStyle style) => system.isTV
        ? style.copyWith(
            // The focus border must follow the painted button, not a larger
            // invisible touch target. Mobile/desktop keep their existing style.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          )
        : style;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TVFocusable(
          borderRadius: BorderRadius.circular(XbUiTokens.radiusSm),
          focusableWhenDisabled: true,
          onPressed: reload,
          child: TextButton(
            onPressed: reload,
            style: tvStyle(reloadStyle),
            child: Text(l10n.xboardReloadNodes,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(width: 8),
        TVFocusable(
          borderRadius: BorderRadius.circular(XbUiTokens.radiusMd),
          // Use the existing foreground color for contrast against the fill.
          focusBorderColor: Theme.of(context).colorScheme.onPrimary,
          focusableWhenDisabled: true,
          onPressed: switchNode,
          child: ElevatedButton(
            onPressed: switchNode,
            style: tvStyle(switchStyle),
            child: Text(l10n.xboardSwitch,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }
}
