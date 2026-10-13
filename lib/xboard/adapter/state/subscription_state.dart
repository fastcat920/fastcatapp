import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';

part 'generated/subscription_state.g.dart';

/// 订阅状态管理

/// 获取订阅信息
@riverpod
Future<SubscriptionModel> getSubscription(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) {
    throw StateError('Account session changed');
  }
  final value = await ApiRequestCache.get<SubscriptionModel>(
    'xboard:subscription:$epoch',
    ttl: const Duration(minutes: 1),
    fetch: sdk.subscription.getSubscription,
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) {
    throw StateError('Account session changed');
  }
  return value;
}

/// 获取订阅链接
@riverpod
Future<String> getSubscribeUrl(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) {
    throw StateError('Account session changed');
  }
  final value = await ApiRequestCache.get<String>(
    'xboard:subscribe_url:$epoch',
    ttl: const Duration(minutes: 5),
    fetch: sdk.subscription.getSubscribeUrl,
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) {
    throw StateError('Account session changed');
  }
  return value;
}

void clearGetSubscriptionCache() {
  ApiRequestCache.invalidatePrefix('xboard:subscription');
}

void clearGetSubscribeUrlCache() {
  ApiRequestCache.invalidatePrefix('xboard:subscribe_url');
}
