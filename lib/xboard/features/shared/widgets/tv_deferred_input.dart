import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TVDeferredInputBuilder = Widget Function(
  BuildContext context,
  FocusNode? focusNode,
  bool readOnly,
  bool showCursor,
  VoidCallback beginEditing,
);

class TVDeferredInput extends StatefulWidget {
  final TVDeferredInputBuilder builder;
  final BorderRadius? borderRadius;

  const TVDeferredInput({
    super.key,
    required this.builder,
    this.borderRadius,
  });

  @override
  State<TVDeferredInput> createState() => _TVDeferredInputState();
}

class _TVDeferredInputState extends State<TVDeferredInput> {
  late final FocusNode _selectFocusNode;
  late final FocusNode _editFocusNode;
  bool _isSelecting = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _selectFocusNode = FocusNode();
    _editFocusNode = FocusNode(canRequestFocus: false);
    _editFocusNode.addListener(_handleEditFocusChange);
  }

  @override
  void dispose() {
    _editFocusNode.removeListener(_handleEditFocusChange);
    _selectFocusNode.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _handleEditFocusChange() {
    if (!_editFocusNode.hasFocus && _isEditing && mounted) {
      setState(() {
        _isEditing = false;
        _editFocusNode.canRequestFocus = false;
      });
    }
  }

  void _beginEditing() {
    if (!system.isTV || _isEditing) return;
    setState(() {
      _isEditing = true;
      _editFocusNode.canRequestFocus = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _editFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      _beginEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!system.isTV) {
      return widget.builder(context, null, false, true, () {});
    }

    _editFocusNode.canRequestFocus = _isEditing;
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _selectFocusNode,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (focused) {
        setState(() => _isSelecting = focused);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _beginEditing,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
            border: _isSelecting && !_isEditing
                ? Border.all(
                    color: colorScheme.primary,
                    width: 2,
                  )
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: widget.builder(
            context,
            _editFocusNode,
            !_isEditing,
            _isEditing,
            _beginEditing,
          ),
        ),
      ),
    );
  }
}
