import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  _updateProxy(ProxyState proxyState) async {
    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    commonPrint.log(
        "[ProxyManager] _updateProxy called: isStart=$isStart, systemProxy=$systemProxy, port=$port, proxy=${proxy != null ? 'exists' : 'null'}");
    if (isStart && systemProxy) {
      commonPrint.log(
          "[ProxyManager] >>> Calling startProxy(port=$port, bypass=${proxyState.bassDomain.length} domains)");
      final result = await proxy?.startProxy(port, proxyState.bassDomain);
      commonPrint.log("[ProxyManager] <<< startProxy result: $result");
    } else {
      commonPrint.log(
          "[ProxyManager] >>> Calling stopProxy (isStart=$isStart, systemProxy=$systemProxy)");
      proxy?.stopProxy();
    }
  }

  @override
  void initState() {
    super.initState();
    commonPrint.log(
        "[ProxyManager] initState called, proxy=${proxy != null ? 'exists' : 'null'}");
    ref.listenManual(
      proxyStateProvider,
      (prev, next) {
        commonPrint.log(
            "[ProxyManager] proxyStateProvider changed: prev=${prev?.isStart}, next=${next.isStart}, systemProxy=${next.systemProxy}");
        if (prev != next) {
          _updateProxy(next);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
