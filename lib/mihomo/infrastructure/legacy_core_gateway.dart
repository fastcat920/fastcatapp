import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/state.dart';

import '../application/core_gateway.dart';
import '../domain/core_models.dart';

/// Compatibility adapter around the proven platform/core integration.
///
/// FastCat features depend on [CoreGateway]; current legacy state remains
/// contained here until the platform bridges are migrated independently.
class LegacyCoreGateway implements CoreGateway {
  const LegacyCoreGateway();

  @override
  bool get isRunning => globalState.isStart;

  @override
  MihomoRuntimeStatus get runtimeStatus {
    final status = globalState.coreSwitchStatusNotifier.value.stage;
    return switch (status) {
      CoreSwitchStage.checkingHelper ||
      CoreSwitchStage.startingService ||
      CoreSwitchStage.helperReady ||
      CoreSwitchStage.coreConnecting ||
      CoreSwitchStage.tunApplying =>
        MihomoRuntimeStatus.starting,
      CoreSwitchStage.connected => MihomoRuntimeStatus.running,
      CoreSwitchStage.stopping => MihomoRuntimeStatus.stopping,
      CoreSwitchStage.failed => MihomoRuntimeStatus.failed,
      CoreSwitchStage.idle =>
        isRunning ? MihomoRuntimeStatus.running : MihomoRuntimeStatus.stopped,
    };
  }

  @override
  List<MihomoGroup> getGroups() {
    return globalState.appController.getCurrentGroups().map((group) {
      final nodes = group.all.map((proxy) {
        return MihomoNode(
          name: proxy.name,
          type: proxy.type,
          delayMs: getNodeDelay(proxy.name, testUrl: group.testUrl),
        );
      }).toList(growable: false);
      final selected = globalState.appController
          .getSelectedProxyName(group.name)
          ?.toString();
      return MihomoGroup(
        name: group.name,
        type: group.type.name,
        nodes: nodes,
        selected: selected?.isNotEmpty == true ? selected : group.now,
        hidden: group.hidden == true,
        testUrl: group.testUrl,
      );
    }).toList(growable: false);
  }

  @override
  String? getCurrentGroupName() =>
      globalState.appController.getCurrentGroupName()?.toString();

  @override
  Future<bool> setRunning(bool value) =>
      globalState.appController.updateStatus(value);

  @override
  Future<void> selectNode({
    required String groupName,
    required String nodeName,
  }) async {
    await globalState.appController.changeProxy(
      groupName: groupName,
      proxyName: nodeName,
    );
    globalState.appController.updateCurrentSelectedMap(groupName, nodeName);
    globalState.appController.updateCurrentGroupName(groupName);
    await globalState.appController.updateGroups();
  }

  @override
  Future<void> refreshGroups() => globalState.appController.updateGroups();

  @override
  Future<void> applyCurrentProfile() =>
      globalState.appController.applyProfile(silence: true);

  @override
  int? getNodeDelay(String nodeName, {String? testUrl}) {
    final state = globalState.appController.getProxyCardState(nodeName);
    final resolvedName = state.proxyName.isEmpty ? nodeName : state.proxyName;
    final resolvedUrl = globalState.appController.getRealTestUrl(
      state.testUrl ?? testUrl,
    );
    return globalState.appState.delayMap[resolvedUrl]?[resolvedName];
  }
}
