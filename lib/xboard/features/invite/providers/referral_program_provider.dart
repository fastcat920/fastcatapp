import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/infrastructure/cache/content_cache_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class ReferralProgramState {
  const ReferralProgramState({
    this.program,
    this.isLoading = false,
    this.error,
  });

  final CatboardReferralProgram? program;
  final bool isLoading;
  final Object? error;
}

class ReferralProgramNotifier extends Notifier<ReferralProgramState> {
  Future<void>? _refreshing;
  Completer<void>? _cacheReady;
  int _generation = 0;
  int _epoch = 0;
  bool _disposed = false;

  bool _isCurrent(int generation) =>
      !_disposed &&
      generation == _generation &&
      ref.read(sessionEpochProvider) == _epoch;

  @override
  ReferralProgramState build() {
    _epoch = ref.watch(sessionEpochProvider);
    final generation = ++_generation;
    _disposed = false;
    _refreshing = null;
    ref.onDispose(() => _disposed = true);
    final cacheReady = Completer<void>();
    _cacheReady = cacheReady;
    Future<void>(() => _initialize(cacheReady, generation));
    return const ReferralProgramState(isLoading: true);
  }

  Future<void> _initialize(
    Completer<void> cacheReady,
    int generation,
  ) async {
    try {
      if (!_isCurrent(generation)) return;
      final scope = await ContentCacheScope.current();
      if (!_isCurrent(generation)) return;
      if (scope != null) {
        await ref.read(storageProvider.future);
        if (!_isCurrent(generation)) return;
        final cached = (await ref
                .read(storageServiceProvider)
                .getCatboardReferralProgram(scope: scope))
            .dataOrNull;
        if (_isCurrent(generation) && cached != null) {
          state = ReferralProgramState(program: cached);
        }
      }
    } catch (_) {
      // 缓存不可用不应阻止网络加载。
    } finally {
      if (!cacheReady.isCompleted) cacheReady.complete();
    }
    if (!_isCurrent(generation)) return;
    await refresh();
  }

  Future<void> refresh() async {
    final generation = _generation;
    await _cacheReady?.future;
    if (!_isCurrent(generation)) return;
    final activeRefresh = _refreshing;
    if (activeRefresh != null) return await activeRefresh;

    final refresh = _refresh();
    _refreshing = refresh;
    await refresh.whenComplete(() {
      if (identical(_refreshing, refresh)) _refreshing = null;
    });
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final previous = state.program;
    state = ReferralProgramState(program: previous, isLoading: true);
    try {
      final scope = await ContentCacheScope.current();
      if (!_isCurrent(generation)) return;
      final sdk = await ref.read(xboardSdkProvider.future);
      if (!_isCurrent(generation)) return;
      final program = await sdk.catboard.getReferralProgram();
      if (!_isCurrent(generation)) return;
      if (program == null) {
        await ref.read(storageServiceProvider).clearCatboardReferralProgram();
      } else if (scope != null) {
        await ref
            .read(storageServiceProvider)
            .saveCatboardReferralProgram(program, scope: scope);
      }
      if (!_isCurrent(generation)) return;
      state = ReferralProgramState(program: program);
    } catch (error) {
      if (!_isCurrent(generation)) return;
      // 推广等级是增强能力。网络失败时继续展示缓存，避免页面闪烁。
      state = ReferralProgramState(program: previous, error: error);
    }
  }

  Future<void> clear() async {
    final generation = ++_generation;
    await ref.read(storageServiceProvider).clearCatboardReferralProgram();
    if (!_isCurrent(generation)) return;
    state = const ReferralProgramState();
  }
}

final referralProgramProvider =
    NotifierProvider<ReferralProgramNotifier, ReferralProgramState>(
  ReferralProgramNotifier.new,
);
