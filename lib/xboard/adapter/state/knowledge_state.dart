import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';

class KnowledgeArticleDetailRequest {
  final int id;
  final String language;

  const KnowledgeArticleDetailRequest({
    required this.id,
    required this.language,
  });

  @override
  bool operator ==(Object other) {
    return other is KnowledgeArticleDetailRequest &&
        other.id == id &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(id, language);
}

/// 知识库文章列表 Provider（keepAlive — 全局缓存，避免每次进入页面重新请求）
///
/// 注意：V2Board 列表接口不含 body 字段，XBoard 列表接口含 body。
/// 使用 `ref.invalidate(knowledgeArticlesProvider(language))` 强制刷新。
final knowledgeArticlesProvider =
    FutureProvider.family<dynamic, String>((ref, language) async {
  final sdk = await ref.read(xboardSdkProvider.future);
  return await sdk.httpService
      .getRequest('/user/knowledge/fetch?language=$language');
});

/// 单篇文章详情 Provider（带 body，XBoard/V2Board 均支持）
///
/// 用 ?id={id} 参数请求完整文章（含 body、订阅链接占位符替换、访问控制处理）。
/// V2Board 列表不含 body，必须通过此接口获取内容。
final knowledgeArticleDetailProvider =
    FutureProvider.family<dynamic, KnowledgeArticleDetailRequest>(
        (ref, request) async {
  final sdk = await ref.read(xboardSdkProvider.future);
  final language = Uri.encodeQueryComponent(request.language);
  return await sdk.httpService
      .getRequest('/user/knowledge/fetch?id=${request.id}&language=$language');
});
