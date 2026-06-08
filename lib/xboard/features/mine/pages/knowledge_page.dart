import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inapp;

class KnowledgePage extends ConsumerWidget {
  const KnowledgePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).xboardDocsCenter)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchArticles(
            ref, Localizations.localeOf(context).toLanguageTag()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 56, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    Text('加载失败',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('${snapshot.error}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }
          final articles = snapshot.data ?? [];
          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('暂无文档',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          // 按 category 分组
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final article in articles) {
            final category = article['category'] as String? ?? '其他';
            grouped.putIfAbsent(category, () => []).add(article);
          }
          final categories = grouped.keys.toList();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: categories.length,
            itemBuilder: (context, ci) {
              final category = categories[ci];
              final items = grouped[category]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ci > 0) const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: 1,
                                indent: 52,
                                endIndent: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.15)),
                          ListTile(
                            leading: Icon(
                              Icons.article_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              items[i]['title'] as String? ?? '未知文档',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _ArticleDetailPage(
                                  title: items[i]['title'] as String? ?? '文档',
                                  content: items[i]['body'] as String? ?? '',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchArticles(
      WidgetRef ref, String language) async {
    final sdk = await ref.read(xboardSdkProvider.future);
    final resp = await sdk.httpService
        .getRequest('/user/knowledge/fetch?language=$language');
    final data = resp['data'];
    // API 返回 Map<category, List<article>>（Laravel groupBy 结果）
    if (data is Map) {
      return (data as Map<String, dynamic>)
          .values
          .whereType<List>()
          .expand((list) => list.whereType<Map<String, dynamic>>())
          .toList();
    }
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}

// ─── 文章详情页 ─────────────────────────────────────────────────────────────

class _ArticleDetailPage extends StatefulWidget {
  final String title;
  final String content;
  const _ArticleDetailPage({required this.title, required this.content});

  @override
  State<_ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<_ArticleDetailPage> {
  // webview_flutter for Android/iOS/macOS
  WebViewController? _controller;
  bool _isLoading = true;

  /// 是否使用 webview_flutter（Android/iOS/macOS）
  static bool get _useWebViewFlutter =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// 是否使用 flutter_inappwebview（Windows/Linux 桌面端）
  static bool get _useInAppWebView => Platform.isWindows || Platform.isLinux;

  /// Dart 侧 Markdown/HTML → 完整 HTML 页面（与 docs_page 同逻辑，不依赖 JS）
  static String _contentToHtml(String content, {bool isDark = false}) {
    // Phase 1: 保护原始 HTML 块
    final htmlBlocks = <String, String>{};
    int blockIndex = 0;
    String s = content;

    s = s.replaceAllMapped(
      RegExp(
          r'<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>[\s\S]*?</\1>|<([a-zA-Z][a-zA-Z0-9]*)\b[^>]*/?>',
          multiLine: true),
      (m) {
        final key = '\x00HTML_BLOCK_${blockIndex++}\x00';
        htmlBlocks[key] = m.group(0)!;
        return key;
      },
    );

    // Phase 2: Markdown 语法转换

    // ::: admonition 块
    s = s.replaceAllMapped(
      RegExp(r':::(\w+)\s*(.*?)\n([\s\S]*?):::', multiLine: true),
      (m) {
        final type = m.group(1)!.toLowerCase();
        final title = m.group(2)!.trim();
        final body = m.group(3)!.trim();
        const colors = <String, List<String>>{
          'tip': ['#e8f5e9', '#2e7d32'],
          'warning': ['#fff8e1', '#f57f17'],
          'danger': ['#fce4ec', '#c62828'],
          'info': ['#e3f2fd', '#1565c0'],
        };
        final pair = colors[type] ?? ['#f5f5f5', '#333'];
        final label = title.isNotEmpty ? title : type.toUpperCase();
        return '<div style="background:${pair[0]};border-left:4px solid ${pair[1]};'
            'border-radius:6px;padding:12px 16px;margin:12px 0">'
            '<strong style="color:${pair[1]}">$label</strong>'
            '<br>${body.replaceAll('\n', '<br>')}</div>';
      },
    );

    // 代码块
    s = s.replaceAllMapped(
      RegExp(r'```[\w]*\n?([\s\S]*?)```', multiLine: true),
      (m) {
        final code = m
            .group(1)!
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .trim();
        return '<pre><code>$code</code></pre>';
      },
    );

    // 分割线
    s = s.replaceAll(RegExp(r'^---+$', multiLine: true), '<hr>');

    // 标题
    for (int i = 6; i >= 1; i--) {
      s = s.replaceAllMapped(
        RegExp('^${'#' * i} (.+)\$', multiLine: true),
        (m) => '<h$i>${m.group(1)!}</h$i>',
      );
    }

    // 粗体/斜体
    s = s
        .replaceAllMapped(RegExp(r'\*\*\*(.*?)\*\*\*'),
            (m) => '<strong><em>${m.group(1)}</em></strong>')
        .replaceAllMapped(
            RegExp(r'\*\*(.*?)\*\*'), (m) => '<strong>${m.group(1)}</strong>')
        .replaceAllMapped(
            RegExp(r'\*(.*?)\*'), (m) => '<em>${m.group(1)}</em>');

    // 行内代码
    s = s.replaceAllMapped(
        RegExp(r'`([^`]+)`'), (m) => '<code>${m.group(1)}</code>');

    // 图片
    s = s.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (m) => '<img alt="${m.group(1)}" src="${m.group(2)}">',
    );

    // 链接
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // 无序列表
    s = s.replaceAllMapped(RegExp(r'^[-*+] (.+)$', multiLine: true),
        (m) => '<li>${m.group(1)!}</li>');
    s = s.replaceAllMapped(
        RegExp(r'(<li>.*?</li>\n?)+'), (m) => '<ul>${m.group(0)}</ul>');

    // 有序列表
    s = s.replaceAllMapped(RegExp(r'^\d+\. (.+)$', multiLine: true),
        (m) => '<li>${m.group(1)!}</li>');

    // 引用块（> quote，支持多行连续）
    s = s.replaceAllMapped(
      RegExp(r'(^> .+(\n> .+)*)', multiLine: true),
      (m) {
        final inner =
            m.group(0)!.replaceAll(RegExp(r'^> ', multiLine: true), '');
        return '<blockquote>${inner.replaceAll('\n', '<br>')}</blockquote>';
      },
    );

    // 表格（| col | col | 语法）
    s = s.replaceAllMapped(
      RegExp(r'(^\|.+\|[ \t]*\n)(^\|[-| :]+\|[ \t]*\n)((?:^\|.+\|[ \t]*\n?)+)',
          multiLine: true),
      (m) {
        final headerLine = m.group(1)!.trim();
        final bodyLines = m.group(3)!.trim().split('\n');

        String parseRow(String line, String tag) {
          final cells = line
              .split('|')
              .where((c) => c.trim().isNotEmpty)
              .map((c) => c.trim());
          return '<tr>${cells.map((c) => '<$tag>$c</$tag>').join()}</tr>';
        }

        final thead = '<thead>${parseRow(headerLine, 'th')}</thead>';
        final tbody =
            '<tbody>${bodyLines.map((l) => parseRow(l.trim(), 'td')).join()}</tbody>';
        return '<table>$thead$tbody</table>';
      },
    );

    // 段落（双换行）和换行
    s = s.replaceAllMapped(RegExp(r'\n\n+'), (_) => '\n</p><p>\n');
    s = s.replaceAll(RegExp(r'(?<!</p>)\n(?!<)'), '<br>\n');

    // Phase 3: 还原 HTML 块
    for (final entry in htmlBlocks.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }

    // Phase 4: 封装完整 HTML
    final textColor = isDark ? '#e0e0e0' : '#1a1a1a';
    final bgColor = isDark ? '#1e1e1e' : '#ffffff';
    final codeBg = isDark ? '#2d2d2d' : '#f4f4f4';
    final hrColor = isDark ? '#444' : '#e0e0e0';

    return '''<!DOCTYPE html><html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:16px;line-height:1.7;word-wrap:break-word;color:$textColor;background:$bgColor;max-width:100%}
img{max-width:100%;height:auto;border-radius:8px;margin:8px 0}
pre{background:$codeBg;padding:12px;border-radius:6px;overflow-x:auto}
code{background:$codeBg;padding:2px 4px;border-radius:3px;font-size:.9em;font-family:monospace}
a{color:#1976D2}blockquote{border-left:4px solid #1976D2;margin:0;padding-left:16px;color:#555}
h1,h2,h3,h4{margin-top:20px;margin-bottom:8px}
hr{border:none;border-top:1px solid $hrColor;margin:16px 0}
ul,ol{padding-left:24px}table{border-collapse:collapse;width:100%}
th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background:$codeBg}
p{margin:8px 0}
</style></head><body><p>$s</p></body></html>''';
  }

  /// 生成文章 HTML
  String _buildArticleHtml() {
    final isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    return _contentToHtml(widget.content, isDark: isDark);
  }

  @override
  void initState() {
    super.initState();
    if (_useWebViewFlutter) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadHtmlString(_buildArticleHtml());
    } else if (_useInAppWebView) {
      // flutter_inappwebview handles loading in the widget itself
      _isLoading = false;
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_useWebViewFlutter && _controller != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_useInAppWebView) {
      return inapp.InAppWebView(
        initialSettings: inapp.InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
        ),
        onWebViewCreated: (controller) {
          controller.loadData(
            data: _buildArticleHtml(),
            mimeType: 'text/html',
            encoding: 'utf-8',
          );
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final uri = action.request.url;
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            launchUrl(uri.uriValue, mode: LaunchMode.externalApplication);
            return inapp.NavigationActionPolicy.CANCEL;
          }
          return inapp.NavigationActionPolicy.ALLOW;
        },
      );
    }
    // Fallback: plain text
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Text(widget.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7)),
    );
  }
}
