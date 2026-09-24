import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

enum XbDialogTone { neutral, warning, danger }

/// Shared confirmation surface for every irreversible or blocking action.
class XbConfirmDialog extends StatelessWidget {
  const XbConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.tone = XbDialogTone.neutral,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final XbDialogTone tone;
  final IconData? icon;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    XbDialogTone tone = XbDialogTone.neutral,
    IconData? icon,
    bool barrierDismissible = true,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => XbConfirmDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            tone: tone,
            icon: icon,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final isDanger = tone == XbDialogTone.danger;
    final isWarning = tone == XbDialogTone.warning;
    final color = isDanger
        ? theme.colorScheme.error
        : isWarning
            ? XbUiStatusColor.pending(context)
            : theme.colorScheme.primary;
    final displayIcon = icon ??
        (isDanger
            ? Icons.warning_amber_rounded
            : isWarning
                ? Icons.info_outline
                : Icons.help_outline);

    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      icon: Icon(displayIcon, color: color),
      title: Text(title, style: XbUiText.sectionTitle(context)),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(cancelLabel ?? (chinese ? '取消' : 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDanger
              ? XbUiButton.filledDanger(context)
              : XbUiButton.filledPrimary(context),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Shared single-choice dialog used by settings selectors.
class XbChoiceDialog<T> extends StatelessWidget {
  const XbChoiceDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.labelBuilder,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T value) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(title, style: XbUiText.sectionTitle(context)),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                _ChoiceTile<T>(
                  value: options[index],
                  selected: options[index] == selected,
                  label: labelBuilder(options[index]),
                ),
                if (index != options.length - 1)
                  Divider(
                    height: 1,
                    indent: 52,
                    color: XbUiTokens.cardBorder(context),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.value,
    required this.selected,
    required this.label,
  });

  final T value;
  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(XbUiTokens.radiusSm);
    void select() => Navigator.of(context).pop(value);
    return TVFocusable(
      borderRadius: radius,
      onPressed: select,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: radius),
        focusColor: Colors.transparent,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(label),
        onTap: select,
      ),
    );
  }
}
