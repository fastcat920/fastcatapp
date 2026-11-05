import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper widget that adds D-pad focusable behavior for Android TV.
///
/// On non-TV platforms, this widget is transparent — it just renders [child].
/// On TV, it adds:
/// - Focus highlight (blue border glow when focused)
/// - D-pad Enter/OK key triggers [onPressed]
/// - Optional auto-focus
///
/// Usage:
/// ```dart
/// TVFocusable(
///   onPressed: () => doSomething(),
///   child: MyButton(),
/// )
/// ```
class TVFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;

  /// Keep temporary busy controls in D-pad navigation without accepting input.
  final bool focusableWhenDisabled;
  final FocusNode? focusNode;
  final BorderRadius? borderRadius;
  final Color? focusBorderColor;
  final FocusOnKeyEventCallback? onKeyEvent;

  const TVFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.focusableWhenDisabled = false,
    this.focusNode,
    this.borderRadius,
    this.focusBorderColor,
    this.onKeyEvent,
  });

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant TVFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _isFocused = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final delegatedResult = widget.onKeyEvent?.call(node, event);
    if (delegatedResult == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      // D-pad center / Enter / Select
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onPressed?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // On non-TV, just render child directly — no focus overhead
    if (!system.isTV) {
      return widget.child;
    }

    final materialButton = _materialButtonIn(widget.child);
    final states = <WidgetState>{
      if (widget.onPressed == null) WidgetState.disabled,
    };
    final buttonStyle = materialButton == null
        ? null
        : _TvStyledButton(materialButton).resolvedStyle(context, states);
    final shape = buttonStyle?.shape?.resolve(states);
    final ringColor = widget.focusBorderColor ??
        _contrastingFocusColor(
            context, buttonStyle?.backgroundColor?.resolve(states));
    final side = BorderSide(
      color: _isFocused ? ringColor : Colors.transparent,
      width: 2,
    );
    final Decoration decoration = shape != null
        ? ShapeDecoration(shape: shape.copyWith(side: side))
        : BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            border: Border.fromBorderSide(side),
          );

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.onPressed != null || widget.focusableWhenDisabled,
      descendantsAreFocusable: false,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          foregroundDecoration: decoration,
          child: _adaptMaterialButton(widget.child),
        ),
      ),
    );
  }
}

ButtonStyleButton? _materialButtonIn(Widget child) {
  if (child is ButtonStyleButton) return child;
  if (child is SizedBox && child.child != null) {
    return _materialButtonIn(child.child!);
  }
  return null;
}

Widget _adaptMaterialButton(Widget child) {
  if (child is ButtonStyleButton) return _TvStyledButton(child);
  if (child is SizedBox && child.child != null) {
    return SizedBox(
      key: child.key,
      width: child.width,
      height: child.height,
      child: _adaptMaterialButton(child.child!),
    );
  }
  return child;
}

Color _contrastingFocusColor(BuildContext context, Color? background) {
  final scheme = Theme.of(context).colorScheme;
  final fill =
      Color.alphaBlend(background ?? Colors.transparent, scheme.surface);
  double contrast(Color color) {
    final a = color.computeLuminance();
    final b = fill.computeLuminance();
    return (a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05));
  }

  if (contrast(scheme.primary) >= 3) return scheme.primary;
  if (contrast(scheme.onPrimary) >= 3) return scheme.onPrimary;
  return contrast(Colors.white) > contrast(Colors.black)
      ? Colors.white
      : Colors.black;
}

/// Preserve the native button's label, semantics, callbacks and complete style,
/// but leave TV focus painting to the single outer TVFocusable border.
class _TvStyledButton extends ButtonStyleButton {
  _TvStyledButton(this.source)
      : super(
          key: source.key,
          onPressed: source.onPressed,
          onLongPress: source.onLongPress,
          onHover: source.onHover,
          onFocusChange: source.onFocusChange,
          style: (source.style ?? const ButtonStyle()).copyWith(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          focusNode: null,
          autofocus: false,
          clipBehavior: source.clipBehavior,
          statesController: source.statesController,
          isSemanticButton: source.isSemanticButton,
          tooltip: source.tooltip,
          child: source.child,
        );

  final ButtonStyleButton source;

  ButtonStyle resolvedStyle(BuildContext context, Set<WidgetState> states) {
    final defaults = source.defaultStyleOf(context);
    final theme = source.themeStyleOf(context);
    return ButtonStyle(
      shape: WidgetStatePropertyAll(source.style?.shape?.resolve(states) ??
          theme?.shape?.resolve(states) ??
          defaults.shape?.resolve(states)),
      backgroundColor: WidgetStatePropertyAll(
          source.style?.backgroundColor?.resolve(states) ??
              theme?.backgroundColor?.resolve(states) ??
              defaults.backgroundColor?.resolve(states)),
    );
  }

  @override
  ButtonStyle defaultStyleOf(BuildContext context) =>
      source.defaultStyleOf(context);

  @override
  ButtonStyle? themeStyleOf(BuildContext context) =>
      source.themeStyleOf(context);
}

extension TvButtonFocus on ButtonStyleButton {
  Widget withTvFocus({bool? autofocus}) => system.isTV
      ? TVFocusable(
          autofocus: autofocus ?? this.autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          child: this,
        )
      : this;
}

/// Scale effect variant: focused item scales up slightly (TV "zoom" feel).
class TVFocusableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final double focusScale;

  const TVFocusableScale({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.focusScale = 1.05,
  });

  @override
  State<TVFocusableScale> createState() => _TVFocusableScaleState();
}

class _TVFocusableScaleState extends State<TVFocusableScale> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onPressed?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!system.isTV) {
      return widget.child;
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isFocused ? widget.focusScale : 1.0,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}
