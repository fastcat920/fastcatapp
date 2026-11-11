import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';

/// Shared rule presentation; the underlying core rule remains unchanged.
class RoutingRuleCard extends StatelessWidget {
  const RoutingRuleCard(
      {super.key,
      required this.value,
      required this.chinese,
      this.onEdit,
      this.onDelete,
      this.onUp,
      this.onDown});
  final String value;
  final bool chinese;
  final VoidCallback? onEdit, onDelete, onUp, onDown;

  @override
  Widget build(BuildContext context) {
    Widget action(
        String id, String label, IconData icon, VoidCallback? callback) {
      return TVFocusable(
        key: ValueKey('rule-action-$id'),
        borderRadius: BorderRadius.circular(12),
        focusableWhenDisabled: true,
        onPressed: callback,
        child: SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: label,
              onPressed: callback,
              icon: Icon(icon),
            )),
      );
    }

    return Card(
      shape: XbUiCardStyle.shape(context),
      color: XbUiCardStyle.background(context),
      elevation: XbUiCardStyle.elevation(context),
      shadowColor: XbUiCardStyle.shadowColor(context),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final parts = value.split(',');
          final destination = parts.length >= 2 ? parts[1] : value;
          final direct = parts.length >= 3 && parts[2] == 'DIRECT';
          final label =
              direct ? (chinese ? '直连' : 'Direct') : (chinese ? '代理' : 'Proxy');
          final theme = Theme.of(context);
          final style =
              theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
          double textWidth(String text) {
            final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context))
              ..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final tagWidth = textWidth(label) + 16;
          final inline = textWidth(destination) + tagWidth + 4 * 48 + 24 <=
              constraints.maxWidth;
          final tag = Container(
            key: const Key('routing-mode-label'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8)),
            child: Text(label,
                style:
                    style.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          );
          final actions = Wrap(alignment: WrapAlignment.end, children: [
            action(
                'edit', chinese ? '编辑' : 'Edit', Icons.edit_outlined, onEdit),
            action('delete', chinese ? '删除' : 'Delete', Icons.delete_outline,
                onDelete),
            action('up', chinese ? '上移' : 'Move up', Icons.arrow_upward, onUp),
            action('down', chinese ? '下移' : 'Move down', Icons.arrow_downward,
                onDown),
          ]);
          final header = Row(children: [
            Expanded(
                child: Text(destination,
                    style: style,
                    maxLines: inline ? 1 : 2,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            tag,
          ]);
          if (inline) {
            return Row(children: [
              Expanded(child: header),
              const SizedBox(width: 12),
              actions
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ]);
        }),
      ),
    );
  }
}
