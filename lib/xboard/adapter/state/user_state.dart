import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';

part 'generated/user_state.g.dart';

/// 用户状态管理

/// 获取用户信息
@riverpod
Future<UserModel> getUserInfo(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) {
    throw StateError('Account session changed');
  }
  final value = await ApiRequestCache.get<UserModel>(
    'xboard:user_info:$epoch',
    ttl: const Duration(minutes: 2),
    fetch: sdk.user.getUserInfo,
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) {
    throw StateError('Account session changed');
  }
  return value;
}

void clearGetUserInfoCache() {
  ApiRequestCache.invalidatePrefix('xboard:user_info');
}
