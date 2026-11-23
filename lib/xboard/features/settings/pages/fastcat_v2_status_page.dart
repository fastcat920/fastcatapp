import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatV2StatusPage extends ConsumerStatefulWidget {
  const FastCatV2StatusPage({super.key});

  @override
  ConsumerState<FastCatV2StatusPage> createState() => _FastCatV2StatusState();
}

class _FastCatV2StatusState extends ConsumerState<FastCatV2StatusPage> {
  Future<Map>? _snapshot;

  Future<Map> _read() async => await clashCore.clashInterface.getProxies();

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final online = ref.watch(runTimeProvider.select((v) => v != null));
    if (!online) _snapshot = null;
    final errors = {
      'entry': zh ? '入口网络不可达' : 'Gateway unreachable',
      'certificate': zh ? '证书验证失败' : 'Certificate verification failed',
      'authentication': zh ? '设备凭证被拒绝' : 'Device credential rejected',
      'target': zh ? '目标连接失败或被策略拒绝' : 'Target unavailable or denied',
      'capacity': zh ? '入口已达容量上限' : 'Gateway at capacity',
      'protocol': zh ? '协议协商失败' : 'Protocol negotiation failed',
    };
    final udpStates = {
      'available': zh ? '已接通' : 'Connected',
      'unavailable': zh ? '不可用' : 'Unavailable',
      'disabled': zh ? '节点未启用' : 'Disabled for node',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(zh ? 'FastCat v2 连接状态' : 'FastCat v2 connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            onPressed:
                online ? () => setState(() => _snapshot = _read()) : null,
          ),
        ],
      ),
      body: !online
          ? Center(
              child:
                  Text(zh ? '连接 VPN 后可查看。' : 'Connect the VPN to view status.'))
          : FutureBuilder<Map>(
              future: _snapshot ??= _read(),
              builder: (context, result) {
                if (result.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (result.hasError) {
                  return Center(
                      child: Text(zh
                          ? '未能读取连接状态，请刷新。'
                          : 'Unable to read status. Refresh to retry.'));
                }
                final nodes = <Widget>[];
                for (final e in (result.data ?? const {}).entries) {
                  final data = e.value;
                  if (data is! Map || data['fastcat-v2'] is! Map) continue;
                  final state = data['fastcat-v2'] as Map;
                  final unknown = zh ? '尚无记录' : 'No observation yet';
                  final tcp = {
                        'h3': 'HTTP/3',
                        'h2': 'HTTP/2'
                      }[state['tcp-protocol']] ??
                      unknown;
                  final lines = [
                    '${zh ? '最近 TCP 连接' : 'Last TCP connection'} · $tcp',
                    'UDP · ${udpStates[state['udp-status']] ?? unknown}',
                    for (final kind in ['tcp', 'udp'])
                      if (errors.containsKey(state['$kind-error']))
                        '${kind.toUpperCase()} · ${errors[state['$kind-error']]}',
                  ];
                  nodes.add(ListTile(
                      title: Text(e.key.toString()),
                      subtitle: Text(lines.join('\n'))));
                }
                return nodes.isEmpty
                    ? Center(
                        child: Text(zh
                            ? '当前配置没有 FastCat v2 节点。'
                            : 'No FastCat v2 nodes in this profile.'))
                    : ListView(children: nodes);
              },
            ),
    );
  }
}
