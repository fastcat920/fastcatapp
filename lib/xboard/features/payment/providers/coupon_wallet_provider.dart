import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/initialization/providers/initialization_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

// Only an account change resets the wallet, not subscription/UI state updates.
final couponWalletSessionProvider = Provider<String?>((ref) {
  return ref.watch(xboardUserAuthProvider.select(
    (auth) => auth.isAuthenticated ? (auth.email ?? '') : null,
  ));
});

final couponWalletReadyProvider = Provider<bool>((ref) {
  final initialized = ref.watch(isInitializedProvider);
  return initialized &&
      ref.watch(xboardUserAuthProvider.select(
        (auth) => auth.isAuthenticated && !auth.isLoading,
      ));
});

final couponWalletLoaderProvider =
    Provider<Future<List<CatboardCoupon>> Function()>((ref) {
  return () async {
    final sdk = await ref.read(xboardSdkProvider.future);
    return sdk.catboard.getCouponWallet();
  };
});

final couponWalletProvider =
    NotifierProvider<CouponWalletNotifier, AsyncValue<List<CatboardCoupon>>>(
        CouponWalletNotifier.new);

class CouponWalletNotifier extends Notifier<AsyncValue<List<CatboardCoupon>>> {
  int _generation = 0;
  Future<void>? _inFlight;
  String? _session;

  @override
  AsyncValue<List<CatboardCoupon>> build() {
    _session = ref.watch(couponWalletSessionProvider);
    final generation = ++_generation;
    _inFlight = null;
    ref.onDispose(() => _generation++);
    if (_session == null) return const AsyncData([]);

    void refreshIfActive() {
      if (generation == _generation) unawaited(refresh());
    }

    ref.listen(couponWalletReadyProvider, (_, ready) {
      if (ready) refreshIfActive();
    });
    final observer = _WalletLifecycleObserver(refreshIfActive);
    WidgetsBinding.instance.addObserver(observer);
    final timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        refreshIfActive();
      }
    });
    ref.onDispose(() {
      timer.cancel();
      WidgetsBinding.instance.removeObserver(observer);
    });
    Future.microtask(refreshIfActive);
    return const AsyncLoading();
  }

  Future<void> refresh() {
    if (_session == null || !ref.read(couponWalletReadyProvider)) {
      return Future.value();
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final generation = _generation;
    final session = _session;
    final loader = ref.read(couponWalletLoaderProvider);
    final previous = state;
    state =
        const AsyncLoading<List<CatboardCoupon>>().copyWithPrevious(previous);
    final task = Future<void>(() async {
      try {
        if (generation != _generation ||
            ref.read(couponWalletSessionProvider) != session) {
          return;
        }
        final coupons = await loader().timeout(const Duration(seconds: 30));
        if (generation != _generation ||
            ref.read(couponWalletSessionProvider) != session) {
          return;
        }
        state = AsyncData(coupons);
      } catch (error, stack) {
        if (generation != _generation ||
            ref.read(couponWalletSessionProvider) != session) {
          return;
        }
        // A temporary network error must not turn a known wallet into empty.
        state = AsyncError<List<CatboardCoupon>>(error, stack)
            .copyWithPrevious(previous);
      } finally {
        if (generation == _generation) _inFlight = null;
      }
    });
    _inFlight = task;
    return task;
  }
}

class _WalletLifecycleObserver extends WidgetsBindingObserver {
  _WalletLifecycleObserver(this.refresh);
  final VoidCallback refresh;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }
}
