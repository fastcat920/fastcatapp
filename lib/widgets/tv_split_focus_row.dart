import 'package:flutter/material.dart';
import 'tv_focusable.dart';

/// Separate remote targets inside one card. The inset keeps either focus ring
/// clear of the card border and the neighbouring action.
class TVSplitFocusRow extends StatelessWidget {
  const TVSplitFocusRow(
      {super.key,
      required this.content,
      required this.action,
      required this.onSelect,
      required this.onAction,
      this.focusNode,
      this.actionFocusNode,
      this.autofocus = false,
      this.onKeyEvent,
      this.actionOnKeyEvent,
      this.actionWidth = 56});
  final Widget content, action;
  final VoidCallback? onSelect, onAction;
  final FocusNode? focusNode, actionFocusNode;
  final bool autofocus;
  final FocusOnKeyEventCallback? onKeyEvent, actionOnKeyEvent;
  final double actionWidth;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: TVFocusable(
                  focusNode: focusNode,
                  autofocus: autofocus,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: onSelect,
                  onKeyEvent: onKeyEvent,
                  child: content)),
          const SizedBox(width: 4),
          SizedBox(
              width: actionWidth,
              child: TVFocusable(
                  focusNode: actionFocusNode,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: onAction,
                  onKeyEvent: actionOnKeyEvent,
                  child: Center(child: action))),
        ]),
      );
}
