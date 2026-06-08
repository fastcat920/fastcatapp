import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/state/knowledge_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iaw;

const _docsLanguage = 'zh-CN';

/// 知识库文章模型
class KnowledgeArticle {
  final int id;
  final String category;
  final String title;
  final String body;
  final int createdAt;

  KnowledgeArticle({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticle(
      id: _pickInt(json, ['id', 'article_id', 'knowledge_id']),
      category: _pickString(json, ['category', 'group', 'type']).isNotEmpty
          ? _pickString(json, ['category', 'group', 'type'])
          : '其他',
      title: _pickString(json, ['title', 'question']),
      body: _pickString(json, ['body', 'content', 'answer']),
      createdAt: _pickInt(json, ['updated_at', 'created_at']),
    );
  }

  static String _pickString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  static int _pickInt(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  DateTime get createdDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
}

/// 文档中心页面 — 数据由 knowledgeArticlesProvider 提供（keepAlive 缓存）
class DocsPage extends ConsumerStatefulWidget {
  const DocsPage({super.key});

  @override
  ConsumerState<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends ConsumerState<DocsPage>
    with SingleTickerProviderStateMixin {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  late final AnimationController _refreshAnim;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final theme = Theme.of(context);
    const language = _docsLanguage;

    ref.listen<AsyncValue<dynamic>>(
      knowledgeArticlesProvider(language),
      (_, next) {
        if (next.isLoading && !_refreshAnim.isAnimating) {
          _refreshAnim.repeat();
        } else if (!next.isLoading && _refreshAnim.isAnimating) {
          _refreshAnim
            ..stop()
            ..reset();
        }
      },
    );

    final asyncArticles = ref.watch(knowledgeArticlesProvider(language));
    final isDarkScaffold = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkScaffold ? null : const Color(0xFFFAFBFD),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardDocsCenter),
        actions: isDesktop
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RotationTransition(
                    turns: _refreshAnim,
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.invalidate(knowledgeArticlesProvider(language)),
                      tooltip: AppLocalizations.of(context).refresh,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      // Desktop: don't wrap entire body in RefreshIndicator (causes issues
      // with Column+Expanded layout); refresh is done via the header button.
      // Mobile: RefreshIndicator works fine with touch overscroll.
      body: isDesktop
          ? _buildDesktopBody(theme, asyncArticles, language)
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(knowledgeArticlesProvider(language)),
              child: _buildBody(theme, false, asyncArticles, language),
            ),
    );
  }

