import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/api_request_cache.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';

part 'generated/payment_state.g.dart';

/// 支付状态管理

/// 获取支付方式列表
@riverpod
Future<List<PaymentMethodModel>> getPaymentMethods(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  final methods = await ApiRequestCache.get<List<PaymentMethodModel>>(
    'xboard:payment_methods:$epoch',
    ttl: const Duration(minutes: 10),
    fetch: sdk.payment.getPaymentMethods,
  );
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  return methods;
}

void clearGetPaymentMethodsCache() {
  ApiRequestCache.invalidatePrefix('xboard:payment_methods:');
}
