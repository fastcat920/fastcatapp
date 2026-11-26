import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

final _noticeHtmlTag = RegExp(
  r'<(?:p|div|span|h[1-6]|ul|ol|li|br|hr|strong|b|em|i|u|s|a|img|font|table|tr|td|th|blockquote|pre|code)(?=[\s/>])',
  caseSensitive: false,
);
final _previewWhitespace = RegExp(r'[\s\u00a0]+');

bool isNoticeHtml(String content) => _noticeHtmlTag.hasMatch(content);

String noticePreviewText(String content) {
  if (!isNoticeHtml(content)) {
    return content.replaceAll(_previewWhitespace, ' ').trim();
  }
  final fragment = html.parseFragment(content);
  for (final node in fragment.querySelectorAll('script,style,template')) {
    node.remove();
  }
  for (final node in fragment.querySelectorAll(
      'br,hr,p,div,h1,h2,h3,h4,h5,h6,li,td,th,blockquote,pre')) {
    node.append(dom.Text(' '));
  }
  return fragment.text!.replaceAll(_previewWhitespace, ' ').trim();
}

const _noticeBlocks = {
  'blockquote',
  'br',
  'div',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'li',
  'ol',
  'p',
  'pre',
  'table',
  'tr',
  'ul',
};
const _verbatimNoticeTags = {'pre', 'code', 'script', 'style', 'textarea'};

/// Older notices store author-entered newlines alongside inline markup.
/// Preserve these without adding breaks between existing HTML paragraphs.
String formatNoticeHtml(String content) {
  final source = content.trim();
  if (!source.contains('\n') && !source.contains('\r')) return source;
  final fragment = html.parseFragment(source);

  void preserveBreaks(dom.Node parent) {
    final children = parent.nodes.toList(growable: false);
    for (var index = 0; index < children.length; index++) {
      final node = children[index];
      if (node is dom.Element) {
        if (!_verbatimNoticeTags.contains(node.localName)) preserveBreaks(node);
        continue;
      }
      if (node is! dom.Text || !node.data.contains('\n')) continue;

      final before = index == 0 ? null : children[index - 1];
      final after = index + 1 == children.length ? null : children[index + 1];
      final isStructuralWhitespace =
          !RegExp(r'[^ \t\r\n]').hasMatch(node.data) &&
              (before == null ||
                  after == null ||
                  (before is dom.Element &&
                      _noticeBlocks.contains(before.localName)) ||
                  (after is dom.Element &&
                      _noticeBlocks.contains(after.localName)));
      if (isStructuralWhitespace) continue;

      final lines = node.data.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) parent.insertBefore(dom.Element.tag('br'), node);
        if (lines[i].isNotEmpty) parent.insertBefore(dom.Text(lines[i]), node);
      }
      node.remove();
    }
  }

  preserveBreaks(fragment);
  return fragment.outerHtml;
}
