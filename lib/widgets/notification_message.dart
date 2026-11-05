import 'package:flutter/material.dart';

/// Status prefixes remain readable in logs, but use bundled Material glyphs
/// on screen instead of depending on the desktop's installed emoji fonts.
class NotificationMessage extends StatelessWidget {
  const NotificationMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final (String prefix, IconData icon, Color color)? status;
    if (message.startsWith('❌ ')) {
      status = ('❌ ', Icons.error_outline, Theme.of(context).colorScheme.error);
    } else if (message.startsWith('✅ ')) {
      status = ('✅ ', Icons.check_circle_outline, Colors.green);
    } else if (message.startsWith('⚠️ ')) {
      status = ('⚠️ ', Icons.warning_amber_rounded, Colors.orange);
    } else {
      status = null;
    }
    if (status == null) return Text(message);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(status.$2, size: 22, color: status.$3)),
        const SizedBox(width: 8),
        Expanded(child: Text(message.substring(status.$1.length))),
      ],
    );
  }
}
