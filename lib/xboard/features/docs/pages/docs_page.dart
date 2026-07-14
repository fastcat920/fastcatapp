import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/webview2_check.dart';
import 'package:fl_clash/xboard/adapter/state/knowledge_state.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/shared/widgets/xb_error_state.dart';
import 'package:fl_clash/xboard/features/shared/styles/html_styles.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iaw;
import 'package:webview_win_floating/webview_plugin.dart';

String _renderMarkdownBody(String content) {
  // 与 V2Board markdown-it 的 html: true 行为保持一致：Markdown 会转换，
  // 文档自带的 HTML 与 style 标签继续保留。
  return md.markdownToHtml(
    content,
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
}

/// Build the language tag expected by the V2Board knowledge API.
///
/// The backend stores English docs as `en-US` while Flutter's English locale is
/// just `en`, so this must not use [Locale.toLanguageTag] directly.
String _localeToDocsLanguage(Locale locale) {
  final lang = locale.languageCode;
  final country = locale.countryCode;
  if (lang == 'en') return 'en-US';
  if (lang == 'zh') return 'zh-CN';
  if (country != null && country.isNotEmpty) return '$lang-$country';
  return lang;
}

/// 文档中心页面 — 数据由 knowledgeArticlesProvider 提供（keepAlive 缓存）
class DocsPage extends ConsumerStatefulWidget {
  const DocsPage({super.key});

  @override
  ConsumerState<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends ConsumerState<DocsPage>
    with SingleTickerProviderStateMixin {
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
    final language = _localeToDocsLanguage(Localizations.localeOf(context));

    ref.listen<AsyncValue<List<KnowledgeArticle>>>(
        knowledgeArticlesProvider(language), (
      _,
      next,
    ) {
      if (next.isLoading && !_refreshAnim.isAnimating) {
        _refreshAnim.repeat();
      } else if (!next.isLoading && _refreshAnim.isAnimating) {
        _refreshAnim
          ..stop()
          ..reset();
      }
    });

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
    AsyncValue<List<KnowledgeArticle>> asyncArticles,
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
              child: XbErrorState(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(knowledgeArticlesProvider(language)),
              ),
            ),
          ],
        ),
        data: (result) {
          final articles = result;
          if (articles.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.article_outlined, size: 56),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context).xboardNoDocuments),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 2,
                ),
                leading: Icon(
                  Icons.article_outlined,
                  size: 20,
                  color: isDark ? null : theme.colorScheme.primary,
                ),
                title: Text(article.title),
                subtitle: Text(
                  _formatDate(article.createdDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isDark ? null : const Color(0xFF9CA3B4),
                ),
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
    AsyncValue<List<KnowledgeArticle>> asyncArticles,
    String language,
  ) {
    return asyncArticles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => XbErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(knowledgeArticlesProvider(language)),
      ),
      data: (result) {
        final articles = result;
        if (articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 56,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).xboardNoDocuments,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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

  Map<String, List<KnowledgeArticle>> _groupArticles(
    List<KnowledgeArticle> articles,
  ) {
    final map = <String, List<KnowledgeArticle>>{};
    for (final a in articles) {
      map.putIfAbsent(a.category, () => []).add(a);
    }
    return map;
  }

  void _showArticleDetail(KnowledgeArticle article, String language) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _ArticleDetailPage(article: article, language: language),
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

  const _ArticleDetailPage({required this.article, required this.language});

  @override
  ConsumerState<_ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends ConsumerState<_ArticleDetailPage> {
  String? _resolvedBody;
  String? _renderedBodyHtml;
  WebViewController? _webController;
  bool _useHtmlWidget = false;
  String? _htmlWidgetContent;
  bool _useInAppWebView = false;
  String? _inAppWebViewHtml;
  iaw.InAppWebViewController? _inAppController;
  bool _lastInAppWebViewIsDark = false;
  bool _lastWebViewIsDark = false;
  bool _isPreparingDocument = false;
  String? _preparingBody;
  bool _webViewLoading = true;
  bool _inAppWebViewLoading = true;
  bool _standardDocumentReady = false;
  bool _standardWebViewAttached = false;
  Timer? _webViewLoadingFallback;
  bool _isClosing = false;
  bool _allowPop = false;
  int _documentGeneration = 0;

  KnowledgeArticleDetailRequest get _detailRequest =>
      KnowledgeArticleDetailRequest(
        id: widget.article.id,
        language: widget.language,
      );

  String get _documentBaseUrl => XBoardConfig.panelUrl ?? gatewayBaseUrl;

  String get _documentBaseHref {
    final rawUrl = _documentBaseUrl.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      return rawUrl.endsWith('/') ? rawUrl : '$rawUrl/';
    }
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path, query: null, fragment: null).toString();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _buildDocumentHtml(
    String renderedContent, {
    bool isDark = false,
    String? baseUrl,
    Color? backgroundColor,
  }) {
    final textColor = isDark ? '#e0e0e0' : '#1a1a1a';
    final fallbackBackground = isDark ? '#1e1e1e' : '#ffffff';
    // `Color.toARGB32()` was added after the Flutter 3.27 toolchain used by
    // release CI. Keep the older value getter until the build image upgrades.
    // ignore: deprecated_member_use
    final backgroundArgb = backgroundColor?.value;
    final bgColor = backgroundArgb == null
        ? fallbackBackground
        : '#${(backgroundArgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final colorScheme = isDark ? 'dark' : 'light';
    final codeBg = isDark ? '#2d2d2d' : '#f4f4f4';
    final hrColor = isDark ? '#444' : '#e0e0e0';
    final baseTag = baseUrl == null || baseUrl.isEmpty
        ? ''
        : '<base href="${const HtmlEscape(HtmlEscapeMode.attribute).convert(baseUrl)}">';
    return '''<!DOCTYPE html><html data-fastcat-document="true"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="color-scheme" content="$colorScheme">
$baseTag
<style>
html,body{margin:0;max-width:100%;background:$bgColor;color-scheme:$colorScheme}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:16px;line-height:1.7;word-wrap:break-word;color:$textColor;background:$bgColor;box-sizing:border-box}
img{max-width:100%;height:auto}
pre{background:$codeBg;padding:12px;border-radius:6px;overflow-x:auto}
code{background:$codeBg;padding:2px 4px;border-radius:3px;font-size:.9em;font-family:monospace}
a{color:#1976D2}blockquote{border-left:4px solid #1976D2;margin:0;padding-left:16px;color:#555}
h1,h2,h3,h4{margin-top:20px;margin-bottom:8px}
hr{border:none;border-top:1px solid $hrColor;margin:16px 0}
ul,ol{padding-left:24px}table{border-collapse:collapse;width:100%}
th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background:$codeBg}
p{margin:8px 0}
</style>
<script>
(function(){
  function reportRendered(){
    if(window.__fastcatDocRenderReported)return;
    window.__fastcatDocRenderReported=true;
    requestAnimationFrame(function(){requestAnimationFrame(function(){
      try{
        if(window.flutter_inappwebview){
          window.flutter_inappwebview.callHandler('documentRendered');
        }else if(window.FastCatDocument){
          window.FastCatDocument.postMessage('rendered');
        }
      }catch(_){ }
    });});
  }
  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',reportRendered,{once:true});
  }else{
    reportRendered();
  }
})();
</script></head><body>$renderedContent</body></html>''';
  }

  /// Linux WebView 失败时，将已经转换好的正文交给 HtmlWidget，避免再次
  /// 执行 Markdown 转换。
  static String _sanitizeBodyHtml(String renderedBodyHtml) {
    return renderedBodyHtml
        .replaceAll(
          RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .trim();
  }

  @override
  void initState() {
    super.initState();
    if ((Platform.isWindows && WebView2Check.isInstalled()) ||
        Platform.isMacOS) {
      _useInAppWebView = true;
    }
    final initialBody = _stripLeadingTitle(widget.article.body).trim();
    _resolvedBody = initialBody.isEmpty ? null : initialBody;
    // 与 Apex 一致：列表接口已有正文时直接准备文档；只有正文为空时，
    // build 才请求单篇详情。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && initialBody.isNotEmpty) {
        unawaited(_prepareDocument(initialBody));
      }
    });
  }

  /// Strip leading Markdown H1 title from body if it matches the article title.
  /// This avoids duplicating the title (already shown in AppBar).
  String _stripLeadingTitle(String body) {
    final title = widget.article.title.trim();
    if (title.isEmpty) return body;
    // Match: # Title followed by newline
    final h1Pattern = RegExp(r'^#\s+' + RegExp.escape(title) + r'\s*\n');
    final stripped = body.replaceFirst(h1Pattern, '');
    return stripped;
  }

  Future<void> _closeDetailPage() async {
    if (_isClosing) return;
    _isClosing = true;

    if (Platform.isLinux) {
      final platformController = _webController?.platform;
      if (platformController is WindowsPlatformWebViewController) {
        try {
          await platformController.controller.setVisibility(false);
        } catch (_) {
          // The WebView may already be disposed after a load failure.
        }
      }
    }

    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _webViewLoadingFallback?.cancel();
    final platformController = _webController?.platform;
    if (platformController is WindowsPlatformWebViewController) {
      unawaited(platformController.controller.dispose());
    }
    _webController = null;
    super.dispose();
  }

  static String _parseDetailBody(dynamic result) {
    String findBody(dynamic value) {
      if (value is Map) {
        final normalized = value.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final direct = KnowledgeArticle.pickString(normalized, [
          'body',
          'content',
          'answer',
          'description',
        ]);
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

  void _retryDetail() {
    _documentGeneration++;
    final platformController = _webController?.platform;
    if (platformController is WindowsPlatformWebViewController) {
      unawaited(platformController.controller.dispose());
    }
    setState(() {
      _resolvedBody = null;
      _renderedBodyHtml = null;
      _webController = null;
      _useHtmlWidget = false;
      _htmlWidgetContent = null;
      _useInAppWebView = false;
      _inAppWebViewHtml = null;
      _inAppController = null;
      _isPreparingDocument = false;
      _preparingBody = null;
      _webViewLoading = true;
      _inAppWebViewLoading = true;
      _standardDocumentReady = false;
      _standardWebViewAttached = false;
      _lastInAppWebViewIsDark = false;
      _lastWebViewIsDark = false;
    });
    invalidateKnowledgeArticleDetailCache(_detailRequest);
    unawaited(
      ref
          .refresh(knowledgeArticleDetailProvider(_detailRequest).future)
          .catchError((_) => null),
    );
  }

  Future<void> _prepareDocument(String content) async {
    if (!mounted || content.isEmpty) return;
    if (_resolvedBody == content && _renderedBodyHtml != null) return;
    if (_preparingBody == content) return;

    final generation = ++_documentGeneration;
    _preparingBody = content;
    if (!_isPreparingDocument) {
      setState(() => _isPreparingDocument = true);
    }

    // Markdown 转换可能在长文档上占用明显的 UI 时间，放入后台 isolate。
    // 同一份结果同时供 WebView 与 Linux HtmlWidget 回退使用。
    final renderedBodyHtml = await compute(_renderMarkdownBody, content);
    if (!mounted || generation != _documentGeneration) return;

    _renderedBodyHtml = renderedBodyHtml;
    setState(() {
      _resolvedBody = content;
      _htmlWidgetContent = _sanitizeBodyHtml(renderedBodyHtml);
      _isPreparingDocument = false;
      _preparingBody = null;
    });
    await _initWebView(content, renderedBodyHtml);
  }

  Future<void> _initWebView(
    String content,
    String renderedBodyHtml,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.scaffoldBackgroundColor;

    if (Platform.isWindows && !WebView2Check.isInstalled()) {
      if (mounted) {
        setState(() {
          _resolvedBody = content;
          _useInAppWebView = false;
          _useHtmlWidget = true;
          _isPreparingDocument = false;
        });
      }
      return;
    }

    if (Platform.isWindows || Platform.isMacOS) {
      _inAppWebViewLoading = true;
      _inAppWebViewHtml = _buildDocumentHtml(
        renderedBodyHtml,
        isDark: isDark,
        baseUrl: _documentBaseHref,
        backgroundColor: backgroundColor,
      );
      _useInAppWebView = true;
      _lastInAppWebViewIsDark = isDark;
      if (mounted) {
        setState(() {
          _resolvedBody = content;
          _isPreparingDocument = false;
        });
        if (_inAppController != null) {
          _scheduleWebViewLoadingFallback(inAppWebView: true);
          unawaited(
            _inAppController!.loadData(
              data: _inAppWebViewHtml!,
              mimeType: 'text/html',
              encoding: 'utf-8',
            ),
          );
        }
      }
      return;
    }

    if (Platform.isLinux) {
      if (mounted) {
        setState(() {
          _resolvedBody = content;
          _useHtmlWidget = true;
          _isPreparingDocument = false;
        });
      }
      return;
    }

    if (!(Platform.isAndroid || Platform.isIOS)) {
      if (mounted) {
        setState(() {
          _resolvedBody = content;
          _isPreparingDocument = false;
        });
      }
      return;
    }
    final fullHtml = _buildDocumentHtml(
      renderedBodyHtml,
      isDark: isDark,
      baseUrl: _documentBaseHref,
      backgroundColor: backgroundColor,
    );
    _htmlWidgetContent = _sanitizeBodyHtml(renderedBodyHtml);
    _standardDocumentReady = false;
    _standardWebViewAttached = false;

    void markDocumentReady() {
      _standardDocumentReady = true;
      if (_standardWebViewAttached) {
        unawaited(_finishStandardWebViewLoading());
      }
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FastCatDocument',
        onMessageReceived: (_) => markDocumentReady(),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => markDocumentReady(),
          onWebResourceError: (error) {
            if (!Platform.isLinux || error.isForMainFrame != true || !mounted) {
              return;
            }
            final platformController = _webController?.platform;
            if (platformController is WindowsPlatformWebViewController) {
              unawaited(platformController.controller.dispose());
            }
            setState(() {
              _webController = null;
              _useHtmlWidget = true;
              _webViewLoading = false;
            });
          },
          onNavigationRequest: (request) {
            if (!request.isMainFrame) return NavigationDecision.navigate;
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Set the native surface before the WebView is attached. Otherwise its
    // first frame follows the operating-system theme until HTML is painted.
    try {
      await controller.setBackgroundColor(backgroundColor);
    } catch (_) {
      // Background styling is best-effort; never block document loading when
      // an older platform WebView does not implement this operation.
    }
    if (!mounted) {
      final platformController = controller.platform;
      if (platformController is WindowsPlatformWebViewController) {
        unawaited(platformController.controller.dispose());
      }
      return;
    }
    if (!mounted || _resolvedBody != content) {
      final platformController = controller.platform;
      if (platformController is WindowsPlatformWebViewController) {
        unawaited(platformController.controller.dispose());
      }
      return;
    }
    if (_useHtmlWidget) {
      final platformController = controller.platform;
      if (platformController is WindowsPlatformWebViewController) {
        unawaited(platformController.controller.dispose());
      }
      return;
    }
    final previousPlatformController = _webController?.platform;
    if (previousPlatformController is WindowsPlatformWebViewController) {
      unawaited(previousPlatformController.controller.dispose());
    }
    _webController = controller;
    _standardWebViewAttached = true;
    _webViewLoading = true;
    _lastWebViewIsDark = isDark;
    setState(() {
      _resolvedBody = content;
      _isPreparingDocument = false;
    });
    _scheduleWebViewLoadingFallback(inAppWebView: false);
    unawaited(controller.loadHtmlString(fullHtml));
  }

  Future<void> _finishStandardWebViewLoading() async {
    _webViewLoadingFallback?.cancel();
    if (!mounted ||
        !_webViewLoading ||
        !_standardDocumentReady ||
        !_standardWebViewAttached ||
        _webController == null) {
      return;
    }

    // DOM 首帧可能在 WebView 尚未合成到 Flutter 窗口时就已经完成。
    // 等待原生视图挂载后的两个 Flutter 帧，避免关闭遮罩时露出白色表面。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_webViewLoading) return;
    final nextFrame = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => nextFrame.complete());
    WidgetsBinding.instance.scheduleFrame();
    await nextFrame.future;
    if (!mounted || !_webViewLoading) return;

    setState(() {
      _webViewLoading = false;
    });
  }

  Future<void> _finishInAppWebViewLoading() async {
    if (!mounted || !_inAppWebViewLoading) return;

    // The JavaScript callback means the document has completed two browser
    // paint cycles. Wait for Flutter's current frame as well so the loading
    // overlay is not removed between the native surface and Flutter frames.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_inAppWebViewLoading) return;

    _webViewLoadingFallback?.cancel();
    setState(() => _inAppWebViewLoading = false);
  }

  void _scheduleWebViewLoadingFallback({required bool inAppWebView}) {
    _webViewLoadingFallback?.cancel();
    _webViewLoadingFallback = Timer(
      const Duration(seconds: 8),
      inAppWebView
          ? () => unawaited(_finishInAppWebViewLoading())
          : () {
              _standardDocumentReady = true;
              unawaited(_finishStandardWebViewLoading());
            },
    );
  }

  Future<void> _reloadWebViewForTheme({
    required WebViewController controller,
    required String html,
    required Color backgroundColor,
  }) async {
    try {
      await controller.setBackgroundColor(backgroundColor);
    } catch (_) {
      // Keep the current document usable on platforms without this operation.
    }
    if (!mounted || !identical(_webController, controller)) return;
    await controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = widget.article;

    Widget contentArea;
    if (_resolvedBody == null) {
      // 与 Apex 一致：只有列表没有正文时才请求单篇详情；列表已有正文时
      // 不再后台校验并重建 WebView。
      final asyncDetail = ref.watch(
        knowledgeArticleDetailProvider(_detailRequest),
      );
      contentArea = asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            XbErrorState(message: e.toString(), onRetry: _retryDetail),
        data: (result) {
          final fetchedBody =
              _stripLeadingTitle(_parseDetailBody(result)).trim();
          if (!_isPreparingDocument) {
            _isPreparingDocument = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _resolvedBody != null) return;
              if (fetchedBody.isEmpty) {
                setState(() {
                  _resolvedBody = '';
                  _isPreparingDocument = false;
                });
              } else {
                unawaited(_prepareDocument(fetchedBody));
              }
            });
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      contentArea = _buildContentArea(theme);
    }

    return PopScope(
      canPop: !Platform.isLinux || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_closeDetailPage());
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isClosing ? null : _closeDetailPage,
          ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
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
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(article.createdDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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

    // 与 Apex 一致：Linux 直接使用 HtmlWidget，不创建原生 WebView。
    if (_useHtmlWidget && _htmlWidgetContent != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: NoticeHtmlStyles.buildNoticeHtml(
          context: context,
          htmlContent: _htmlWidgetContent!,
          preserveDocumentStyles: true,
          onTapUrl: (url) {
            if (url == null) return;
            final uri = Uri.tryParse(url);
            if (uri != null) {
              unawaited(
                launchUrl(uri, mode: LaunchMode.externalApplication),
              );
            }
          },
        ),
      );
    }

    if (_useInAppWebView) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if ((_inAppWebViewHtml == null || _lastInAppWebViewIsDark != isDark) &&
          _renderedBodyHtml != null) {
        _inAppWebViewHtml = _buildDocumentHtml(
          _renderedBodyHtml!,
          isDark: isDark,
          baseUrl: _documentBaseHref,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        );
        _lastInAppWebViewIsDark = isDark;
      }
      if (_inAppWebViewHtml == null) {
        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return Stack(
        children: [
          iaw.InAppWebView(
            key: ValueKey(isDark),
            initialData: iaw.InAppWebViewInitialData(
              data: _inAppWebViewHtml!,
              mimeType: 'text/html',
              encoding: 'utf-8',
            ),
            initialSettings: iaw.InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: false,
              underPageBackgroundColor:
                  Theme.of(context).scaffoldBackgroundColor,
            ),
            onWebViewCreated: (controller) {
              _inAppController = controller;
              _scheduleWebViewLoadingFallback(inAppWebView: true);
              controller.addJavaScriptHandler(
                handlerName: 'documentRendered',
                callback: (_) {
                  unawaited(_finishInAppWebViewLoading());
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'openExternal',
                callback: (args) async {
                  final url = args.isNotEmpty ? args[0].toString() : '';
                  if (url.isNotEmpty) {
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
              );
            },
            onLoadStop: (_, __) {
              _inAppController?.evaluateJavascript(source: r'''
(function(){
  // Ignore the WebView's initial blank document. Some desktop backends emit
  // onLoadStop for it before loadData() commits the actual article.
  if (document.documentElement.getAttribute("data-fastcat-document") !== "true") return;
  if (window.__fastcatDocInterceptInstalled) return;
  window.__fastcatDocInterceptInstalled = true;
  function isDownloadLike(url) {
    var lower = (url || "").split("?")[0].toLowerCase();
    if (/\.(dmg|exe|apk|zip|7z|rar|tar\.gz|tar|gz|bz2|deb|rpm|msi|ipa|pkg|iso|bin)$/.test(lower)) return true;
    if (/\/(download|file|d|s|share)\//.test(lower)) return true;
    return false;
  }
  document.addEventListener("click", function(e) {
    var el = e.target;
    while (el && el !== document) {
      if (el.tagName === "A" && el.href) {
        var cls = (el.className && el.className.baseVal !== undefined) ? el.className.baseVal : (el.className || "");
        var target = (el.getAttribute("target") || "").toLowerCase();
        if (cls.indexOf("download-btn") !== -1 || target === "_blank" || isDownloadLike(el.href)) {
          e.preventDefault();
          e.stopPropagation();
          window.flutter_inappwebview.callHandler("openExternal", el.href);
          return false;
        }
        break;
      }
      el = el.parentElement;
    }
  }, true);

  // onLoadStop can fire before the native WebView has submitted its first
  // painted frame. Two animation frames ensure text/layout has been painted
  // before Flutter removes the cover. Images are intentionally not awaited,
  // so slow images can appear progressively after the text is visible.
  if (!window.__fastcatDocRenderDelivered) {
    window.__fastcatDocRenderDelivered = true;
    requestAnimationFrame(function() {
      requestAnimationFrame(function() {
        window.flutter_inappwebview.callHandler("documentRendered");
      });
    });
  }
})();
''');
            },
            shouldOverrideUrlLoading: (_, navigationAction) async {
              // Allow iframes and subresources to load inline (not main-frame nav)
              if (!navigationAction.isForMainFrame) {
                return iaw.NavigationActionPolicy.ALLOW;
              }
              final url = navigationAction.request.url?.toString() ?? '';
              if (url.isNotEmpty) {
                final uri = Uri.tryParse(url);
                if (uri != null &&
                    (uri.scheme == 'http' || uri.scheme == 'https')) {
                  // Fallback: open download links in browser
                  final lower = url.split('?')[0].toLowerCase();
                  final isDownload = lower.endsWith('.dmg') ||
                      lower.endsWith('.exe') ||
                      lower.endsWith('.apk') ||
                      lower.endsWith('.zip') ||
                      lower.endsWith('.7z') ||
                      lower.endsWith('.rar') ||
                      lower.endsWith('.tar.gz') ||
                      lower.endsWith('.tar') ||
                      lower.endsWith('.gz') ||
                      lower.endsWith('.bz2') ||
                      lower.endsWith('.deb') ||
                      lower.endsWith('.rpm') ||
                      lower.endsWith('.msi') ||
                      lower.endsWith('.ipa') ||
                      lower.endsWith('.pkg') ||
                      lower.endsWith('.iso') ||
                      lower.endsWith('.bin');
                  if (isDownload) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    return iaw.NavigationActionPolicy.CANCEL;
                  }
                  // Non-download link: allow navigating within the webview
                  return iaw.NavigationActionPolicy.ALLOW;
                }
              }
              return iaw.NavigationActionPolicy.ALLOW;
            },
          ),
          if (_inAppWebViewLoading)
            Positioned.fill(
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
    }

    if ((Platform.isAndroid || Platform.isIOS) && _webController != null) {
      final currentIsDark = theme.brightness == Brightness.dark;
      if (_lastWebViewIsDark != currentIsDark && _renderedBodyHtml != null) {
        final fullHtml = _buildDocumentHtml(
          _renderedBodyHtml!,
          isDark: currentIsDark,
          baseUrl: _documentBaseHref,
          backgroundColor: theme.scaffoldBackgroundColor,
        );
        final controller = _webController!;
        _lastWebViewIsDark = currentIsDark;
        unawaited(
          _reloadWebViewForTheme(
            controller: controller,
            html: fullHtml,
            backgroundColor: theme.scaffoldBackgroundColor,
          ),
        );
      }
      return Stack(
        children: [
          WebViewWidget(controller: _webController!),
          if (_webViewLoading)
            Positioned.fill(
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
    }

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: _isPreparingDocument
          ? const Center(child: CircularProgressIndicator())
          : null,
    );
  }
}
