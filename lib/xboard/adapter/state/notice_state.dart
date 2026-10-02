import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';

import 'package:fl_clash/xboard/infrastructure/cache/content_cache_scope.dart';

part 'generated/notice_state.g.dart';

/// 公告状态管理

/// 获取公告列表
@riverpod
Future<List<NoticeModel>> getNotices(Ref ref) async {
  final sdk = await ref.watch(xboardSdkProvider.future);
  final scope = await ContentCacheScope.current();
  if (scope == null) return [];
  return ApiRequestCache.get<List<NoticeModel>>(
    'xboard:notices:$scope',
    ttl: const Duration(minutes: 5),
    fetch: sdk.notice.getNotices,
  );
}

void clearGetNoticesCache() {
  ApiRequestCache.invalidatePrefix('xboard:notices:');
}
