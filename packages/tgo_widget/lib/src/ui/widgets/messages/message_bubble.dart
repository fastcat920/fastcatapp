import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/tgo_theme.dart';

/// Message bubble container
class MessageBubble extends StatelessWidget {
  final Widget child;
  final bool isUser;
  final bool isError;

  const MessageBubble({
    super.key,
    required this.child,
    required this.isUser,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = TgoThemeProvider.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: math.min(380, constraints.maxWidth * 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isError
              ? theme.errorColor.withOpacity(0.1)
              : isUser
                  ? theme.userBubbleBg
                  : theme.agentBubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 16 : 6),
            topRight: Radius.circular(isUser ? 6 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            color: isError
                ? theme.errorColor
                : isUser
                    ? theme.userBubbleText
                    : theme.agentBubbleText,
            fontSize: 14,
            height: 1.6,
          ),
          child: child,
        ),
      );
    });
  }
}

/// Blinking cursor for streaming messages
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TgoThemeProvider.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 8,
            height: 16,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

/// AI loading dots animation
class AILoadingDots extends StatefulWidget {
  const AILoadingDots({super.key});

  @override
  State<AILoadingDots> createState() => _AILoadingDotsState();
}

class _AILoadingDotsState extends State<AILoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with staggered delay
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TgoThemeProvider.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            final value = _animations[index].value;
            // Scale between 0.6 and 1.0, Opacity between 0.5 and 1.0
            final scale = 0.6 + (value * 0.4);
            final opacity = 0.5 + (value * 0.5);

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: theme.textMuted.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
