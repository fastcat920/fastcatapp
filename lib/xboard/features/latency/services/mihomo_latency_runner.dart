import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';

Future<void> testNodeLatency(Proxy proxy, [String? testUrl]) async {
  final controller = globalState.appController;
  final state = controller.getProxyCardState(proxy.name);
  final url = state.testUrl.getSafeValue(controller.getRealTestUrl(testUrl));
  if (state.proxyName.isEmpty) return;
  controller.setDelay(Delay(url: url, name: state.proxyName, value: 0));
  controller.setDelay(await clashCore.getDelay(url, state.proxyName));
}

Future<void> testNodesLatency(
  List<Proxy> proxies, [
  String? testUrl,
  void Function(String proxyName)? onResult,
]) async {
  final controller = globalState.appController;
  final names = proxies.map((proxy) => proxy.name).toSet();
  final tests = names.map((proxyName) async {
    final state = controller.getProxyCardState(proxyName);
    final url = state.testUrl.getSafeValue(controller.getRealTestUrl(testUrl));
    if (state.proxyName.isEmpty) return;
    controller.setDelay(Delay(url: url, name: state.proxyName, value: 0));
    controller.setDelay(await clashCore.getDelay(url, state.proxyName));
    onResult?.call(state.proxyName);
  }).toList();
  for (final batch in tests.batch(100)) {
    await Future.wait(batch);
  }
  controller.addSortNum();
}
