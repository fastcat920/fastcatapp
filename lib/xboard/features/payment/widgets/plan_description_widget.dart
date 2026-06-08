import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class PlanDescriptionWidget extends StatelessWidget {
  final String content;
  const PlanDescriptionWidget({
    super.key,
    required this.content,
  });

  /// 检测内容是否包含 HTML 标签
  static final _htmlTagPattern = RegExp(r'<[a-zA-Z][^>]*>');
  bool get _isHtml => _htmlTagPattern.hasMatch(content);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: 14,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _isHtml
          ? HtmlWidget(content, textStyle: textStyle)
          : MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: textStyle,
                textAlign: WrapAlignment.center,
              ),
            ),
    );
  }
}