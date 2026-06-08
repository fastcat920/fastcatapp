import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/archive.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';

import 'common/common.dart';
import 'models/models.dart';
import 'views/profiles/override_profile.dart';

class AppController {
  int? lastProfileModified;

  /// 默认 true：启动时不自动弹 UAC，只有用户在设置中手动开启 TUN 时
  /// 通过 resetTunAdminDenied() 重置为 false，才允许弹 UAC 提权。
  /// 解决非管理员运行时反复弹 UAC 的问题。
  bool _tunAdminDenied = true;

  /// 订阅导入流程正在执行 applyProfile 时为 true，
  /// 防止 ClashManager 的 needSetupProvider 监听器重复触发 handleChangeProfile，
  /// 避免两个并发 applyProfile 竞争导致 groups 被清空。
  bool isImportApplying = false;

  /// 用户在设置中主动开启 TUN 时调用，允许再次弹出 UAC
  void resetTunAdminDenied() => _tunAdminDenied = false;

  final BuildContext context;
  final WidgetRef _ref;

  AppController(this.context, WidgetRef ref) : _ref = ref;

  setupClashConfigDebounce() {
    debouncer.call(FunctionTag.setupClashConfig, () async {
      await setupClashConfig();
    });
  }

  updateClashConfigDebounce() {
    debouncer.call(FunctionTag.updateClashConfig, () async {
      await updateClashConfig();
    });
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

  restartCore() async {
    commonPrint.log("restart core");
    await clashService?.reStart();
    await _initCore();
    if (_ref.read(runTimeProvider.notifier).isStart) {
      globalState.startTime = null; // 重启后计时归零
      await globalState.handleStart();
    }
  }

  updateStatus(bool isStart) async {
    if (isStart) {
      await globalState.handleStart([
        updateRunTime,
        updateTraffic,
      ]);
      // handleStart resets startTime to null on VPN failure — bail out
      if (globalState.startTime == null) return;
      if (Platform.isIOS) {
        // Traffic routing just enabled — mihomo was already running in idle mode.
        // Refresh groups from the core and re-apply the user's selected proxy.
        await _refreshGroupsAfterConnect();
        addCheckIpNumDebounce();
        return;
      }
      final currentLastModified =
          await _ref.read(currentProfileProvider)?.profileLastModified;
      if (currentLastModified == null || lastProfileModified == null) {
        addCheckIpNumDebounce();
        return;
      }
      if (currentLastModified <= (lastProfileModified ?? 0)) {
        addCheckIpNumDebounce();
        return;
      }
      applyProfileDebounce();
    } else {
      await globalState.handleStop();
      await clashCore.resetTraffic();
      _ref.read(trafficsProvider.notifier).clear();
      _ref.read(totalTrafficProvider.notifier).value = Traffic();
      await tray.updateTrayTitle();
      _ref.read(runTimeProvider.notifier).value = null;
      addCheckIpNumDebounce();
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

  addProfile(Profile profile) async {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (_ref.read(currentProfileIdProvider) != null) return;
    _ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  deleteProfile(String id) async {
    _ref.read(profilesProvider.notifier).deleteProfileById(id);
    clearEffect(id);
    if (globalState.config.currentProfileId == id) {
      final profiles = globalState.config.profiles;
      final currentProfileId = _ref.read(currentProfileIdProvider.notifier);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        currentProfileId.value = updateId;
      } else {
        currentProfileId.value = null;
        updateStatus(false);
      }
    }
  }

  updateProviders() async {
    _ref.read(providersProvider.notifier).value =
        await clashCore.getExternalProviders();
  }

  updateLocalIp() async {
    _ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    _ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }

  Future<void> updateProfile(Profile profile) async {
    final newProfile = await profile.update();
    _ref
        .read(profilesProvider.notifier)
        .setProfile(newProfile.copyWith(isUpdating: false));
    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
    }
  }

  setProfile(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
  }

  setProfileAndAutoApply(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
    }
  }

  setProfiles(List<Profile> profiles) {
    _ref.read(profilesProvider.notifier).value = profiles;
  }

  addLog(Log log) {
    _ref.read(logsProvider.notifier).addLog(log);
  }

  updateOrAddHotKeyAction(HotKeyAction hotKeyAction) {
    final hotKeyActions = _ref.read(hotKeyActionsProvider);
    final index =
        hotKeyActions.indexWhere((item) => item.action == hotKeyAction.action);
    if (index == -1) {
      _ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..add(hotKeyAction);
    } else {
      _ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..[index] = hotKeyAction;
    }

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
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted == true) {
      // 原生首页：带 loading 遮罩执行
      await commonScaffoldState?.loadingRun(() async {
        await _updateClashConfig();
      });
    } else {
      // XBoard 路由或其他场景：直接执行，不依赖 homeScaffold
      await _updateClashConfig();
    }
  }