  /// PC 端布局：SafeArea + 顶栏标题+刷新按钮 + 内容区
  Widget _buildDesktopBody(
    ThemeData theme,
    AsyncValue<dynamic> asyncArticles,
    String language,
  ) {
    return SafeArea(
      child: asyncArticles.when(
        loading: () => const Column(
          children: [
            SizedBox(height: 4),
            Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
        error: (error, _) => Column(
          children: [
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('加载失败', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                      onPressed: () =>
                          ref.invalidate(knowledgeArticlesProvider(language)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (result) {
          final articles = _parseArticles(result);
          if (articles.isEmpty) {
            return const Column(
              children: [
                SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, size: 56),
                        SizedBox(height: 16),
                        Text('暂无文档'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final grouped = _groupArticles(articles);
          return Column(
            children: [
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: grouped.entries.map((entry) {
                    return _buildCategoryTile(theme, entry, language);
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryTile(
    ThemeData theme,
    MapEntry<String, List<KnowledgeArticle>> entry,
    String language,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExpansionTile(
      shape: const Border(),
      initiallyExpanded: true,
      leading: Icon(
        Icons.folder_outlined,
        color: isDark ? null : theme.colorScheme.primary,
      ),
      title: Text(
        entry.key,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: entry.value.asMap().entries.map((articleEntry) {
        final article = articleEntry.value;
        return Column(
          children: [
            if (articleEntry.key > 0) const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isDark
                    ? null
                    : Border.all(color: const Color(0xFFEEF0F4), width: 1),
                boxShadow: isDark
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x0A1565C0),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
                leading: Icon(Icons.article_outlined,
                    size: 20, color: isDark ? null : theme.colorScheme.primary),
                title: Text(article.title),
                subtitle: Text(
                  _formatDate(article.createdDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: isDark ? null : const Color(0xFF9CA3B4)),
                onTap: () => _showArticleDetail(article, language),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Mobile layout body (wrapped in RefreshIndicator)
  Widget _buildBody(
    ThemeData theme,
    bool isDesktop,
    AsyncValue<dynamic> asyncArticles,
    String language,
  ) {
    return asyncArticles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: () =>
                  ref.invalidate(knowledgeArticlesProvider(language)),
            ),
          ],
        ),
      ),
      data: (result) {
        final articles = _parseArticles(result);
        if (articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    size: 56, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('暂无文档',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }
        final grouped = _groupArticles(articles);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              const SizedBox(height: 4),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: grouped.entries.map((entry) {
                  return _buildCategoryTile(theme, entry, language);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<KnowledgeArticle> _parseArticles(dynamic result) {
    if (result is! Map) return [];
    final dataField = result['data'];
    List<dynamic> rawList;
    if (dataField is List) {
      rawList = dataField;
    } else if (dataField is Map) {
      final articles = dataField['articles'];
      final nestedData = dataField['data'];
      rawList = articles is List
          ? articles
          : nestedData is List
              ? nestedData
              : dataField.values
                  .whereType<List>()
                  .expand((list) => list)
                  .toList();
    } else {
      rawList = [];
    }
    return rawList
        .whereType<Map>()
        .map((e) => KnowledgeArticle.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Map<String, List<KnowledgeArticle>> _groupArticles(
      List<KnowledgeArticle> articles) {
    final map = <String, List<KnowledgeArticle>>{};
    for (final a in articles) {
      map.putIfAbsent(a.category, () => []).add(a);
    }
    return map;
  }

  void _showArticleDetail(KnowledgeArticle article, String language) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArticleDetailPage(
          article: article,
          language: language,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// 文章详情页
class _ArticleDetailPage extends ConsumerStatefulWidget {
  final KnowledgeArticle article;
  final String language;

  const _ArticleDetailPage({
    required this.article,
    required this.language,
  });

  @override
  ConsumerState<_ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends ConsumerState<_ArticleDetailPage> {
  String? _resolvedBody;
  WebViewController? _webController;
  bool _useInAppWebView = false;
  String? _inAppWebViewHtml;
  bool _webLoading = true;

  KnowledgeArticleDetailRequest get _detailRequest =>
      KnowledgeArticleDetailRequest(
        id: widget.article.id,
        language: widget.language,
      );

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _contentToHtml(String content, {bool isDark = false}) {
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

    s = s.replaceAll(RegExp(r'^---+$', multiLine: true), '<hr>');

    for (int i = 6; i >= 1; i--) {
      s = s.replaceAllMapped(
        RegExp('^${'#' * i} (.+)\$', multiLine: true),
        (m) => '<h$i>${m.group(1)!}</h$i>',
      );
    }

    s = s
        .replaceAllMapped(RegExp(r'\*\*\*(.*?)\*\*\*'),
            (m) => '<strong><em>${m.group(1)}</em></strong>')
        .replaceAllMapped(
            RegExp(r'\*\*(.*?)\*\*'), (m) => '<strong>${m.group(1)}</strong>')
        .replaceAllMapped(
            RegExp(r'\*(.*?)\*'), (m) => '<em>${m.group(1)}</em>');

    s = s.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    s = s.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (m) => '<img alt="${m.group(1)}" src="${m.group(2)}">',
    );

    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    s = s.replaceAllMapped(
      RegExp(r'^[-*+] (.+)$', multiLine: true),
      (m) => '<li>${m.group(1)!}</li>',
    );
    s = s.replaceAllMapped(
      RegExp(r'(<li>.*?</li>\n?)+'),
      (m) => '<ul>${m.group(0)}</ul>',
    );

    s = s.replaceAllMapped(
      RegExp(r'^\d+\. (.+)$', multiLine: true),
      (m) => '<li>${m.group(1)!}</li>',
    );

    s = s.replaceAllMapped(
      RegExp(r'(^> .+(\n> .+)*)', multiLine: true),
      (m) {
        final inner =
            m.group(0)!.replaceAll(RegExp(r'^> ', multiLine: true), '');
        return '<blockquote>${inner.replaceAll('\n', '<br>')}</blockquote>';
      },
    );

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

    s = s.replaceAllMapped(RegExp(r'\n\n+'), (_) => '\n</p><p>\n');
    s = s.replaceAll(RegExp(r'(?<!</p>)\n(?!<)'), '<br>\n');

    for (final entry in htmlBlocks.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }

    final textColor = isDark ? '#e0e0e0' : '#1a1a1a';
    final bgColor = isDark ? '#1e1e1e' : '#ffffff';
    final codeBg = isDark ? '#2d2d2d' : '#f4f4f4';
    final hrColor = isDark ? '#444' : '#e0e0e0';

    return '''<!DOCTYPE html><html><head>
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
</style></head><body>$s</body></html>''';
  }

  @override
  void initState() {
    super.initState();
    final body = widget.article.body;
    if (body.isNotEmpty) {
      _resolvedBody = body;
      _initWebView(body);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  static String _parseDetailBody(dynamic result) {
    String findBody(dynamic value) {
      if (value is Map) {
        final normalized =
            value.map((key, value) => MapEntry(key.toString(), value));
        final direct = KnowledgeArticle._pickString(
          normalized,
          ['body', 'content', 'answer', 'description'],
        );
        if (direct.isNotEmpty) return direct;

        for (final key in const [
          'data',
          'article',
          'knowledge',
          'detail',
          'item',
          'record',
          'result',
        ]) {
          final nested = normalized[key];
          final nestedBody = findBody(nested);
          if (nestedBody.isNotEmpty) return nestedBody;
        }

        for (final nested in normalized.values) {
          final nestedBody = findBody(nested);
          if (nestedBody.isNotEmpty) return nestedBody;
        }
      }
      if (value is List) {
        for (final item in value) {
          final nestedBody = findBody(item);
          if (nestedBody.isNotEmpty) return nestedBody;
        }
      }
      return '';
    }

    return findBody(result);
  }

  void _resetDetailContent() {
    _resolvedBody = null;
    _webController = null;
    _useInAppWebView = false;
    _inAppWebViewHtml = null;
    _webLoading = true;
  }

  void _retryDetail() {
    setState(_resetDetailContent);
    ref.invalidate(knowledgeArticleDetailProvider(_detailRequest));
    unawaited(
      ref
          .refresh(knowledgeArticleDetailProvider(_detailRequest).future)
          .catchError((_) => null),
    );
  }

  void _initWebView(String content) {
    final isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final fullHtml = _contentToHtml(content, isDark: isDark);

    if (Platform.isWindows || Platform.isLinux) {
      _inAppWebViewHtml = fullHtml;
      _useInAppWebView = true;
      if (mounted) setState(() => _webLoading = false);
      return;
    }

    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return;
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _webLoading = false);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(fullHtml);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = widget.article;

    Widget contentArea;
    if (_resolvedBody == null) {
      final asyncDetail =
          ref.watch(knowledgeArticleDetailProvider(_detailRequest));
      contentArea = asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('加载失败', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: _retryDetail,
              ),
            ],
          ),
        ),
        data: (result) {
          if (_resolvedBody == null) {
            final fetchedBody = _parseDetailBody(result);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _resolvedBody = fetchedBody;
                if (fetchedBody.isNotEmpty) {
                  _initWebView(fetchedBody);
                } else {
                  _webLoading = false;
                }
              });
            });
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContentArea(theme);
        },
      );
    } else {
      contentArea = _buildContentArea(theme);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.primaryContainer
                            : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.category,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time,
                        size: 13, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(article.createdDate),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: contentArea),
        ],
      ),
    );
  }

  Widget _buildContentArea(ThemeData theme) {
    final body = _resolvedBody ?? '';
    if (body.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            '暂无内容',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_useInAppWebView && _inAppWebViewHtml != null) {
      return iaw.InAppWebView(
        initialData: iaw.InAppWebViewInitialData(
          data: _inAppWebViewHtml!,
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: iaw.InAppWebViewSettings(
          javaScriptEnabled: true,
        ),
      );
    }

    if ((Platform.isAndroid || Platform.isIOS || Platform.isMacOS) &&
        _webController != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _webController!),
          if (_webLoading) const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_webLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(body),
    );
  }
}
