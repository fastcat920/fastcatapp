import 'dart:async';

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
  bool _keyboardVisibleInSession = false;
  bool _waitingForKeyboardToHide = false;
  bool _reopenAfterKeyboardHide = false;
  int _editingSession = 0;
  Timer? _showKeyboardFallbackTimer;
  LogicalKeyboardKey? _pendingActivationKey;
  LogicalKeyboardKey? _pendingExitKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectFocusNode = widget.focusNode ?? FocusNode();
    _editFocusNode = FocusNode(canRequestFocus: false);
    _editFocusNode.addListener(_handleEditFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showKeyboardFallbackTimer?.cancel();
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

    if (_waitingForKeyboardToHide && !isKeyboardVisible) {
      _waitingForKeyboardToHide = false;
      if (_reopenAfterKeyboardHide) {
        _reopenAfterKeyboardHide = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _beginEditing();
        });
      }
      return;
    }

    if (!_isEditing) return;
    if (isKeyboardVisible) {
      _keyboardVisibleInSession = true;
    } else if (_keyboardVisibleInSession) {
      _endEditing(hideKeyboard: false);
    }
  }

  void _handleEditFocusChange() {
    if (!_editFocusNode.hasFocus && _isEditing && mounted) {
      _cancelEditingSession();
      setState(() {
        _isEditing = false;
        _editFocusNode.canRequestFocus = false;
      });
    }
  }

  void _beginEditing() {
    if (!system.isTV || _isEditing) return;
    if (_waitingForKeyboardToHide) {
      _reopenAfterKeyboardHide = true;
      return;
    }

    final session = ++_editingSession;
    _keyboardVisibleInSession = false;
    _showKeyboardFallbackTimer?.cancel();
    setState(() {
      _isEditing = true;
      _editFocusNode.canRequestFocus = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isEditing || session != _editingSession) return;
      _editFocusNode.requestFocus();
      _showKeyboardFallbackTimer = Timer(
        const Duration(milliseconds: 300),
        () {
          if (!mounted || !_isEditing || session != _editingSession) return;
          if (View.of(context).viewInsets.bottom > 0) {
            _keyboardVisibleInSession = true;
            return;
          }
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        },
      );
    });
  }

  void _endEditing({bool hideKeyboard = true}) {
    if (!_isEditing || !mounted) return;
    final keyboardIsVisible = View.of(context).viewInsets.bottom > 0;
    _cancelEditingSession();
    _waitingForKeyboardToHide = hideKeyboard && keyboardIsVisible;
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

  void _cancelEditingSession() {
    _editingSession++;
    _keyboardVisibleInSession = false;
    _showKeyboardFallbackTimer?.cancel();
    _showKeyboardFallbackTimer = null;
  }

  bool _isActivationKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  bool _isExitKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.escape;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    if (_pendingExitKey == key) {
      if (event is KeyUpEvent) _pendingExitKey = null;
      return KeyEventResult.handled;
    }

    if (_pendingActivationKey == key) {
      if (event is KeyUpEvent) {
        _pendingActivationKey = null;
        _beginEditing();
      }
      return KeyEventResult.handled;
    }

    if (_isEditing && _isExitKey(key) && event is KeyDownEvent) {
      _pendingExitKey = key;
      _endEditing();
      return KeyEventResult.handled;
    }

    if (!_isEditing && _isActivationKey(key) && event is KeyDownEvent) {
      _pendingActivationKey = key;
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