  Future<void> _updateClashConfig() async {
    final updateParams = _ref.read(updateParamsProvider);
    final res = await _requestAdmin(updateParams.tun.enable);
    if (res.isError) {
      return;
    }
    final realTunEnable = _ref.read(realTunEnableProvider);
    final message = await clashCore.updateConfig(
      updateParams.copyWith.tun(
        enable: realTunEnable,
      ),
    );
    if (message.isNotEmpty) throw message;
  }

  Future<Result<bool>> _requestAdmin(bool enableTun) async {
    final realTunEnable = _ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      // 本会话已拒绝过 UAC，不再重复弹出
      if (_tunAdminDenied) {
        enableTun = false;
      } else {
        final code = await system.authorizeCore();
        switch (code) {
          case AuthorizeCode.success:
            await restartCore();
            // 验证服务是否真的起来了（Win11 可能批准 UAC 但服务启动失败）
            final isAdminNow = await system.checkIsAdmin();
            if (!isAdminNow) {
              _tunAdminDenied = true;
              enableTun = false;
              break;
            }
            return Result.error("");
          case AuthorizeCode.none:
            break;
          case AuthorizeCode.error:
            _tunAdminDenied = true;
            enableTun = false;
            break;
        }
      }
    }
    _ref.read(realTunEnableProvider.notifier).value = enableTun;
    return Result.success(enableTun);
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
    final res = await _requestAdmin(patchConfig.tun.enable);
    if (res.isError) {
      return;
    }
    final realTunEnable = _ref.read(realTunEnableProvider);
    final realPatchConfig = patchConfig.copyWith.tun(enable: realTunEnable);
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
    await updateGroups();
    await updateProviders();
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

