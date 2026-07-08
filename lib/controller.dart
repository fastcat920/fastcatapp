import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/app_backup_service.dart';
import 'package:fl_clash/services/app_exit_service.dart';
import 'package:fl_clash/services/app_profile_controller.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/xboard/features/auth/services/device_heartbeat_service.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';

import 'common/common.dart';
import 'models/models.dart';
import 'views/profiles/override_profile.dart';

class _TunAdminResult {
  const _TunAdminResult({
    required this.enableTun,
    required this.didRestartCore,
  });

  final bool enableTun;
  final bool didRestartCore;
}

class AppController {
  int? lastProfileModified;

  /// 默认 true：启动时不自动弹 UAC，只有用户在设置中手动开启 TUN 时
  /// 通过 resetTunAdminDenied() 重置为 false，才允许弹 UAC 提权。
  /// 解决非管理员运行时反复弹 UAC 的问题。
  bool _tunAdminDenied = true;
  bool _isCoreSwitching = false;

  bool get isCoreSwitching => _isCoreSwitching;

  /// 订阅导入流程正在执行 applyProfile 时为 true，
  /// 防止 ClashManager 的 needSetupProvider 监听器重复触发 handleChangeProfile，
  /// 避免两个并发 applyProfile 竞争导致 groups 被清空。
  bool isImportApplying = false;

  /// 用户在设置中主动开启 TUN 时调用，允许再次弹出 UAC
  void resetTunAdminDenied() => _tunAdminDenied = false;

  final BuildContext context;
  final WidgetRef _ref;
  late final AppExitService _exitService;
  late final AppBackupService _backupService;
  late final AppProfileController _profileController;

  AppController(this.context, WidgetRef ref) : _ref = ref {
    _exitService = const AppExitService();
    _backupService = AppBackupService(_ref);
    _profileController = AppProfileController(
      _ref,
      applyProfileDebounce: applyProfileDebounce,
      updateStatus: updateStatus,
    );
  }

  setupClashConfigDebounce() {
    debouncer.call(FunctionTag.setupClashConfig, () async {
      await setupClashConfig();
    });
  }

  updateClashConfigDebounce({
    Duration duration = const Duration(milliseconds: 600),
  }) {
    if (duration <= Duration.zero) {
      debouncer.cancel(FunctionTag.updateClashConfig);
      unawaited(updateClashConfig());
      return;
    }
    debouncer.call(FunctionTag.updateClashConfig, () async {
      await updateClashConfig();
    }, duration: duration);
  }

  updateGroupsDebounce() {
    debouncer.call(FunctionTag.updateGroups, updateGroups);
  }

  addCheckIpNumDebounce() {
    debouncer.call(FunctionTag.addCheckIpNum, () {
      _ref.read(checkIpNumProvider.notifier).add();
    });
  }

  applyProfileDebounce({
    bool silence = false,
  }) {
    debouncer.call(FunctionTag.applyProfile, (silence) {
      applyProfile(silence: silence);
    }, args: [silence]);
  }

  savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, savePreferences);
  }

  changeProxyDebounce(String groupName, String proxyName) {
    debouncer.call(FunctionTag.changeProxy,
        (String groupName, String proxyName) async {
      if (Platform.isIOS) {
        // iOS: selection already saved locally by updateCurrentSelectedMap().
        // If VPN is connected, tell mihomo to switch proxy but do NOT call
        // updateGroups() — IPC getProxies can return empty and wipe the list.
        if (globalState.isStart) {
          try {
            await changeProxy(
              groupName: groupName,
              proxyName: proxyName,
            );
          } catch (_) {}
        }
        return;
      }
      await changeProxy(
        groupName: groupName,
        proxyName: proxyName,
      );
      await updateGroups();
    }, args: [groupName, proxyName]);
  }

  restartCore({
    bool setupProfile = true,
    bool restoreStart = true,
  }) async {
    commonPrint.log('restart core');
    final wasStart = _ref.read(runTimeProvider.notifier).isStart;
    await clashService?.reStart();
    await _initCore(setupProfile: setupProfile);
    if (restoreStart && wasStart) {
      globalState.startTime = null; // 重启后计时归零
      await globalState.handleStart();
    }
  }

  Future<bool> updateStatus(bool isStart) async {
    if (_isCoreSwitching) return false;
    _isCoreSwitching = true;
    globalState.isCoreSwitchingNotifier.value = true;
    unawaited(XBoardDeviceHeartbeatService.markActive(
      reason: isStart ? 'proxy_start' : 'proxy_stop',
      force: true,
    ));
    try {
      if (isStart) {
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.coreConnecting,
        );
        await globalState.handleStart([
          updateRunTime,
          updateTraffic,
        ]);
        // handleStart resets startTime to null on VPN failure — bail out
        if (globalState.startTime == null) {
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.failed,
          );
          return false;
        }
        if (_ref.read(realTunEnableProvider)) {
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.tunApplying,
          );
        }
        if (Platform.isIOS) {
          // Traffic routing just enabled — mihomo was already running in idle mode.
          // Refresh groups from the core and re-apply the user's selected proxy.
          await _refreshGroupsAfterConnect();
          addCheckIpNumDebounce();
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.connected,
          );
          return true;
        }
        final currentLastModified =
            await _ref.read(currentProfileProvider)?.profileLastModified;
        if (currentLastModified == null || lastProfileModified == null) {
          addCheckIpNumDebounce();
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.connected,
          );
          return true;
        }
        if (currentLastModified <= (lastProfileModified ?? 0)) {
          addCheckIpNumDebounce();
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.connected,
          );
          return true;
        }
        applyProfileDebounce();
        addCheckIpNumDebounce();
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.connected,
        );
        return true;
      } else {
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.stopping,
        );
        await globalState.handleStop();
        await clashCore.resetTraffic();
        _ref.read(trafficsProvider.notifier).clear();
        _ref.read(totalTrafficProvider.notifier).value = Traffic();
        await tray.updateTrayTitle();
        _ref.read(runTimeProvider.notifier).value = null;
        addCheckIpNumDebounce();
        return true;
      }
    } catch (_) {
      globalState.updateCoreSwitchStatus(
        CoreSwitchStage.failed,
        message: isStart ? '连接失败' : '断开失败',
      );
      rethrow;
    } finally {
      _isCoreSwitching = false;
      globalState.isCoreSwitchingNotifier.value = false;
      if (globalState.coreSwitchStatusNotifier.value.stage !=
          CoreSwitchStage.failed) {
        globalState.resetCoreSwitchStatus();
      }
    }
  }

  updateRunTime() {
    final startTime = globalState.startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      _ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      _ref.read(runTimeProvider.notifier).value = null;
    }
  }

  updateTraffic() async {
    final traffic = await clashCore.getTraffic();
    _ref.read(trafficsProvider.notifier).addTraffic(traffic);
    await tray.updateTrayTitle(traffic);
    _ref.read(totalTrafficProvider.notifier).value =
        await clashCore.getTotalTraffic();
  }

  addProfile(Profile profile) => _profileController.addProfile(profile);

  deleteProfile(String id) => _profileController.deleteProfile(id);

  updateProviders() async {
    _ref.read(providersProvider.notifier).value =
        await clashCore.getExternalProviders();
  }

  updateLocalIp() async {
    _ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    _ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }

  Future<void> updateProfile(Profile profile) =>
      _profileController.updateProfile(profile);

  setProfile(Profile profile) => _profileController.setProfile(profile);

  setProfileAndAutoApply(Profile profile) =>
      _profileController.setProfileAndAutoApply(profile);

  setProfiles(List<Profile> profiles) =>
      _profileController.setProfiles(profiles);

  addLog(Log log) {
    _ref.read(logsProvider.notifier).addLog(log);
  }

  updateOrAddHotKeyAction(HotKeyAction hotKeyAction) {
    final hotKeyActions = _ref.read(hotKeyActionsProvider);
    final index =
        hotKeyActions.indexWhere((item) => item.action == hotKeyAction.action);
    _ref.read(hotKeyActionsProvider.notifier).value = index == -1
        ? (List.from(hotKeyActions)..add(hotKeyAction))
        : (List.from(hotKeyActions)..[index] = hotKeyAction);
  }

  List<Group> getCurrentGroups() {
    return _ref.read(currentGroupsStateProvider.select((state) => state.value));
  }

  String getRealTestUrl(String? url) {
    return _ref.read(getRealTestUrlProvider(url));
  }

  int getProxiesColumns() {
    return _ref.read(getProxiesColumnsProvider);
  }

  addSortNum() {
    return _ref.read(sortNumProvider.notifier).add();
  }

  getCurrentGroupName() {
    final currentGroupName = _ref.read(currentProfileProvider.select(
      (state) => state?.currentGroupName,
    ));
    return currentGroupName;
  }

  ProxyCardState getProxyCardState(proxyName) {
    return _ref.read(getProxyCardStateProvider(proxyName));
  }

  getSelectedProxyName(groupName) {
    return _ref.read(getSelectedProxyNameProvider(groupName));
  }

  updateCurrentGroupName(String groupName) {
    final profile = _ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) {
      return;
    }
    setProfile(
      profile.copyWith(currentGroupName: groupName),
    );
  }

  Future<void> updateClashConfig() async {
    if (_isCoreSwitching) return;
    _isCoreSwitching = true;
    globalState.isCoreSwitchingNotifier.value = true;
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    try {
      if (commonScaffoldState?.mounted == true) {
        // 原生首页：带 loading 遮罩执行
        await commonScaffoldState?.loadingRun(() async {
          await _updateClashConfig();
        });
      } else {
        // XBoard 路由或其他场景：直接执行，不依赖 homeScaffold
        await _updateClashConfig();
      }
    } finally {
      _isCoreSwitching = false;
      globalState.isCoreSwitchingNotifier.value = false;
    }
  }

  Future<void> _updateClashConfig() async {
    final updateParams = _ref.read(updateParamsProvider);
    final wasStart = _ref.read(runTimeProvider.notifier).isStart;
    final res = await _requestAdmin(updateParams.tun.enable);
    if (res.isError) {
      return;
    }
    final adminResult = res.data!;
    if (adminResult.didRestartCore) {
      await _ref.read(currentProfileProvider)?.checkAndUpdate();
      await _setupClashConfigWithTun(
        _ref.read(patchClashConfigProvider),
        adminResult.enableTun,
      );
      _ref.read(realTunEnableProvider.notifier).value = adminResult.enableTun;
      await updateGroups();
      await updateProviders();
      if (wasStart) {
        globalState.startTime = null;
        await globalState.handleStart();
      }
      return;
    }
    final message = await clashCore.updateConfig(
      updateParams.copyWith.tun(
        enable: adminResult.enableTun,
      ),
    );
    if (message.isNotEmpty) throw message;
    _ref.read(realTunEnableProvider.notifier).value = adminResult.enableTun;
  }

  Future<Result<_TunAdminResult>> _requestAdmin(bool enableTun) async {
    final realTunEnable = _ref.read(realTunEnableProvider);
    var didRestartCore = false;
    if (enableTun != realTunEnable && realTunEnable == false) {
      // 本会话已拒绝过 UAC，不再重复弹出
      if (_tunAdminDenied) {
        enableTun = false;
      } else {
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.checkingHelper,
        );
        final code = await system.authorizeCore();
        switch (code) {
          case AuthorizeCode.success:
            // 验证服务是否真的起来了（Win11 可能批准 UAC 但服务启动失败）
            globalState.updateCoreSwitchStatus(
              CoreSwitchStage.helperReady,
            );
            final isAdminNow = await system.checkIsAdmin();
            if (!isAdminNow) {
              _tunAdminDenied = true;
              enableTun = false;
              break;
            }
            globalState.updateCoreSwitchStatus(
              CoreSwitchStage.coreConnecting,
            );
            await restartCore(setupProfile: false, restoreStart: false);
            didRestartCore = true;
            break;
          case AuthorizeCode.none:
            break;
          case AuthorizeCode.error:
            _tunAdminDenied = true;
            enableTun = false;
            break;
        }
      }
    }
    return Result.success(
      _TunAdminResult(
        enableTun: enableTun,
        didRestartCore: didRestartCore,
      ),
    );
  }

  Future<void> setupClashConfig() async {
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted == true) {
      await commonScaffoldState?.loadingRun(() async {
        await _setupClashConfig();
      });
    } else {
      await _setupClashConfig();
    }
  }

  _setupClashConfig() async {
    await _ref.read(currentProfileProvider)?.checkAndUpdate();
    final patchConfig = _ref.read(patchClashConfigProvider);
    final wasStart = _ref.read(runTimeProvider.notifier).isStart;
    final res = await _requestAdmin(patchConfig.tun.enable);
    if (res.isError) {
      return;
    }
    final adminResult = res.data!;
    await _setupClashConfigWithTun(patchConfig, adminResult.enableTun);
    _ref.read(realTunEnableProvider.notifier).value = adminResult.enableTun;
    if (adminResult.didRestartCore && wasStart) {
      globalState.startTime = null;
      await globalState.handleStart();
    }
  }

  Future<void> _setupClashConfigWithTun(
    ClashConfig patchConfig,
    bool enableTun,
  ) async {
    final realPatchConfig = patchConfig.copyWith.tun(enable: enableTun);
    final params = await globalState.getSetupParams(
      pathConfig: realPatchConfig,
    );
    final message = await clashCore.setupConfig(params);
    lastProfileModified = await _ref.read(
      currentProfileProvider.select(
        (state) => state?.profileLastModified,
      ),
    );
    if (message.isNotEmpty) {
      throw message;
    }
  }

  Future _applyProfile() async {
    if (Platform.isIOS) {
      // iOS: clash core runs in the PacketTunnel extension (separate process).
      // The extension can't access the main app's file paths, so setupConfig
      // and updateGroups via IPC will fail. Always parse YAML in Dart instead.
      await _applyProfileFromYaml();
      return;
    }
    await clashCore.requestGc();
    await _setupClashConfig();
    await Future.wait<void>([updateGroups(), updateProviders()]);
  }

  /// iOS/fallback: parse profile YAML directly in Dart to build Groups.
  /// This runs when VPN is not connected so clash core (in PacketTunnel) is
  /// unavailable. Gives users a node list before connecting.
  ///
  /// Handles both inline `proxies:` and `proxy-providers:` with `use:`.
  Future<void> _applyProfileFromYaml() async {
    try {
      final profile = _ref.read(currentProfileProvider);
      if (profile == null) return;
      final file = await profile.getFile();
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final yamlDoc = loadYaml(content);
      if (yamlDoc is! YamlMap) return;

      // 1. Extract inline proxies
      final proxiesList = yamlDoc['proxies'] as YamlList? ?? YamlList();
      final proxyMap = <String, Proxy>{};
      for (final p in proxiesList) {
        if (p is YamlMap) {
          final name = p['name']?.toString() ?? '';
          final type = p['type']?.toString() ?? '';
          if (name.isNotEmpty) {
            proxyMap[name] = Proxy(name: name, type: type);
          }
        }
      }

      // 2. Load proxy-providers: read cached provider files from disk.
      //    XBoard subscriptions typically use proxy-providers with external
      //    URLs. After first download, mihomo caches provider content to
      //    the path specified in each provider's config.
      final providerProxies = <String, List<Proxy>>{}; // providerName → proxies
      final providers = yamlDoc['proxy-providers'] as YamlMap?;
      if (providers != null) {
        final profileDir = dirname(file.path);
        for (final entry in providers.entries) {
          final providerName = entry.key.toString();
          final providerCfg = entry.value;
          if (providerCfg is! YamlMap) continue;
          final path = providerCfg['path']?.toString();
          if (path == null || path.isEmpty) continue;

          // Provider path is relative to profile directory
          final providerFile = File(
            path.startsWith('/') ? path : join(profileDir, path),
          );
          try {
            if (await providerFile.exists()) {
              final providerContent = await providerFile.readAsString();
              final providerYaml = loadYaml(providerContent);
              // Provider files can be a list of proxies or a map with proxies key
              YamlList? providerProxiesList;
              if (providerYaml is YamlList) {
                providerProxiesList = providerYaml;
              } else if (providerYaml is YamlMap) {
                providerProxiesList = providerYaml['proxies'] as YamlList?;
              }
              if (providerProxiesList != null) {
                final nodes = <Proxy>[];
                for (final p in providerProxiesList) {
                  if (p is YamlMap) {
                    final name = p['name']?.toString() ?? '';
                    final type = p['type']?.toString() ?? '';
                    if (name.isNotEmpty) {
                      final proxy = Proxy(name: name, type: type);
                      nodes.add(proxy);
                      proxyMap[name] = proxy;
                    }
                  }
                }
                providerProxies[providerName] = nodes;
              }
            }
          } catch (_) {
            // Provider file not readable — skip
          }
        }
      }

      // 3. Extract proxy-groups, handling both `proxies:` and `use:` fields
      final groupsList = yamlDoc['proxy-groups'] as YamlList? ?? YamlList();
      final groups = <Group>[];
      for (final g in groupsList) {
        if (g is! YamlMap) continue;
        final name = g['name']?.toString() ?? '';
        final typeStr = g['type']?.toString() ?? '';
        if (name.isEmpty) continue;

        GroupType groupType;
        try {
          groupType = GroupType.parseProfileType(typeStr);
        } catch (_) {
          continue;
        }

        final allProxies = <Proxy>[];

        // Add nodes from `use:` (proxy-providers)
        final useList = g['use'] as YamlList?;
        if (useList != null) {
          for (final providerName in useList) {
            final nodes = providerProxies[providerName.toString()];
            if (nodes != null) {
              allProxies.addAll(nodes);
            }
          }
        }

        // Add nodes from `proxies:` (inline references)
        final proxyNames = (g['proxies'] as YamlList? ?? YamlList())
            .map((e) => e.toString())
            .toList();
        for (final pName in proxyNames) {
          if (proxyMap.containsKey(pName)) {
            allProxies.add(proxyMap[pName]!);
          } else {
            // Could be a group reference or built-in like DIRECT/REJECT
            allProxies.add(Proxy(name: pName, type: 'Unknown'));
          }
        }

        groups.add(Group(
          type: groupType,
          name: name,
          all: allProxies,
          now: allProxies.isNotEmpty ? allProxies.first.name : null,
          icon: g['icon']?.toString() ?? '',
        ));
      }

      // 修正默认 now：优先选择 URLTest/Fallback 计算组（如自动选择、故障转移）
      for (var i = 0; i < groups.length; i++) {
        final group = groups[i];
        if (group.all.isEmpty) continue;
        final nowName = group.now ?? '';
        // 如果当前 now 是 DIRECT/REJECT，或不是计算组引用，尝试切换到第一个计算组
        final isNowComputed = nowName.isNotEmpty &&
            groups.any((g) => g.name == nowName && g.type.isComputedSelected);
        if (!isNowComputed) {
          final computedProxy = group.all.cast<Proxy?>().firstWhere(
            (p) => groups.any(
                (g) => g.name == p!.name && g.type.isComputedSelected),
            orElse: () => null,
          );
          if (computedProxy != null) {
            groups[i] = group.copyWith(now: computedProxy.name);
          }
        }
      }

      final existing = _ref.read(groupsProvider);
      if (groups.isNotEmpty || existing.isEmpty) {
        final corrected = _correctGroupNowValues(groups);
        _ref.read(groupsProvider.notifier).value = corrected;
      }
    } catch (e) {
      commonPrint.log('_applyProfileFromYaml error: $e');
    }
  }

  /// After VPN connects on iOS, mihomo is now running in PacketTunnel.
  /// Fetch live groups from the core and re-apply the user's proxy selections.
  Future<void> _refreshGroupsAfterConnect() async {
    try {
      // 立即尝试一次，未就绪则等待后快速重试
      var newGroups = await clashCore.getProxiesGroups();
      if (newGroups.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 250));
        newGroups = await retry(
          task: () async {
            return await clashCore.getProxiesGroups();
          },
          retryIf: (res) => res.isEmpty,
          maxAttempts: 6,
          delay: const Duration(milliseconds: 300),
        );
      }
      if (newGroups.isNotEmpty) {
        final correctedGroups = _correctGroupNowValues(newGroups);
        _ref.read(groupsProvider.notifier).value = correctedGroups;
        _correctDirectNodes();
      }
      // Re-apply saved proxy selections
      final profile = _ref.read(currentProfileProvider);
      if (profile != null) {
        for (final entry in profile.selectedMap.entries) {
          try {
            await clashCore.changeProxy(
              ChangeProxyParams(
                groupName: entry.key,
                proxyName: entry.value,
              ),
            );
          } catch (_) {}
        }
        // Refresh groups again to get updated "now" values
        final refreshed = await clashCore.getProxiesGroups();
        if (refreshed.isNotEmpty) {
          final correctedRefreshed = _correctGroupNowValues(refreshed);
          _ref.read(groupsProvider.notifier).value = correctedRefreshed;
          _correctDirectNodes();
        }
      }
    } catch (e) {
      commonPrint.log('iOS _refreshGroupsAfterConnect error: $e');
    }
  }

  Future applyProfile({bool silence = false}) async {
    unawaited(XBoardDeviceHeartbeatService.markActive(reason: 'apply_profile'));
    if (silence) {
      await _applyProfile();
    } else {
      final commonScaffoldState = globalState.homeScaffoldKey.currentState;
      if (commonScaffoldState?.mounted == true) {
        await commonScaffoldState?.loadingRun(() async {
          await _applyProfile();
        });
      } else {
        await _applyProfile();
      }
    }
    addCheckIpNumDebounce();
  }

  handleChangeProfile() {
    // 订阅导入流程自己会调用 applyProfile，跳过此处避免并发竞争
    if (isImportApplying) return;
    _ref.read(delayDataSourceProvider.notifier).value = {};
    // On iOS, YAML parsing is fast and doesn't need a loading overlay.
    applyProfile(silence: Platform.isIOS);
    _ref.read(logsProvider.notifier).value = FixedList(500);
    _ref.read(requestsProvider.notifier).value = FixedList(500);
    globalState.cacheHeightMap = {};
    globalState.cacheScrollPosition = {};
  }

  updateBrightness(Brightness brightness) {
    _ref.read(appBrightnessProvider.notifier).value = brightness;
  }

  autoUpdateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(
            profile.autoUpdateDuration,
          )
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString());
      }
    }
  }

  Future<void> updateGroups() async {
    if (Platform.isIOS && !globalState.isStart) {
      // VPN not connected — mihomo not running. Parse YAML locally.
      await _applyProfileFromYaml();
      return;
    }
    try {
      final newGroups = await retry(
        task: () async {
          return await clashCore.getProxiesGroups();
        },
        retryIf: (res) => res.isEmpty,
      );
      final existing = _ref.read(groupsProvider);
      if (newGroups.isEmpty) {
        if (existing.isNotEmpty) return;
        await _applyProfileFromYaml();
        return;
      }
      // 写入前修正 now: 避免 UI 短暂显示 DIRECT
      final correctedGroups = _correctGroupNowValues(newGroups);
      _ref.read(groupsProvider.notifier).value = correctedGroups;
      _correctDirectNodes();
    } catch (e) {
      commonPrint.log('updateGroups error: $e');
      final existing = _ref.read(groupsProvider);
      if (existing.isNotEmpty) return;
      await _applyProfileFromYaml();
    }
  }

  updateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) {
        continue;
      }
      await updateProfile(profile);
    }
  }

  savePreferences() => _exitService.savePreferences();

  changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    unawaited(XBoardDeviceHeartbeatService.markActive(reason: 'change_proxy'));
    await clashCore.changeProxy(
      ChangeProxyParams(
        groupName: groupName,
        proxyName: proxyName,
      ),
    );
    if (_ref.read(appSettingProvider).closeConnections) {
      await clashCore.closeConnections();
    }
    addCheckIpNumDebounce();
  }

  handleBackOrExit() async {
    if (_ref.read(backBlockProvider)) {
      return;
    }
    if (_ref.read(appSettingProvider).minimizeOnExit) {
      if (system.isDesktop) {
        await savePreferencesDebounce();
      }
      await system.back();
    } else {
      await handleExit();
    }
  }

  backBlock() {
    _ref.read(backBlockProvider.notifier).value = true;
  }

  unBackBlock() {
    _ref.read(backBlockProvider.notifier).value = false;
  }

  handleExit() => _exitService.handleExit();

  Future handleClearCacheAndRestart() =>
      _exitService.handleClearCacheAndRestart();

  Future handleClear() => _exitService.handleClear();

  _handlePreference() async {
    if (await preferences.isInit) {
      return;
    }
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      final isExists = await file.exists();
      if (isExists) {
        await file.delete();
      }
    }
    await handleExit();
  }

  Future<void> _initCore({bool setupProfile = true}) async {
    if (!Platform.isIOS) {
      final isInit = await clashCore.isInit;
      if (!isInit) {
        await clashCore.init();
        await clashCore.setState(
          globalState.getCoreState(),
        );
      }
    }
    if (setupProfile) {
      await applyProfile(silence: true);
    }

    // iOS always-on: start the tunnel in idle mode so mihomo is available
    // for IPC (delay tests, proxy queries) before the user taps "connect".
    if (Platform.isIOS) {
      final profileId = globalState.config.currentProfileId;
      if (profileId != null) {
        try {
          final profilePath = await appPath.getProfilePath(profileId);
          final configYaml = await File(profilePath).readAsString();
          await service?.ensureTunnelRunning(configYaml);
        } catch (e) {
          commonPrint.log('iOS ensureTunnelRunning failed: $e');
        }
      }
    }
  }

  init() async {
    FlutterError.onError = (details) {
      commonPrint.log(details.stack.toString());
    };
    updateTray(true);
    await _syncLaunchWindowVisibility();
    await _initCore();
    await _initStatus();
    autoLaunch?.updateStatus(
      _ref.read(appSettingProvider).autoLaunch,
    );
    autoUpdateProfiles();
    if (!_ref.read(appSettingProvider).silentLaunch) {
      window?.show();
    } else {
      window?.hide();
    }
    await _handlePreference();
    await _handlerDisclaimer();
    _ref.read(initProvider.notifier).value = true;
  }

  Future<void> _syncLaunchWindowVisibility() async {
    if (!system.isDesktop) return;
    if (_ref.read(appSettingProvider).silentLaunch) {
      await window?.hide();
      return;
    }
    await window?.show();
  }

  _initStatus() async {
    // 所有平台启动时先尝试从核心恢复真实运行时间，
    // 避免“连接状态已恢复但计时从 0 重新开始”的错位。
    await globalState.updateStartTime();
    final status = globalState.isStart == true
        ? true
        : _ref.read(appSettingProvider).autoRun;

    await updateStatus(status);
    if (!status) {
      addCheckIpNumDebounce();
    }
  }

  setDelay(Delay delay) {
    _ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  toPage(PageLabel pageLabel) {
    _ref.read(currentPageLabelProvider.notifier).value = pageLabel;
  }

  toProfiles() {
    toPage(PageLabel.profiles);
  }

  initLink() {
    linkManager.initAppLinksListen(
      (url) async {
        final res = await globalState.showMessage(
          title: '${appLocalizations.add}${appLocalizations.profile}',
          message: TextSpan(
            children: [
              TextSpan(text: appLocalizations.doYouWantToPass),
              TextSpan(
                text: ' $url ',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              TextSpan(
                  text:
                      '${appLocalizations.create}${appLocalizations.profile}'),
            ],
          ),
        );

        if (res != true) {
          return;
        }
        addProfileFormURL(url);
      },
    );
  }

  Future<bool> showDisclaimer() async {
    return await globalState.showCommonDialog<bool>(
          dismissible: false,
          child: CommonDialog(
            title: appLocalizations.disclaimer,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop<bool>(false);
                },
                child: Text(appLocalizations.exit),
              ),
              TextButton(
                onPressed: () {
                  _ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(disclaimerAccepted: true),
                      );
                  Navigator.of(context).pop<bool>(true);
                },
                child: Text(appLocalizations.agree),
              )
            ],
            child: SelectableText(
              appLocalizations.disclaimerDesc,
            ),
          ),
        ) ??
        false;
  }

  _handlerDisclaimer() async {
    if (_ref.read(appSettingProvider).disclaimerAccepted) {
      return;
    }
    final isDisclaimerAccepted = await showDisclaimer();
    if (!isDisclaimerAccepted) {
      await handleExit();
    }
    return;
  }

  Future<void> importProfileInBackground(String url) =>
      _profileController.importProfileInBackground(url);

  addProfileFormURL(String url) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    toProfiles();
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    final profile = await commonScaffoldState?.loadingRun<Profile>(
      () async {
        return await Profile.normal(
          url: url,
        ).update();
      },
      title: '${appLocalizations.add}${appLocalizations.profile}',
    );
    if (profile != null) {
      await addProfile(profile);
    }
  }

  addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    final bytes = platformFile?.bytes;
    if (bytes == null) {
      return null;
    }
    if (!context.mounted) return;
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    toProfiles();
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    final profile = await commonScaffoldState?.loadingRun<Profile?>(
      () async {
        await Future.delayed(const Duration(milliseconds: 300));
        return await Profile.normal(label: platformFile?.name).saveFile(bytes);
      },
      title: '${appLocalizations.add}${appLocalizations.profile}',
    );
    if (profile != null) {
      await addProfile(profile);
    }
  }

  addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  updateViewSize(Size size) {
    _ref.read(viewSizeProvider.notifier).value = size;
  }

  setProvider(ExternalProvider? provider) {
    _ref.read(providersProvider.notifier).setProvider(provider);
  }

  List<Proxy> _sortOfName(List<Proxy> proxies) {
    return List.of(proxies)
      ..sort(
        (a, b) => utils.sortByChar(
          utils.getPinyin(a.name),
          utils.getPinyin(b.name),
        ),
      );
  }

  List<Proxy> _sortOfDelay({
    required List<Proxy> proxies,
    String? testUrl,
  }) {
    return List.of(proxies)
      ..sort(
        (a, b) {
          final aDelay = _ref.read(getDelayProvider(
            proxyName: a.name,
            testUrl: testUrl,
          ));
          final bDelay = _ref.read(
            getDelayProvider(
              proxyName: b.name,
              testUrl: testUrl,
            ),
          );
          if (aDelay == null && bDelay == null) {
            return 0;
          }
          if (aDelay == null || aDelay == -1) {
            return 1;
          }
          if (bDelay == null || bDelay == -1) {
            return -1;
          }
          return aDelay.compareTo(bDelay);
        },
      );
  }

  List<Proxy> getSortProxies(List<Proxy> proxies, [String? url]) {
    final sortedProxies =
        switch (_ref.read(proxiesStyleSettingProvider).sortType) {
      ProxiesSortType.none => proxies,
      ProxiesSortType.delay => _sortOfDelay(
          proxies: proxies,
          testUrl: url,
        ),
      ProxiesSortType.name => _sortOfName(proxies),
    };
    final groups = _ref.read(groupsProvider);
    final computedProxies = sortedProxies.where((proxy) {
      final group = groups.getGroup(proxy.name);
      final type = GroupTypeExtension.getGroupType(proxy.type);
      return group?.type.isComputedSelected == true ||
          type?.isComputedSelected == true;
    }).toList();
    final nodeProxies = sortedProxies.where((proxy) {
      final group = groups.getGroup(proxy.name);
      final type = GroupTypeExtension.getGroupType(proxy.type);
      return group?.type.isComputedSelected != true &&
          type?.isComputedSelected != true;
    }).toList();
    return [...computedProxies, ...nodeProxies];
  }

  clearEffect(String profileId) => _profileController.clearEffect(profileId);

  updateTun() {
    unawaited(XBoardDeviceHeartbeatService.markActive(reason: 'toggle_tun'));
    _ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith.tun(enable: !state.tun.enable),
        );
  }

  updateSystemProxy() {
    unawaited(
      XBoardDeviceHeartbeatService.markActive(reason: 'toggle_system_proxy'),
    );
    _ref.read(networkSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            systemProxy: !state.systemProxy,
          ),
        );
  }

  Future<List<Package>> getPackages() async {
    if (_ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (_ref.read(packagesProvider).isEmpty) {
      _ref.read(packagesProvider.notifier).value =
          await app?.getPackages() ?? [];
    }
    return _ref.read(packagesProvider);
  }

  updateStart() {
    updateStatus(!_ref.read(runTimeProvider.notifier).isStart);
  }

  updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final SelectedMap selectedMap = Map.from(
        currentProfile.selectedMap,
      )..[groupName] = proxyName;
      _ref.read(profilesProvider.notifier).setProfile(
            currentProfile.copyWith(
              selectedMap: selectedMap,
            ),
          );
    }
  }

  updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      return;
    }
    _ref.read(profilesProvider.notifier).setProfile(
          currentProfile.copyWith(
            unfoldSet: value,
          ),
        );
  }

  changeMode(Mode mode) {
    unawaited(XBoardDeviceHeartbeatService.markActive(reason: 'change_mode'));
    _ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(mode: mode),
        );
    if (mode == Mode.global) {
      updateCurrentGroupName(GroupName.GLOBAL.name);
      // 同步修正 GLOBAL 默认节点，避免 UI 先显示错误节点再跳回自动选择。
      _correctGlobalDefaultNode();
    }
    addCheckIpNumDebounce();
  }

  /// 切换到全局模式时，如果 GLOBAL 组的当前选中是 DIRECT（已被隐藏），
  /// 自动切换到第一个有效代理（通常是 URLTest 自动选择组）。
  void _correctGlobalDefaultNode() {
    // 读取已排序/修正的显示用分组（URLTest/自动选择排在前面），
    // 而非原始 Clash 分组（其中线路节点可能排在 URLTest 之前）。
    final displayGroups = _ref.read(currentGroupsStateProvider).value;
    final globalGroup = displayGroups.getGroup(GroupName.GLOBAL.name);
    if (globalGroup == null || globalGroup.all.isEmpty) return;
    final correctedNow = globalGroup.now ?? '';
    if (correctedNow.isEmpty) return;
    // 检查原始 Clash 数据中 GLOBAL 的 now 是否已是修正后的值
    final rawGroups = _ref.read(groupsProvider);
    final rawGlobal = rawGroups.getGroup(GroupName.GLOBAL.name);
    if (rawGlobal == null) return;
    if (rawGlobal.now == correctedNow) return;
    // 将修正后的选择（优先 URLTest 自动选择）同步到 Clash
    changeProxyDebounce(GroupName.GLOBAL.name, correctedNow);
    updateCurrentSelectedMap(GroupName.GLOBAL.name, correctedNow);
  }

  /// 在写入 groupsProvider 之前修正所有分组的 now 值，
  /// 将 DIRECT/REJECT 替换为第一个有效代理，优先 URLTest/Fallback 计算组。
  List<Group> _correctGroupNowValues(List<Group> groups) {
    return groups.map((group) {
      final nowValue = group.now ?? '';
      if (nowValue.isEmpty) return group;
      if (nowValue == UsedProxy.DIRECT.name ||
          nowValue == UsedProxy.REJECT.name) {
        final validProxies = group.all
            .where((p) =>
                p.name != UsedProxy.DIRECT.name &&
                p.name != UsedProxy.REJECT.name)
            .toList();
        if (validProxies.isEmpty) return group;
        // 优先选择 URLTest/Fallback 计算组（如自动选择、故障转移）
        final computedProxy = validProxies.cast<Proxy?>().firstWhere(
          (p) =>
              groups.any((g) => g.name == p!.name && g.type.isComputedSelected),
          orElse: () => null,
        );
        return group.copyWith(now: (computedProxy ?? validProxies.first).name);
      }
      return group;
    }).toList();
  }

  /// 修正所有可见分组中 now=DIRECT/REJECT 的情况。
  /// 注意：GLOBAL 组由 _correctGlobalDefaultNode 单独处理，
  /// 以使用排序后的代理列表（URLTest 优先）。
  void _correctDirectNodes() {
    final groups = _ref.read(groupsProvider);
    for (final group in groups) {
      if (group.hidden == true) continue;
      if (group.name == GroupName.GLOBAL.name) continue;
      final nowValue = group.now ?? '';
      if (nowValue.isEmpty) continue;
      if (nowValue == UsedProxy.DIRECT.name ||
          nowValue == UsedProxy.REJECT.name) {
        final validProxies = group.all
            .where((p) =>
                p.name != UsedProxy.DIRECT.name &&
                p.name != UsedProxy.REJECT.name)
            .toList();
        if (validProxies.isEmpty) continue;
        // 优先选择 URLTest/Fallback 计算组（如自动选择、故障转移）
        final computedProxy = validProxies.cast<Proxy?>().firstWhere(
          (p) =>
              groups.any((g) => g.name == p!.name && g.type.isComputedSelected),
          orElse: () => null,
        );
        final proxyName = (computedProxy ?? validProxies.first).name;
        changeProxyDebounce(group.name, proxyName);
        updateCurrentSelectedMap(group.name, proxyName);
      }
    }
  }

  updateAutoLaunch() {
    _ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            autoLaunch: !state.autoLaunch,
          ),
        );
  }

  updateVisible() async {
    final visible = await window?.isVisible;
    if (visible != null && !visible) {
      window?.show();
    } else {
      window?.hide();
    }
  }

  updateMode() {
    _ref.read(patchClashConfigProvider.notifier).updateState(
      (state) {
        final index = Mode.values.indexWhere((item) => item == state.mode);
        if (index == -1) {
          return null;
        }
        final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
        return state.copyWith(
          mode: Mode.values[nextIndex],
        );
      },
    );
  }

  handleAddOrUpdate(WidgetRef ref, [Rule? rule]) async {
    final res = await globalState.showCommonDialog<Rule>(
      child: AddRuleDialog(
        rule: rule,
        snippet: ref.read(
          profileOverrideStateProvider.select(
            (state) => state.snippet!,
          ),
        ),
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        final model = state.copyWith.overrideData!(
          rule: state.overrideData!.rule.updateRules(
            (rules) {
              final index = rules.indexWhere((item) => item.id == res.id);
              if (index == -1) {
                return List.from([res, ...rules]);
              }
              return List.from(rules)..[index] = res;
            },
          ),
        );
        return model;
      },
    );
  }

  Future<bool> exportLogs() async {
    final logsRaw = _ref.read(logsProvider).list.map(
          (item) => SensitiveMasker.maskText(item),
        );
    final data = await Isolate.run<List<int>>(() async {
      final logsRawString = logsRaw.join('\n');
      return utf8.encode(logsRawString);
    });
    return await picker.saveFile(
          utils.logFile,
          Uint8List.fromList(data),
        ) !=
        null;
  }

  Future<List<int>> backupData() => _backupService.backupData();

  updateTray([bool focus = false]) async {
    tray.update(
      trayState: _ref.read(trayStateProvider),
    );
  }

  recoveryData(
    List<int> data,
    RecoveryOption recoveryOption,
  ) =>
      _backupService.recoveryData(data, recoveryOption);
}
