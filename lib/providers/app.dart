import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

part 'generated/app.g.dart';

// ── Toggle ────────────────────────────────────────────────────────────────

@riverpod
class RealTunEnable extends _$RealTunEnable with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.realTunEnable;
  @override
  onUpdate(value) => globalState.appState =
      globalState.appState.copyWith(realTunEnable: value);
}

// ── Logs ──────────────────────────────────────────────────────────────────

@riverpod
class Logs extends _$Logs with AutoDisposeNotifierMixin {
  @override
  FixedList<Log> build() => globalState.appState.logs;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(logs: value);

  void addLog(Log value) {
    state = state.copyWith()..add(value);
  }

  void clear() {
    state = state.copyWith()..clear();
  }
}

// ── Requests ──────────────────────────────────────────────────────────────

@riverpod
class Requests extends _$Requests with AutoDisposeNotifierMixin {
  @override
  FixedList<Connection> build() => globalState.appState.requests;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(requests: value);

  void addRequest(Connection value) {
    state = state.copyWith()..add(value);
  }

  void clear() {
    state = state.copyWith()..clear();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

@riverpod
class Providers extends _$Providers with AutoDisposeNotifierMixin {
  @override
  List<ExternalProvider> build() => globalState.appState.providers;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(providers: value);

  void setProvider(ExternalProvider? provider) {
    if (provider == null) return;
    final index = state.indexWhere((item) => item.name == provider.name);
    if (index == -1) return;
    state = List.from(state)..[index] = provider;
  }
}

// ── Packages ──────────────────────────────────────────────────────────────

@riverpod
class Packages extends _$Packages with AutoDisposeNotifierMixin {
  @override
  List<Package> build() => globalState.appState.packages;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(packages: value);
}

// ── Brightness ────────────────────────────────────────────────────────────

@riverpod
class AppBrightness extends _$AppBrightness with AutoDisposeNotifierMixin {
  @override
  Brightness? build() => globalState.appState.brightness;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(brightness: value);

  void setState(Brightness? value) => state = value;
}

// ── Traffic ───────────────────────────────────────────────────────────────

@riverpod
class Traffics extends _$Traffics with AutoDisposeNotifierMixin {
  @override
  FixedList<Traffic> build() => globalState.appState.traffics;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(traffics: value);

  void addTraffic(Traffic value) {
    state = state.copyWith()..add(value);
  }

  void clear() {
    state = state.copyWith()..clear();
  }
}

@riverpod
class TotalTraffic extends _$TotalTraffic with AutoDisposeNotifierMixin {
  @override
  Traffic build() => globalState.appState.totalTraffic;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(totalTraffic: value);
}

// ── Network ───────────────────────────────────────────────────────────────

@riverpod
class LocalIp extends _$LocalIp with AutoDisposeNotifierMixin {
  @override
  String? build() => globalState.appState.localIp;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(localIp: value);

  @override
  set state(String? value) {
    super.state = value;
    globalState.appState = globalState.appState.copyWith(localIp: state);
  }
}

// ── Time ──────────────────────────────────────────────────────────────────

@riverpod
class RunTime extends _$RunTime with AutoDisposeNotifierMixin {
  @override
  int? build() => globalState.appState.runTime;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(runTime: value);

  bool get isStart => state != null;
}

// ── View ──────────────────────────────────────────────────────────────────

@riverpod
class ViewSize extends _$ViewSize with AutoDisposeNotifierMixin {
  @override
  Size build() => globalState.appState.viewSize;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(viewSize: value);

  ViewMode get viewMode => utils.getViewMode(state.width);
  bool get isMobileView => viewMode == ViewMode.mobile;
}

@riverpod
double viewWidth(Ref ref) => ref.watch(viewSizeProvider).width;
@riverpod
ViewMode viewMode(Ref ref) => utils.getViewMode(ref.watch(viewWidthProvider));
@riverpod
bool isMobileView(Ref ref) => ref.watch(viewModeProvider) == ViewMode.mobile;
@riverpod
double viewHeight(Ref ref) => ref.watch(viewSizeProvider).height;

// ── App lifecycle ─────────────────────────────────────────────────────────

@riverpod
class Init extends _$Init with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.isInit;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(isInit: value);
}

@riverpod
class CurrentPageLabel extends _$CurrentPageLabel
    with AutoDisposeNotifierMixin {
  @override
  PageLabel build() => globalState.appState.pageLabel;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(pageLabel: value);
}

// ── Counters ──────────────────────────────────────────────────────────────

@riverpod
class SortNum extends _$SortNum with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.sortNum;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(sortNum: value);

  void add() => state++;
}

@riverpod
class CheckIpNum extends _$CheckIpNum with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.checkIpNum;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(checkIpNum: value);

  void add() => state++;
}

// ── UI locks ──────────────────────────────────────────────────────────────

@riverpod
class BackBlock extends _$BackBlock with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.backBlock;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(backBlock: value);
}

@riverpod
class Version extends _$Version with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.version;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(version: value);
}

// ── Groups (proxies) ──────────────────────────────────────────────────────

@riverpod
class Groups extends _$Groups with AutoDisposeNotifierMixin {
  @override
  List<Group> build() => globalState.appState.groups;
  @override
  onUpdate(value) {
    globalState.appState = globalState.appState.copyWith(groups: value);
    _cacheGroups(value);
  }

  void _cacheGroups(List<Group> groups) {
    // 短暂的核心未就绪或订阅更新失败不应覆盖最后一份可用节点缓存。
    // 登出时由认证流程显式清理缓存，避免跨账号保留。
    if (groups.isEmpty) return;
    SharedPreferences.getInstance().then((prefs) {
      final json = jsonEncode(groups.map((g) => g.toJson()).toList());
      prefs.setString('cached_groups', json);
    });
  }
}

// ── Delay ─────────────────────────────────────────────────────────────────

@riverpod
class DelayDataSource extends _$DelayDataSource with AutoDisposeNotifierMixin {
  @override
  DelayMap build() => globalState.appState.delayMap;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(delayMap: value);

  void setDelay(Delay delay) {
    if (state[delay.url]?[delay.name] != delay.value) {
      final DelayMap newDelayMap = Map.from(state);
      newDelayMap.putIfAbsent(delay.url, () => {});
      newDelayMap[delay.url]![delay.name] = delay.value;
      state = newDelayMap;
    }
  }
}

// ── Proxies search ────────────────────────────────────────────────────────

@riverpod
class ProxiesQuery extends _$ProxiesQuery with AutoDisposeNotifierMixin {
  @override
  String build() => globalState.appState.proxiesQuery;
  @override
  onUpdate(value) =>
      globalState.appState = globalState.appState.copyWith(proxiesQuery: value);
}
