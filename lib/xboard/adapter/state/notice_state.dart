import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';

import 'package:fl_clash/xboard/infrastructure/cache/content_cache_scope.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';

part 'generated/notice_state.g.dart';

/// 公告状态管理

/// 获取公告列表
@riverpod
Future<List<NoticeModel>> getNotices(Ref ref) async {
  final lease = ref.keepAlive();
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  try {
    final sdk = await ref.watch(xboardSdkProvider.future);
    final scope = await ContentCacheScope.current();
    if (!active || ref.read(sessionEpochProvider) != epoch) {
      throw StateError('公告请求所属会话已失效');
    }
    if (scope == null) throw StateError('公告认证信息尚未就绪');
    final notices = await ApiRequestCache.get<List<NoticeModel>>(
      'xboard:notices:$epoch:$scope',
      ttl: const Duration(minutes: 5),
      fetch: sdk.notice.getNotices,
    );
    if (!active || ref.read(sessionEpochProvider) != epoch) {
      throw StateError('公告请求所属会话已失效');
    }
    return notices;
  } finally {
    lease.close();
  }
}

void clearGetNoticesCache() {
  ApiRequestCache.invalidatePrefix('xboard:notices:');
}
