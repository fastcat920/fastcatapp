import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class KnowledgeArticleDetailRequest {
  final int id;
  final String language;

  const KnowledgeArticleDetailRequest({
    required this.id,
    required this.language,
  });

  @override
  bool operator ==(Object other) =>
      other is KnowledgeArticleDetailRequest &&
      other.id == id &&
      other.language == language;

  @override
  int get hashCode => Object.hash(id, language);
}

/// 知识库文章模型
class KnowledgeArticle {
  final int id;
  final String category;
  final String title;
  final String body;
  final int createdAt;

  const KnowledgeArticle({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticle(
      id: pickInt(json, ['id', 'article_id', 'knowledge_id']),
      category: pickString(json, ['category', 'group', 'type']).isNotEmpty
          ? pickString(json, ['category', 'group', 'type'])
          : '其他',
      title: pickString(json, ['title', 'question']),
      body: pickString(json, ['body', 'content', 'answer']),
      createdAt: pickInt(json, ['updated_at', 'created_at']),
    );
  }

  DateTime get createdDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  static String pickString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  static int pickInt(Map<String, dynamic> json, List<String> keys) {
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
}

// ── Parsers ─────────────────────────────────────────────────────────────────

List<KnowledgeArticle> parseKnowledgeArticles(dynamic result) {
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

// ── Providers ───────────────────────────────────────────────────────────────

/// 知识库文章列表 Provider（keepAlive — 全局缓存）
///
/// 使用 `ref.invalidate(knowledgeArticlesProvider(language))` 强制刷新。
final knowledgeArticlesProvider =
    FutureProvider.family<List<KnowledgeArticle>, String>(
        (ref, language) async {
  final sdk = await ref.read(xboardSdkProvider.future);
  final uri = Uri(
    path: '/user/knowledge/fetch',
    queryParameters: {'language': language},
  );
  final raw = await sdk.httpService.getRequest(uri.toString());
  // 列表刷新后正文可能已经更新，不能再让旧的详情缓存覆盖列表中的新正文。
  ApiRequestCache.invalidatePrefix(_knowledgeArticleDetailCachePrefix);
  return parseKnowledgeArticles(raw);
});

const _knowledgeArticleDetailCachePrefix = 'knowledge:detail:';

String _knowledgeArticleDetailCacheKey(KnowledgeArticleDetailRequest request) =>
    '$_knowledgeArticleDetailCachePrefix${request.id}:${request.language}';

/// 清除单篇文章详情缓存，用于用户主动重试或刷新。
void invalidateKnowledgeArticleDetailCache(
  KnowledgeArticleDetailRequest request,
) {
  ApiRequestCache.invalidate(_knowledgeArticleDetailCacheKey(request));
}

/// 单篇文章详情 Provider。
///
/// Provider 离开页面后可以自动释放；短时间内重新打开时，由请求缓存直接
/// 返回结果，并合并同一篇文章的并发请求。
final knowledgeArticleDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, KnowledgeArticleDetailRequest>(
        (ref, request) async {
  return ApiRequestCache.get<Map<String, dynamic>?>(
    _knowledgeArticleDetailCacheKey(request),
    ttl: const Duration(minutes: 5),
    fetch: () async {
      final sdk = await ref.read(xboardSdkProvider.future);
      final uri = Uri(
        path: '/user/knowledge/fetch',
        queryParameters: {
          'id': request.id.toString(),
          'language': request.language,
        },
      );
      final raw = await sdk.httpService.getRequest(uri.toString());
      return raw;
    },
  );
});