      _ref.read(groupsProvider.notifier).value = groups;
    } catch (e) {
      commonPrint.log("_applyProfileFromYaml error: $e");
      // Don't wipe existing groups on parse error
      if (_ref.read(groupsProvider).isEmpty) {
        _ref.read(groupsProvider.notifier).value = [];
      }
    }
  }

  /// After VPN connects on iOS, mihomo is now running in PacketTunnel.
  /// Fetch live groups from the core and re-apply the user's proxy selections.
  Future<void> _refreshGroupsAfterConnect() async {
    // Wait briefly for mihomo to fully initialize inside the extension
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final newGroups = await retry(
        task: () async {
          return await clashCore.getProxiesGroups();
        },
        retryIf: (res) => res.isEmpty,
        maxAttempts: 5,
        delay: const Duration(seconds: 1),
      );
      if (newGroups.isNotEmpty) {
        _ref.read(groupsProvider.notifier).value = newGroups;
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
          _ref.read(groupsProvider.notifier).value = refreshed;
        }
      }
    } catch (e) {
      commonPrint.log("iOS _refreshGroupsAfterConnect error: $e");
    }
  }

  Future applyProfile({bool silence = false}) async {
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
      // On iOS, don't overwrite existing groups with empty IPC result.
      // Keep YAML-parsed groups as fallback if mihomo IPC fails.
      if (Platform.isIOS && newGroups.isEmpty) {
        final existing = _ref.read(groupsProvider);
        if (existing.isNotEmpty) return;
      }
      _ref.read(groupsProvider.notifier).value = newGroups;
    } catch (_) {
      // On iOS, preserve existing groups on error
      if (Platform.isIOS) {
        final existing = _ref.read(groupsProvider);
        if (existing.isNotEmpty) return;
      }
      _ref.read(groupsProvider.notifier).value = [];
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

  savePreferences() async {
    commonPrint.log("save preferences");
    await preferences.saveConfig(globalState.config);
  }

  changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
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

  handleExit() async {
    Future.delayed(commonDuration, () {
      system.exit();
    });
    try {
      await savePreferences();
      await system.setMacOSDns(true);
      await proxy?.stopProxy();
      await clashCore.shutdown();
      await clashService?.destroy();
    } finally {
      system.exit();
    }
  }

  Future handleClear() async {
    await preferences.clearPreferences();
    commonPrint.log("clear preferences");
    globalState.config = Config(
      themeProps: defaultThemeProps,
    );
  }

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

  Future<void> _initCore() async {
    if (!Platform.isIOS) {
      final isInit = await clashCore.isInit;
      if (!isInit) {
        await clashCore.init();
        await clashCore.setState(
          globalState.getCoreState(),
        );
      }
    }
    await applyProfile(silence: true);

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
          commonPrint.log("iOS ensureTunnelRunning failed: $e");
        }
      }
    }
  }

  init() async {
    FlutterError.onError = (details) {
      commonPrint.log(details.stack.toString());
    };
    updateTray(true);
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
          title: "${appLocalizations.add}${appLocalizations.profile}",
          message: TextSpan(
            children: [
              TextSpan(text: appLocalizations.doYouWantToPass),
              TextSpan(
                text: " $url ",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              TextSpan(
                  text:
                      "${appLocalizations.create}${appLocalizations.profile}"),
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

  Future<void> importProfileInBackground(String url) async {
    try {
      // 先删除所有现有的URL订阅（非文件类型的订阅）
      final profiles = globalState.config.profiles;
      final urlProfiles =
          profiles.where((profile) => profile.type == ProfileType.url).toList();

      for (final profile in urlProfiles) {
        commonPrint.log(
            'Removing existing URL profile: ${profile.label ?? profile.id}');
        deleteProfile(profile.id);
      }

      // 然后添加新的订阅
      final profile = await Profile.normal(
        url: url,
      ).update();
      await addProfile(profile);
      app?.tip("${appLocalizations.add} ${appLocalizations.profile}");
    } catch (e) {
      commonPrint.log('Failed to import profile in background: $e');
      app?.tip(appLocalizations.checkError);
    }
  }

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
      title: "${appLocalizations.add}${appLocalizations.profile}",
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
      title: "${appLocalizations.add}${appLocalizations.profile}",
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
    return switch (_ref.read(proxiesStyleSettingProvider).sortType) {
      ProxiesSortType.none => proxies,
      ProxiesSortType.delay => _sortOfDelay(
          proxies: proxies,
          testUrl: url,
        ),
      ProxiesSortType.name => _sortOfName(proxies),
      _ => throw UnimplementedError(),
    };
  }

  clearEffect(String profileId) async {
    final profilePath = await appPath.getProfilePath(profileId);
    final providersDirPath = await appPath.getProvidersDirPath(profileId);
    return await Isolate.run(() async {
      final profileFile = File(profilePath);
      final isExists = await profileFile.exists();
      if (isExists) {
        profileFile.delete(recursive: true);
      }
      final providersFileDir = File(providersDirPath);
      final providersFileIsExists = await providersFileDir.exists();
      if (providersFileIsExists) {
        providersFileDir.delete(recursive: true);
      }
    });
  }

  updateTun() {
    _ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith.tun(enable: !state.tun.enable),
        );
  }

  updateSystemProxy() {
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
    _ref.read(patchClashConfigProvider.notifier).updateState(
          (state) => state.copyWith(mode: mode),
        );
    if (mode == Mode.global) {
      updateCurrentGroupName(GroupName.GLOBAL.name);
    }
    addCheckIpNumDebounce();
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
          (item) => item.toString(),
        );
    final data = await Isolate.run<List<int>>(() async {
      final logsRawString = logsRaw.join("\n");
      return utf8.encode(logsRawString);
    });
    return await picker.saveFile(
          utils.logFile,
          Uint8List.fromList(data),
        ) !=
        null;
  }

  Future<List<int>> backupData() async {
    final homeDirPath = await appPath.homeDirPath;
    final profilesPath = await appPath.profilesPath;
    final configJson = globalState.config.toJson();
    return Isolate.run<List<int>>(() async {
      final archive = Archive();
      archive.add("config.json", configJson);
      await archive.addDirectoryToArchive(profilesPath, homeDirPath);
      final zipEncoder = ZipEncoder();
      return zipEncoder.encode(archive) ?? [];
    });
  }

  updateTray([bool focus = false]) async {
    tray.update(
      trayState: _ref.read(trayStateProvider),
    );
  }

  recoveryData(
    List<int> data,
    RecoveryOption recoveryOption,
  ) async {
    final archive = await Isolate.run<Archive>(() {
      final zipDecoder = ZipDecoder();
      return zipDecoder.decodeBytes(data);
    });
    final homeDirPath = await appPath.homeDirPath;
    final configs =
        archive.files.where((item) => item.name.endsWith(".json")).toList();
    final profiles =
        archive.files.where((item) => !item.name.endsWith(".json"));
    final configIndex =
        configs.indexWhere((config) => config.name == "config.json");
    if (configIndex == -1) throw "invalid backup file";
    final configFile = configs[configIndex];
    var tempConfig = Config.compatibleFromJson(
      json.decode(
        utf8.decode(configFile.content),
      ),
    );
    for (final profile in profiles) {
      final filePath = join(homeDirPath, profile.name);
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(profile.content);
    }
    final clashConfigIndex =
        configs.indexWhere((config) => config.name == "clashConfig.json");
    if (clashConfigIndex != -1) {
      final clashConfigFile = configs[clashConfigIndex];
      tempConfig = tempConfig.copyWith(
        patchClashConfig: ClashConfig.fromJson(
          json.decode(
            utf8.decode(
              clashConfigFile.content,
            ),
          ),
        ),
      );
    }
    _recovery(
      tempConfig,
      recoveryOption,
    );
  }

  _recovery(Config config, RecoveryOption recoveryOption) {
    final recoveryStrategy = _ref.read(appSettingProvider.select(
      (state) => state.recoveryStrategy,
    ));
    final profiles = config.profiles;
    if (recoveryStrategy == RecoveryStrategy.override) {
      _ref.read(profilesProvider.notifier).value = profiles;
    } else {
      for (final profile in profiles) {
        _ref.read(profilesProvider.notifier).setProfile(
              profile,
            );
      }
    }
    final onlyProfiles = recoveryOption == RecoveryOption.onlyProfiles;
    if (!onlyProfiles) {
      _ref.read(patchClashConfigProvider.notifier).value =
          config.patchClashConfig;
      _ref.read(appSettingProvider.notifier).value = config.appSetting;
      _ref.read(currentProfileIdProvider.notifier).value =
          config.currentProfileId;
      _ref.read(appDAVSettingProvider.notifier).value = config.dav;
      _ref.read(themeSettingProvider.notifier).value = config.themeProps;
      _ref.read(windowSettingProvider.notifier).value = config.windowProps;
      _ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
      _ref.read(proxiesStyleSettingProvider.notifier).value =
          config.proxiesStyle;
      _ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
      _ref.read(networkSettingProvider.notifier).value = config.networkProps;
      _ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
      _ref.read(scriptStateProvider.notifier).value = config.scriptProps;
    }
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      _ref.read(currentProfileIdProvider.notifier).value = profiles.first.id;
    }
  }
}
