import 'package:fl_clash/xboard/features/shared/styles/html_styles.dart';
import 'package:fl_clash/xboard/features/shared/utils/notice_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects inline HTML and decodes text for the home card', () {
    expect(isNoticeHtml('<u>Underlined</u>'), isTrue);
    expect(isNoticeHtml('**Markdown**'), isFalse);
    expect(
      noticePreviewText('<p>&nbsp;&nbsp;<b>First</b></p><div>Second &amp; third</div>'),
      'First Second & third',
    );
  });

  test('preserves legacy newlines without duplicating HTML block breaks', () {
    expect(
      formatNoticeHtml('<strong>First</strong>\r\n&nbsp;&nbsp;Second'),
      '<strong>First</strong><br>&nbsp;&nbsp;Second',
    );
    expect(formatNoticeHtml('<p>First</p>\n<p>Second</p>'),
        '<p>First</p>\n<p>Second</p>');
    expect(formatNoticeHtml('<pre>First\nSecond</pre>'),
        '<pre>First\nSecond</pre>');
  });

  testWidgets('renders announcement colors and preserves leading indentation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => NoticeHtmlStyles.buildNoticeHtml(
            context: context,
            htmlContent: formatNoticeHtml(
              '<h3 style="color: rgb(27, 95, 184);">Heading</h3>'
              '<p>&nbsp;&nbsp;<strong style="color: rgb(190, 42, 52);">Important</strong>'
              ' Regular text\n&nbsp;&nbsp;<u>Example</u></p>'
              '<ol><li>First item</li><li>Second item</li></ol>',
            ),
            onTapUrl: null,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final styles = <String, TextStyle>{};
    final fragments = <String>[];
    void visit(InlineSpan span, TextStyle inherited) {
      final style = inherited.merge(span.style);
      if (span is TextSpan) {
        final text = span.text;
        if (text != null) {
          styles[text] = style;
          fragments.add(text);
        }
        for (final child in span.children ?? <InlineSpan>[]) {
          visit(child, style);
        }
      }
    }

    for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
      visit(widget.text, const TextStyle());
    }
    expect(styles['Heading']?.color, const Color(0xFF1B5FB8));
    expect(styles['Important']?.color, const Color(0xFFBE2A34));
    expect(fragments.join(), contains('\u00a0\u00a0Important'));
    expect(styles['Important']?.fontWeight, FontWeight.w700);
    expect(styles['Example']?.decoration, TextDecoration.underline);
    expect(fragments.join(), contains('Regular text\n\u00a0\u00a0Example'));
    expect(fragments.join(), contains('First item'));
    expect(fragments.join(), contains('Second item'));
  });
}
