import 'package:flutter/material.dart';

/// Owns transient chat UI inside the SDK's clipped viewport.
///
/// Unlike Navigator dialogs/routes, entries here cannot paint over the host
/// application's navigation or escape the customer-service window.
class ChatOverlayHost extends StatefulWidget {
  final Widget child;

  const ChatOverlayHost({super.key, required this.child});

  static ChatOverlayHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ChatOverlayHostState>();

  @override
  State<ChatOverlayHost> createState() => ChatOverlayHostState();
}

class ChatOverlayHostState extends State<ChatOverlayHost> {
  Widget? _overlay;

  void show(WidgetBuilder builder) {
    if (!mounted) return;
    setState(() => _overlay = Builder(builder: builder));
  }

  void dismiss() {
    if (_overlay == null || !mounted) return;
    setState(() => _overlay = null);
  }

  @override
  Widget build(BuildContext context) => ClipRect(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            widget.child,
            if (_overlay != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: _overlay!,
                ),
              ),
          ],
        ),
      );
}
