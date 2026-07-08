import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

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
  final raw = await sdk.httpService
      .getRequest('/user/knowledge/fetch?language=$language');
  return parseKnowledgeArticles(raw);
});

/// 单篇文章详情 Provider
final knowledgeArticleDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?,
        KnowledgeArticleDetailRequest>((ref, request) async {
  final sdk = await ref.read(xboardSdkProvider.future);
  final language = Uri.encodeQueryComponent(request.language);
  final cacheBuster = DateTime.now().millisecondsSinceEpoch;
  final raw = await sdk.httpService.getRequest(
    '/user/knowledge/fetch?id=${request.id}&language=$language&_t=$cacheBuster',
  );
  return raw is Map<String, dynamic> ? raw : null;
});
