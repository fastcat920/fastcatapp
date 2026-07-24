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
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  const TVDeferredInput({
    super.key,
    required this.builder,
    this.borderRadius,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<TVDeferredInput> createState() => _TVDeferredInputState();
}

class _TVDeferredInputState extends State<TVDeferredInput>
    with WidgetsBindingObserver {
  late final FocusNode _selectFocusNode;
  late final FocusNode _editFocusNode;
  bool _isSelecting = false;
  bool _isEditing = false;
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectFocusNode = widget.focusNode ?? FocusNode();
    _editFocusNode = FocusNode(canRequestFocus: false);
    _editFocusNode.addListener(_handleEditFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _wasKeyboardVisible = View.of(context).viewInsets.bottom > 0;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editFocusNode.removeListener(_handleEditFocusChange);
    if (widget.focusNode == null) {
      _selectFocusNode.dispose();
    }
    _editFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted || !system.isTV) return;
    final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    final keyboardWasDismissed = _wasKeyboardVisible && !isKeyboardVisible;
    _wasKeyboardVisible = isKeyboardVisible;
    if (keyboardWasDismissed && _isEditing) {
      _endEditing(hideKeyboard: false);
    }
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
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
    });
  }

  void _endEditing({bool hideKeyboard = true}) {
    if (!_isEditing || !mounted) return;
    setState(() {
      _isEditing = false;
      _editFocusNode.canRequestFocus = false;
    });
    _editFocusNode.unfocus();
    if (hideKeyboard) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectFocusNode.canRequestFocus) {
        _selectFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditing &&
        (event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack ||
            event.logicalKey == LogicalKeyboardKey.escape)) {
      _endEditing();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      _beginEditing();
      return KeyEventResult.handled;
    }
    return widget.onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
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
          child: ExcludeFocus(
            excluding: !_isEditing,
            child: widget.builder(
              context,
              _editFocusNode,
              !_isEditing,
              _isEditing,
              _beginEditing,
            ),
          ),
        ),
      ),
    );
  }
}
