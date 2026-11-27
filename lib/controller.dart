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
import 'package:fl_clash/services/app_exit_service.dart';
import 'package:fl_clash/services/desktop_proxy_routing.dart';
import 'package:fl_clash/services/app_profile_controller.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/services/proxy_selection_sync.dart';
import 'package:fl_clash/services/verified_connection_start.dart';
import 'package:fl_clash/services/live_core_groups.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/xboard/features/auth/services/device_heartbeat_service.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/common.dart';
import 'common/boot_diag.dart';
import 'common/diagnostic_log_buffer.dart';
import 'common/serial_operation_queue.dart';
import 'security/profile_vault.dart';
import 'models/models.dart';

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
  bool _isConfigurationSwitching = false;
  bool _isConnectionRepair = false;
  Future<void>? _configUpdateFuture;
  Future<void>? _disconnectCleanupFuture;
  final _profileApplications = SerialOperationQueue();
  String? _lastConnectivityFingerprint;
  Timer? _networkRecoveryTimer;
  DateTime? _lastNetworkRecoveryAt;
  bool _isRecoveringFromNetworkChange = false;
  bool _isExitDialogVisible = false;
  bool _isExiting = false;

  bool get isCoreSwitching => _isCoreSwitching;
  bool get isConfigurationSwitching => _isConfigurationSwitching;

  Future<T> runConnectionRepair<T>(Future<T> Function() repair) async {
    if (_isCoreSwitching) {
      throw StateError('Core operation already in progress');
    }
    _isCoreSwitching = true;
    _isConnectionRepair = true;
    globalState.isCoreSwitchingNotifier.value = true;
    try {
      return await repair();
    } finally {
      _isConnectionRepair = false;
      _isConfigurationSwitching = false;
      _isCoreSwitching = false;
      globalState.isCoreSwitchingNotifier.value = false;
      globalState.resetCoreSwitchStatus();
    }
  }

  late final _proxySelection = ProxySelectionSync(
    readGroups: () async => await clashCore.getProxiesGroups(),
    writeSelection: (group, node) async => await clashCore.changeProxy(
      ChangeProxyParams(groupName: group, proxyName: node),
    ),
    publishGroups: (groups) =>
        _ref.read(groupsProvider.notifier).value = groups,
  );

  Future<void> synchronizeProxySelection() async {
    final mode = _ref.read(patchClashConfigProvider).mode;
    if (mode == Mode.direct) return;
    final groups = getCurrentGroups();
    await _proxySelection.synchronize(
      saved: Map<String, String>.from(
          _ref.read(currentProfileProvider)?.selectedMap ?? {}),
      activeGroup: mode == Mode.global ? 'GLOBAL' : groups.firstOrNull?.name,
    );
  }

  /// 订阅导入流程正在执行 applyProfile 时为 true，
  /// 防止 ClashManager 的 needSetupProvider 监听器重复触发 handleChangeProfile，
  /// 避免两个并发 applyProfile 竞争导致 groups 被清空。
  bool isImportApplying = false;

  /// Keep profile publication and rollback in the same connection-operation
  /// lock. Restoring an ID must not trigger a competing listener application.
  Future<T> runProfileImport<T>(Future<T> Function() operation) async {
    await _acquireConfigurationSwitch();
    isImportApplying = true;
    try {
      return await operation();
    } finally {
      isImportApplying = false;
      _isConfigurationSwitching = false;
      _isCoreSwitching = false;
      globalState.isCoreSwitchingNotifier.value = false;
      globalState.resetCoreSwitchStatus();
    }
  }

  Future<void> restoreProfileConnection() async {
    // A quick reconnect must finish the previous Android listener stop first.
    await _disconnectCleanupFuture;
    await _restoreVerifiedConnection();
  }

  Future<void> stopAfterConfigurationFailure() => _rollbackFailedStart();

  /// Session exit must not ignore a busy connect/apply/repair operation. The
  /// caller first drains subscription imports, then waits here for any other
  /// connection operation before clearing account identity.
  Future<void> disconnectAfterPendingOperations() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (_isCoreSwitching) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Connection operation is still in progress');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // No await between observing idle and updateStatus acquiring the lock.
    if (!await updateStatus(false)) {
      throw StateError('Session connection could not be stopped');
    }
  }

  /// 用户在设置中主动开启 TUN 时调用，允许再次弹出 UAC
  void resetTunAdminDenied() => _tunAdminDenied = false;

  final BuildContext context;
  final WidgetRef _ref;
  late final AppExitService _exitService;
  late final AppProfileController _profileController;

  AppController(this.context, WidgetRef ref, {bool observeDesktopCore = true})
      : _ref = ref {
    if (observeDesktopCore && system.isDesktop) {
      clashService?.unexpectedDisconnects.listen((_) {
        unawaited(_handleDesktopCoreDisconnected());
      });
    }
    _exitService = const AppExitService();
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
      unawaited(_updateConfigurationFromSettings());
      return;
    }
    debouncer.call(FunctionTag.updateClashConfig, () async {
      await _updateConfigurationFromSettings();
    }, duration: duration);
  }

  Future<void> _updateConfigurationFromSettings() async {
    try {
      await updateClashConfig();
    } catch (error) {
      commonPrint.log('[Configuration] update failed: $error');
      XBoardNotification.showError(appLocalizations.xboardConfigurationError);
    }
  }

  updateGroupsDebounce() {
    debouncer.call(FunctionTag.updateGroups, updateGroups);
  }

  addCheckIpNumDebounce() {
    debouncer.call(FunctionTag.addCheckIpNum, () {
      _ref.read(checkIpNumProvider.notifier).add();
    });
  }

  /// Handles an actual physical-network transition reported by
  /// connectivity_plus. The first value is only a baseline; it must not break
  /// active sessions during app startup. Later changes are coalesced because
  /// Wi-Fi/mobile handoffs commonly emit several transient values.
  void handleConnectivityChanged(
    List<ConnectivityResult> results, {
    bool networkIdentityChanged = false,
  }) {
    final fingerprint =
        (results.map((result) => result.name).toList()..sort()).join(',');
    final previous = _lastConnectivityFingerprint;
    _lastConnectivityFingerprint = fingerprint;

    updateLocalIp();
    addCheckIpNumDebounce();

    if (previous == null ||
        (previous == fingerprint && !networkIdentityChanged)) {
      return;
    }
    if (results.contains(ConnectivityResult.vpn) ||
        globalState.isCoreSwitchingNotifier.value ||
        globalState.shouldSuppressConnectionCleanup) {
      return;
    }

    // Remove old RTT badges at once; the actual core cleanup below is debounced
    // to let a Wi-Fi/mobile handoff finish settling first.
    _ref.read(delayDataSourceProvider.notifier).value = {};
    _networkRecoveryTimer?.cancel();
    _networkRecoveryTimer = Timer(
      const Duration(milliseconds: 1500),
      () => unawaited(_recoverFromNetworkChange()),
    );
  }

  Future<void> _recoverFromNetworkChange() async {
    if (_isRecoveringFromNetworkChange ||
        globalState.shouldSuppressConnectionCleanup) {
      return;
    }
    final lastRecoveryAt = _lastNetworkRecoveryAt;
    if (lastRecoveryAt != null &&
        DateTime.now().difference(lastRecoveryAt) <
            const Duration(seconds: 8)) {
      _networkRecoveryTimer?.cancel();
      _networkRecoveryTimer = Timer(
        const Duration(seconds: 8) - DateTime.now().difference(lastRecoveryAt),
        () => unawaited(_recoverFromNetworkChange()),
      );
      return;
    }

    _isRecoveringFromNetworkChange = true;
    _lastNetworkRecoveryAt = DateTime.now();
    try {
      if (globalState.isStart) {
        await clashCore.closeConnections();
        await clashCore.clearNetworkCaches();
      }
    } catch (error) {
      commonPrint.log('network cache recovery failed: $error');
    } finally {
      _isRecoveringFromNetworkChange = false;
    }

    await updateLocalIp();
    addCheckIpNumDebounce();
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
      try {
        if (Platform.isIOS) {
          // iOS: selection already saved locally by updateCurrentSelectedMap().
          // If VPN is connected, tell mihomo to switch proxy but do NOT call
          // updateGroups() — IPC getProxies can return empty and wipe the list.
          if (globalState.isStart) {
            await changeProxy(
              groupName: groupName,
              proxyName: proxyName,
            );
          }
          return;
        }
        await changeProxy(
          groupName: groupName,
          proxyName: proxyName,
        );
        await updateGroups();
      } catch (error) {
        commonPrint.log('[ProxySelection] failed: $error');
        XBoardNotification.showError(
            appLocalizations.xboardProxySelectionFailed);
      }
    }, args: [groupName, proxyName]);
  }

  restartCore({
    bool setupProfile = true,
    bool restoreStart = true,
    bool requireHelper = false,
  }) async {
    commonPrint.log('restart core');
    final wasStart = _ref.read(runTimeProvider.notifier).isStart;
    try {
      await clashService?.reStart(requireHelper: requireHelper);
      await _initCore(setupProfile: setupProfile);
    } catch (_) {
      if (system.isDesktop) {
        await clashService?.shutdown();
        _markDesktopCoreStopped();
      }
      rethrow;
    }
    if (restoreStart && wasStart) {
      globalState.startTime = null; // 重启后计时归零
      await _restoreVerifiedConnection();
    }
  }

  Future<void> handleDesktopProxyFailure() async {
    if (!system.isDesktop ||
        !_ref.read(networkSettingProvider).systemProxy ||
        _ref.read(realTunEnableProvider)) {
      return;
    }
    await _handleDesktopCoreDisconnected();
  }

  Future<void> _handleDesktopCoreDisconnected() async {
    if (!globalState.isStart) return;
    // Publish before awaiting cleanup so a new click cannot retain a fake state.
    _markDesktopCoreStopped(suppressAuthorization: false);
    globalState.updateCoreSwitchStatus(CoreSwitchStage.failed);
    final cleanup = () async {
      try {
        if (await proxy?.stopProxy() == false) {
          commonPrint.log('[CoreDisconnect] system proxy restore failed');
        }
        await system.setMacOSDns(true);
        await clashService?.shutdown();
      } catch (error) {
        commonPrint.log('[CoreDisconnect] system proxy cleanup failed: $error');
      }
    }();
    _disconnectCleanupFuture = cleanup;
    try {
      await cleanup;
    } finally {
      if (identical(_disconnectCleanupFuture, cleanup)) {
        _disconnectCleanupFuture = null;
      }
    }
  }

  void _markDesktopCoreStopped({bool suppressAuthorization = true}) {
    globalState.startTime = null;
    globalState.stopUpdateTasks();
    _ref.read(runTimeProvider.notifier).value = null;
    _ref.read(realTunEnableProvider.notifier).value = false;
    // A failed TUN repair must not cause repeated authorization attempts.
    if (suppressAuthorization) _tunAdminDenied = true;
  }

  Future<bool> updateStatus(bool isStart) async {
    if (_isCoreSwitching || (_isExiting && isStart)) return false;
    _isCoreSwitching = true;
    globalState.isCoreSwitchingNotifier.value = true;
    unawaited(XBoardDeviceHeartbeatService.markActive(
      reason: isStart ? 'proxy_start' : 'proxy_stop',
      force: true,
    ));
    try {
      if (isStart) {
        final pendingCleanup = _disconnectCleanupFuture;
        if (pendingCleanup != null) {
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.coreConnecting,
          );
          await pendingCleanup;
        }
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.coreConnecting,
        );
        final started = await runVerifiedConnectionStart(
          start: () async {
            if (system.isDesktop && clashService?.isConnected != true) {
              await restartCore(restoreStart: false);
            }
            final profile = _ref.read(currentProfileProvider);
            if (profile == null) throw StateError('No profile available');
            final modified = await profile.profileLastModified;
            if (!Platform.isIOS &&
                (lastProfileModified == null ||
                    modified != lastProfileModified)) {
              await applyProfile(silence: true);
            }
            return globalState.prepareStart(
              repairListener: Platform.isAndroid ? _repairAndroidListener : null,
            );
          },
          verify: _verifyStartedConnection,
          commit: () =>
              globalState.commitStarted([updateRunTime, updateTraffic]),
          rollback: _rollbackFailedStart,
        );
        if (!started) {
          globalState.updateCoreSwitchStatus(
            CoreSwitchStage.failed,
          );
          return false;
        }
        addCheckIpNumDebounce();
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.connected,
        );
        return true;
      } else {
        globalState.updateCoreSwitchStatus(
          CoreSwitchStage.stopping,
        );
        if (Platform.isAndroid || Platform.isIOS) {
          await _stopMobileRouting();
          _ref.read(runTimeProvider.notifier).value = null;
          addCheckIpNumDebounce();
          _startDisconnectCleanup();
          return true;
        }
        if (await proxy?.stopProxy() != true) {
          throw StateError('System proxy could not be restored');
        }
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
        message: isStart
            ? appLocalizations.xboardCoreStageFailed
            : appLocalizations.xboardCoreDisconnectFailed,
      );
      rethrow;
    } finally {
      _isConfigurationSwitching = false;
      _isCoreSwitching = false;
      globalState.isCoreSwitchingNotifier.value = false;
      if (globalState.coreSwitchStatusNotifier.value.stage !=
          CoreSwitchStage.failed) {
        globalState.resetCoreSwitchStatus();
      }
    }
  }

  Future<void> _verifyStartedConnection() async {
    if (Platform.isIOS) {
      globalState.updateCoreSwitchStatus(CoreSwitchStage.coreConnecting,
          message: appLocalizations.xboardCoreVerifying);
      if (await service?.isVpnActuallyRunning() != true) {
        throw StateError('系统 VPN 未连接');
      }
    }
    await updateGroups(requireLive: true);
    await synchronizeProxySelection();
    if (!system.isDesktop) return;
    final proxyState = _ref.read(proxyStateProvider);
    final port = proxyState.port;
    if (port <= 0 &&
        (!_ref.read(realTunEnableProvider) || proxyState.systemProxy)) {
      throw StateError('Core proxy listener port is disabled');
    }
    if (port > 0) {
      Socket? socket;
      try {
        socket = await Socket.connect(InternetAddress.loopbackIPv4, port,
            timeout: const Duration(seconds: 2));
      } catch (_) {
        throw StateError('Core proxy listener unavailable');
      } finally {
        socket?.destroy();
      }
    }
    await startVerifiedDesktopProxy(
      enabled: proxyState.systemProxy,
      start: () async => proxy?.startProxy(port, proxyState.bassDomain),
      matches: () async =>
          (await proxy?.getSystemProxyStatus())?.matches('127.0.0.1', port) ==
          true,
    );
    if (clashService?.isConnected != true) {
      throw StateError('Core disconnected during routing verification');
    }
  }

  Future<void> _restoreVerifiedConnection() async {
    final started = await runVerifiedConnectionStart(
      start: globalState.prepareStart,
      verify: _verifyStartedConnection,
      commit: () => globalState.commitStarted([updateRunTime, updateTraffic]),
      rollback: _rollbackFailedStart,
    );
    if (!started) throw StateError('Core connection could not be restored');
  }

  Future<void> _rollbackFailedStart() async {
    // The UI must converge even if the native shutdown itself fails.
    globalState.startTime = null;
    globalState.stopUpdateTasks();
    _ref.read(runTimeProvider.notifier).value = null;
    try {
      if (system.isDesktop && await proxy?.stopProxy() == false) {
        commonPrint.log('[Connection] system proxy rollback failed');
      }
      await globalState.handleStop();
    } catch (error) {
      commonPrint.log('[Connection] rollback failed: $error');
      if (system.isDesktop) await clashService?.shutdown();
    } finally {
      _ref.read(realTunEnableProvider.notifier).value = false;
      lastProfileModified = null;
    }
  }

  Future<void> _stopMobileRouting() async {
    globalState.isDisconnectCleanup = true;
    globalState.suppressConnectionCleanupUntil =
        DateTime.now().add(const Duration(seconds: 3));
    globalState.startTime = null;
    globalState.stopUpdateTasks();
    try {
      await service?.stopVpn();
    } catch (_) {
      globalState.isDisconnectCleanup = false;
      rethrow;
    }
  }

  void _startDisconnectCleanup() {
    late final Future<void> cleanup;
    cleanup = _finishDisconnectCleanup().whenComplete(() {
      if (identical(_disconnectCleanupFuture, cleanup)) {
        _disconnectCleanupFuture = null;
      }
    });
    _disconnectCleanupFuture = cleanup;
    unawaited(cleanup);
  }

  Future<void> _finishDisconnectCleanup() async {
    try {
      if (Platform.isAndroid) {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (
            await clashLib?.getRunTime().timeout(const Duration(seconds: 1)) !=
                null) {
          if (DateTime.now().isAfter(deadline)) {
            commonPrint.log(
              'Android disconnect cleanup timed out waiting for TUN to stop',
            );
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        // getAndroidVpnOptions uses the same tunLock as handleStopTun. Reading
        // it here is a completion barrier: it only returns after the old TUN
        // handler and its file descriptor have been fully released.
        await clashLib
            ?.getAndroidVpnOptions()
            .timeout(const Duration(seconds: 3));
        await clashCore.stopListener().timeout(const Duration(seconds: 3));
      }
      await clashCore.resetTraffic();
      _ref.read(trafficsProvider.notifier).clear();
      _ref.read(totalTrafficProvider.notifier).value = Traffic();
      await tray.updateTrayTitle();
    } catch (error) {
      commonPrint.log('disconnect cleanup failed: $error');
    } finally {
      globalState.isDisconnectCleanup = false;
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
    if (system.isDesktop && !globalState.isStart) return;
    final traffic = await clashCore.getTraffic();
    if (system.isDesktop && !globalState.isStart) return;
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
    // Every caller waits for its update; never report an ignored update as saved.
    final previous = _configUpdateFuture;
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {/* A newer update may recover. */}
      }
      if (Platform.isIOS && !globalState.isStart) return;
      if (!await clashCore.isInit) return;
      await _acquireConfigurationSwitch();
      // Recheck after waiting for a concurrent disconnect to finish.
      if (Platform.isIOS && !globalState.isStart) {
        _isConfigurationSwitching = false;
        _isCoreSwitching = false;
        globalState.isCoreSwitchingNotifier.value = false;
        globalState.resetCoreSwitchStatus();
        return;
      }
      await _performConfigUpdate();
    }();
    _configUpdateFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_configUpdateFuture, operation)) _configUpdateFuture = null;
    }
  }

  Future<void> _acquireConfigurationSwitch() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (_isCoreSwitching) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
            'The core is busy; configuration was not applied.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _isConfigurationSwitching = true;
    _isCoreSwitching = true;
    globalState.isCoreSwitchingNotifier.value = true;
  }

  Future<void> _performConfigUpdate() async {
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
      _isConfigurationSwitching = false;
      _isCoreSwitching = false;
      globalState.isCoreSwitchingNotifier.value = false;
      globalState.resetCoreSwitchStatus();
    }
  }

  Future<void> _updateClashConfig() async {
    final updateParams = _ref.read(updateParamsProvider);
    final wasStart = _ref.read(runTimeProvider.notifier).isStart;
    final res = await _requestAdmin(updateParams.tun.enable);
    if (res.isError) {
      throw StateError('Could not prepare core configuration');
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
        await _restoreVerifiedConnection();
      }
      return;
    }
    final message = await clashCore.updateConfig(
      updateParams.copyWith.tun(
        enable: adminResult.enableTun,
      ),
    );
    await _checkCoreConfigurationResult(message);
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
            await restartCore(
              setupProfile: false,
              restoreStart: false,
              requireHelper: Platform.isWindows,
            );
            didRestartCore = true;
            break;
          case AuthorizeCode.none:
            // Helper may be ready while the old core is still unprivileged.
            if (Platform.isWindows) {
              await restartCore(
                setupProfile: false,
                restoreStart: false,
                requireHelper: true,
              );
              didRestartCore = true;
            }
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
      await _restoreVerifiedConnection();
    }
  }

  Future<void> _repairAndroidListener() async {
    lastProfileModified = null;
    if (!await clashCore.isInit && !await clashCore.init()) {
      throw StateError('Clash core initialization failed');
    }
    await _profileApplications.run(() async {
      await _setupClashConfigWithTun(
        _ref.read(patchClashConfigProvider),
        _ref.read(realTunEnableProvider),
      );
    });
  }

  Future<void> _checkCoreConfigurationResult(String message) async {
    if (message.isEmpty) return;
    // This prefix is a native protocol code, not a translated UI message.
    if (system.isDesktop && message.startsWith('TUN_START_FAILED:')) {
      await _handleDesktopCoreDisconnected();
    }
    throw StateError(message);
  }

  Future<void> _setupClashConfigWithTun(
    ClashConfig patchConfig,
    bool enableTun,
  ) async {
    await ClashCore.initGeo();
    final realPatchConfig = patchConfig.copyWith.tun(enable: enableTun);
    final params = await globalState.getSetupParams(
      pathConfig: realPatchConfig,
    );
    late String message;
    try {
      message = await clashCore.setupConfig(
        params,
        timeout: _isConnectionRepair && system.isDesktop
            ? const Duration(seconds: 30)
            : const Duration(minutes: 2),
      );
    } on TimeoutException {
      if (system.isDesktop) {
        // Stop the stalled native operation; do not leave it applying a late
        // configuration after the UI has released the operation lock.
        await clashService?.shutdown();
        _markDesktopCoreStopped();
      }
      rethrow;
    }
    await _checkCoreConfigurationResult(message);
    lastProfileModified = await _ref.read(
      currentProfileProvider.select(
        (state) => state?.profileLastModified,
      ),
    );
  }

  Future _applyProfile() async {
    if (_ref.read(currentProfileProvider) == null) {
      // First launch and logout legitimately have no subscription. Import and
      // connection boundaries still require an actual selected profile.
      if (isImportApplying) throw StateError('Profile unavailable');
      return;
    }
    if (Platform.isIOS) {
      if (globalState.isStart || _ref.read(runTimeProvider) != null) {
        // Pass configuration contents, not app-private paths, to the running
        // extension. Publishing local YAML alone would leave the old nodes live.
        final params = await globalState.getSetupParams(
          pathConfig: _ref.read(patchClashConfigProvider),
        );
        final vpnService = service;
        if (vpnService == null) throw StateError('VPN service unavailable');
        await vpnService.reloadConfiguration(json.encode(params));
        await updateGroups(requireLive: true);
        await synchronizeProxySelection();
      } else {
        // The extension is unavailable until the first connection starts.
        await _applyProfileFromYaml(requireNodes: true);
      }
      return;
    }
    if (system.isDesktop && clashService?.isConnected != true) {
      await restartCore(setupProfile: false, restoreStart: false);
    }
    await clashCore.requestGc();
    await _setupClashConfig();
    await Future.wait<void>(
        [updateGroups(requireLive: true), updateProviders()]);
    await synchronizeProxySelection();
  }

  /// iOS/fallback: parse profile YAML directly in Dart to build Groups.
  /// This runs when VPN is not connected so clash core (in PacketTunnel) is
  /// unavailable. Gives users a node list before connecting.
  ///
  /// Handles both inline `proxies:` and `proxy-providers:` with `use:`.
  Future<void> _applyProfileFromYaml({
    bool requireNodes = false,
    bool Function()? canApply,
  }) async {
    try {
      final profile = _ref.read(currentProfileProvider);
      if (profile == null || !await profile.check()) {
        if (requireNodes) throw StateError('Profile unavailable');
        return;
      }
      final content = await ProfileVault.instance.readText(profile.id);
      if (canApply?.call() == false) return;
      await ProfileVault.instance.prepareRuntimeProviders(profile.id);
      if (canApply?.call() == false) return;
      final yamlDoc = loadYaml(content);
      if (yamlDoc is! YamlMap) {
        if (requireNodes) throw StateError('Invalid profile configuration');
        return;
      }

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
        for (final entry in providers.entries) {
          final providerName = entry.key.toString();
          final providerCfg = entry.value;
          if (providerCfg is! YamlMap) continue;
          final path = providerCfg['path']?.toString();
          final url = providerCfg['url']?.toString();
          if ((path == null || path.isEmpty) && (url == null || url.isEmpty)) {
            continue;
          }

          final providerFile = File(
            url != null && url.isNotEmpty
                ? await appPath.getRuntimeProvidersFilePath(
                    profile.id,
                    'proxies',
                    url,
                  )
                : path!,
          );
          try {
            if (await providerFile.exists()) {
              final providerContent = await ProfileVault.instance
                  .readRuntimeProvider(profile.id, providerFile.path);
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
                (p) => groups
                    .any((g) => g.name == p!.name && g.type.isComputedSelected),
                orElse: () => null,
              );
          if (computedProxy != null) {
            groups[i] = group.copyWith(now: computedProxy.name);
          }
        }
      }

      if (requireNodes && groups.isEmpty) {
        throw StateError('Profile contains no proxy groups');
      }
      if (canApply?.call() == false) return;
      final existing = _ref.read(groupsProvider);
      if (groups.isNotEmpty || existing.isEmpty) {
        _ref.read(groupsProvider.notifier).value = groups;
      }
    } catch (e) {
      commonPrint.log('_applyProfileFromYaml error: $e');
      if (requireNodes) rethrow;
    }
  }

  /// 从磁盘中的当前 Profile 和 provider 缓存重建节点列表。
  ///
  /// 不访问业务后端，供离线启动和订阅更新失败时恢复节点选择界面。
  Future<void> loadGroupsFromLocalProfile({bool Function()? canApply}) =>
      _applyProfileFromYaml(canApply: canApply);

  Future<void> applyProfile({bool silence = false}) =>
      _profileApplications.run(() => _runProfileApplication(silence: silence));

  Future<void> _runProfileApplication({required bool silence}) async {
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

  /// Apply user overrides through the complete profile path, including rules.
  Future<void> applyUserConfiguration() async {
    final previous = _configUpdateFuture;
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _acquireConfigurationSwitch();
      try {
        await _applyUserConfiguration();
      } finally {
        _isConfigurationSwitching = false;
        _isCoreSwitching = false;
        globalState.isCoreSwitchingNotifier.value = false;
      }
    }();
    _configUpdateFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_configUpdateFuture, operation)) _configUpdateFuture = null;
    }
  }

  Future<void> _applyUserConfiguration() async {
    await applyProfile(silence: true);
  }

  handleChangeProfile() {
    // 订阅导入流程自己会调用 applyProfile，跳过此处避免并发竞争
    if (isImportApplying) return;
    _ref.read(delayDataSourceProvider.notifier).value = {};
    // On iOS, YAML parsing is fast and doesn't need a loading overlay.
    applyProfile(silence: Platform.isIOS);
    // Keep the causal history across profile changes and connection repairs.
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

  Future<void> updateGroups({bool requireLive = false}) async {
    if (Platform.isIOS && !globalState.isStart && !requireLive) {
      // VPN not connected — mihomo not running. Parse YAML locally.
      await _applyProfileFromYaml();
      return;
    }
    try {
      final newGroups = requireLive
          ? await waitForLiveCoreGroups(
              read: clashCore.getProxiesGroups,
              timeout: Duration(seconds: Platform.isIOS ? 10 : 5),
            )
          : await retry(
              task: clashCore.getProxiesGroups,
              retryIf: (res) => res.isEmpty,
            );
      final existing = _ref.read(groupsProvider);
      if (newGroups.isEmpty) {
        if (requireLive) throw StateError('Core proxy groups unavailable');
        if (existing.isNotEmpty) return;
        await _applyProfileFromYaml();
        return;
      }
      // Preserve the core's actual selection, including DIRECT/REJECT.
      _ref.read(groupsProvider.notifier).value = newGroups;
    } catch (e) {
      commonPrint.log('updateGroups error: $e');
      if (requireLive) rethrow;
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
    if (Platform.isIOS && !globalState.isStart) {
      updateCurrentSelectedMap(groupName, proxyName);
      return;
    }
    unawaited(XBoardDeviceHeartbeatService.markActive(reason: 'change_proxy'));
    await _proxySelection.select(groupName, proxyName);
    updateCurrentSelectedMap(groupName, proxyName);
    if (_ref.read(appSettingProvider).closeConnections) {
      await clashCore.closeConnections();
    }
    addCheckIpNumDebounce();
  }

  handleBackOrExit() async {
    if (_ref.read(backBlockProvider)) {
      return;
    }
    if (CustomerServiceHelper.hideEmbeddedCustomerServiceIfVisible()) {
      return;
    }
    if (_isExiting) return;
    if (system.isDesktop) {
      await savePreferencesDebounce();
    }
    await system.back();
  }

  /// 日常关闭窗口和系统返回键只进入后台。仅桌面托盘的“退出应用”
  /// 会调用本方法，防止用户误关窗口导致网络中断。
  Future<void> requestExit() async {
    if (_isExitDialogVisible || _isExiting) return;
    if (!globalState.isStart) {
      await handleExit();
      return;
    }

    _isExitDialogVisible = true;
    try {
      final confirmed = await globalState.showCommonDialog<bool>(
        child: Builder(
          builder: (dialogContext) => CommonDialog(
            title: '退出并断开 VPN？',
            child: const Text('退出应用将停止代理，并恢复设备网络设置。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('退出应用'),
              ),
            ],
          ),
        ),
      );
      if (confirmed == true) {
        await handleExit();
      }
    } finally {
      _isExitDialogVisible = false;
    }
  }

  backBlock() {
    _ref.read(backBlockProvider.notifier).value = true;
  }

  unBackBlock() {
    _ref.read(backBlockProvider.notifier).value = false;
  }

  Future<void> handleExit() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      if (globalState.isStart) {
        try {
          await updateStatus(false).timeout(const Duration(seconds: 5));
        } catch (error) {
          commonPrint.log('disconnect before exit failed: $error');
        }
      }
      await _exitService.handleExit();
    } finally {
      _isExiting = false;
    }
  }

  Future<void> handleClearCacheAndRestart() async {
    if (_isExiting || _isCoreSwitching) return;
    _isExiting = true;
    try {
      await _exitService.handleClearCacheAndRestart();
    } finally {
      _isExiting = false;
    }
  }

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
        final initialized = await clashCore.init();
        if (!initialized) throw StateError('Core initialization failed');
        final stateApplied = await clashCore.setState(
          globalState.getCoreState(),
        );
        if (!stateApplied) throw StateError('Core state setup failed');
      }
    }
    if (setupProfile) {
      await applyProfile(silence: true);
    }

    // Do not create or start the iOS Packet Tunnel here. Privacy consent is
    // collected once at first launch, before the user can use the client.
  }

  init() async {
    globalState.coreStatusReadyNotifier.value = false;
    globalState.coreStatusRecoveringNotifier.value = false;
    try {
      await bootDiagLog('AppController.init begin');
      FlutterError.onError = (details) {
        commonPrint.log(details.stack.toString());
      };
      updateTray(true);
      await _syncLaunchWindowVisibility();
      await bootDiagLog('launch window visibility synced');
      // Adopt the existing system tunnel before any profile application.
      if (Platform.isIOS) await restoreIosConnection();
      final adoptAndroid =
          Platform.isAndroid && await service?.isVpnActuallyRunning() == true;
      if (adoptAndroid) await globalState.updateStartTime();
      await _initCore(
        setupProfile: !(Platform.isIOS || adoptAndroid) || !globalState.isStart,
      );
      await bootDiagLog('core init complete');
      await _initStatus();
      await bootDiagLog('status init complete');
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
      _ref.read(initProvider.notifier).value = true;
      await bootDiagLog('AppController.init complete');
    } finally {
      globalState.coreStatusRecoveringNotifier.value = false;
      globalState.coreStatusReadyNotifier.value = true;
    }
  }

  Future<void> _syncLaunchWindowVisibility() async {
    if (!system.isDesktop) return;
    if (_ref.read(appSettingProvider).silentLaunch) {
      await window?.hide();
      return;
    }
    await window?.show();
  }

  Future<void> restoreIosConnection() async {
    final snapshot = await service!.restoreIosVpnState();
    final status = snapshot['status'];
    if (status == 'connected') {
      final milliseconds = (snapshot['connectedAt'] as num?)?.toInt() ?? 0;
      globalState.startTime = milliseconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(milliseconds)
          : DateTime.now().subtract(const Duration(milliseconds: 1));
      globalState.startUpdateTasks([updateRunTime, updateTraffic]);
      updateRunTime();
      await updateGroups(requireLive: true);
      globalState.updateCoreSwitchStatus(CoreSwitchStage.connected);
    } else if (status == 'connecting' || status == 'recovering') {
      globalState.updateCoreSwitchStatus(CoreSwitchStage.coreConnecting,
          message: appLocalizations.xboardCoreRestoring);
    }
  }

  _initStatus() async {
    if (Platform.isIOS) {
      // Restoring the UI must never start, stop or reconfigure a system tunnel.
      return;
    }
    if (Platform.isAndroid && await service?.isVpnActuallyRunning() == true) {
      // Reopening the UI adopts the live service. Reapplying profiles or
      // invoking start/stop here can reset its runtime or disturb traffic.
      await globalState.updateStartTime();
      await updateGroups(requireLive: true);
      await updateProviders();
      globalState.commitStarted([updateRunTime, updateTraffic]);
      updateRunTime();
      return;
    }
    // 所有平台启动时先尝试从核心恢复真实运行时间。
    // handleStart 会保留这个时间，因此接管已有连接时不会重新从 0 计时。
    await globalState.updateStartTime();
    // “恢复连接”只用于核心中确实存在上一段运行状态的情况。
    // 冷启动期间读取核心与 VPN 状态时仍属于普通初始化。
    globalState.coreStatusRecoveringNotifier.value = globalState.isStart;
    if (globalState.isStart) {
      updateRunTime();
    }
    final status = globalState.isStart || _ref.read(appSettingProvider).autoRun;

    try {
      await updateStatus(status);
      if (!status) {
        addCheckIpNumDebounce();
      }
    } finally {
      globalState.coreStatusRecoveringNotifier.value = false;
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
      (String url) async {
        final zh = Localizations.localeOf(context).languageCode == 'zh';
        final source = Uri.tryParse(url);
        if (source == null || source.host.isEmpty ||
            (source.scheme != 'https' && source.scheme != 'http')) {
          globalState.showNotifier(appLocalizations.subscriptionImportFailed);
          return;
        }
        final res = await globalState.showMessage(
          title: '${appLocalizations.add}${appLocalizations.profile}',
          confirmText: zh ? '添加并使用' : 'Add and use',
          message: TextSpan(
            children: [
              TextSpan(text: appLocalizations.doYouWantToPass),
              TextSpan(
                text: ' ${source.host} ',
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
        await addProfileFormURL(url);
      },
    );
  }

  Future<void> importProfileInBackground(String url) =>
      _profileController.importProfileInBackground(url);

  Future<void> addProfileFormURL(String url) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    toProfiles();
    final epoch = _ref.read(sessionEpochProvider);
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    Future<Profile> fetch() {
      for (final saved in _ref.read(profilesProvider)) {
        if (saved.useProvidedUrl && saved.url == url) return saved.update();
      }
      return Profile.normal(url: url, useProvidedUrl: true).update();
    }
    try {
      final profile = commonScaffoldState != null && commonScaffoldState.mounted
          ? await commonScaffoldState.loadingRun<Profile>(fetch,
              title: '${appLocalizations.add}${appLocalizations.profile}')
          : await fetch();
      if (profile == null) return;
      await runProfileImport(() async {
        if (_ref.read(sessionEpochProvider) != epoch) {
          throw StateError('Account changed during import');
        }
        final previous = _ref.read(currentProfileIdProvider);
        await addProfile(profile);
        _ref.read(currentProfileIdProvider.notifier).value = profile.id;
        try {
          await applyProfile(silence: true);
          await savePreferences();
        } catch (_) {
          if (_ref.read(currentProfileIdProvider) == profile.id &&
              _ref.read(sessionEpochProvider) == epoch) {
            _ref.read(currentProfileIdProvider.notifier).value = previous;
            if (previous != null) await applyProfile(silence: true);
            await savePreferences();
          }
          rethrow;
        }
      });
      globalState.showNotifier(
          '${appLocalizations.add} · ${profile.label ?? Uri.parse(url).host}');
    } catch (_) {
      globalState.showNotifier(appLocalizations.subscriptionImportFailed);
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

  Future<List<Package>> getPackages({bool refresh = false}) async {
    if (_ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (refresh || _ref.read(packagesProvider).isEmpty) {
      _ref.read(packagesProvider.notifier).value = refresh
          ? await app?.refreshPackages() ?? []
          : await app?.getPackages() ?? [];
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
    }
    if (mode != Mode.direct && (!Platform.isIOS || globalState.isStart)) {
      unawaited(synchronizeProxySelection().catchError((Object error) {
        commonPrint.log('[ProxySelection] mode sync failed: $error');
        XBoardNotification.showError(
            appLocalizations.xboardProxySelectionFailed);
      }));
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

  Future<bool> exportLogs() async {
    final report = DiagnosticLogBuffer.fromList(_ref.read(logsProvider)).export(
      chinese: (globalState.config.appSetting.locale ?? Platform.localeName)
          .startsWith('zh'),
      clientVersion:
          '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
      systemVersion:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    final data = await Isolate.run<List<int>>(() async {
      return utf8.encode(report);
    });
    return await picker.saveFile(
          utils.logFile,
          Uint8List.fromList(data),
        ) !=
        null;
  }

  updateTray([bool focus = false]) async {
    tray.update(
      trayState: _ref.read(trayStateProvider),
    );
  }
}
