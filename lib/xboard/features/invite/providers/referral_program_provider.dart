import 'dart:async';

import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/services/storage/xboard_storage_provider.dart';
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

  @override
  ReferralProgramState build() {
    final cacheReady = Completer<void>();
    _cacheReady = cacheReady;
    Future<void>(() => _initialize(cacheReady, _generation));
    return const ReferralProgramState(isLoading: true);
  }

  Future<void> _initialize(
    Completer<void> cacheReady,
    int generation,
  ) async {
    try {
      await ref.read(storageProvider.future);
      final cached =
          (await ref.read(storageServiceProvider).getCatboardReferralProgram())
              .dataOrNull;
      if (generation == _generation && cached != null) {
        state = ReferralProgramState(program: cached);
      }
    } catch (_) {
      // 缓存不可用不应阻止网络加载。
    } finally {
      if (!cacheReady.isCompleted) cacheReady.complete();
    }
    if (generation != _generation) return;
    await refresh();
  }

  Future<void> refresh() async {
    await _cacheReady?.future;
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
      final sdk = await ref.read(xboardSdkProvider.future);
      final program = await sdk.catboard.getReferralProgram();
      if (generation != _generation) return;
      if (program == null) {
        await ref.read(storageServiceProvider).clearCatboardReferralProgram();
      } else {
        unawaited(ref
            .read(storageServiceProvider)
            .saveCatboardReferralProgram(program));
      }
      state = ReferralProgramState(program: program);
    } catch (error) {
      if (generation != _generation) return;
      // 推广等级是增强能力。网络失败时继续展示缓存，避免页面闪烁。
      state = ReferralProgramState(program: previous, error: error);
    }
  }

  Future<void> clear() async {
    _generation++;
    await ref.read(storageServiceProvider).clearCatboardReferralProgram();
    state = const ReferralProgramState();
  }
}

final referralProgramProvider =
    NotifierProvider<ReferralProgramNotifier, ReferralProgramState>(
  ReferralProgramNotifier.new,
);
