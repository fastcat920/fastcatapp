import 'dart:convert';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/constant.dart' show defaultTestUrl;
import 'package:fl_clash/security/local_auto_profile.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/mihomo/mihomo.dart';
import 'package:fl_clash/security/profile_vault.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fastcat_test_node.dart';
import 'fastcat_device_probe.dart';

class FastCatTestNodePage extends ConsumerStatefulWidget {
  const FastCatTestNodePage({super.key});
  @override
  ConsumerState<FastCatTestNodePage> createState() =>
      _FastCatTestNodePageState();
}

class _FastCatTestNodePageState extends ConsumerState<FastCatTestNodePage> {
  static const _previousKey = 'fastcat_https_previous_profile_v1';
  static const _autoPreviousKey = 'fastcat_auto_previous_profile_v1';
  String _verification = '';
  var _form = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _port = TextEditingController();
  late FastCatTestProtocol _protocol;
  final _token = TextEditingController();
  String _savedToken = '';
  bool _loading = true;
  bool _busy = false;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _mobile => _isIOS || defaultTargetPlatform == TargetPlatform.android;
  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  String _text(String zh, String en) => _zh ? zh : en;

  Profile? get _profile {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.id == _protocol.profileId) return profile;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _protocol = _mobile
        ? FastCatTestProtocol.forProfile(ref.read(currentProfileIdProvider)) ??
            FastCatTestProtocol.https
        : FastCatTestProtocol.https;
    _load();
  }

  Future<void> _load() async {
    _server.text = 'zlhk.fastcat.ink';
    _port.text = _protocol.port.toString();
    _token.clear();
    _savedToken = '';
    try {
      if (_profile != null) {
        final data = jsonDecode(
                await ProfileVault.instance.readText(_protocol.profileId))
            as Map<String, dynamic>;
        if (!mounted) return;
        final node = (data['proxies'] as List).single as Map;
        if (node['type'] != _protocol.type) {
          throw const FormatException('Unexpected test protocol');
        }
        _server.text = node['server'] as String;
        _port.text = '${node['port']}';
        _savedToken = node['token'] as String;
      }
    } catch (_) {
      if (mounted) {
        _message(_text('测试节点读取失败，请重新填写',
            'Could not read the test node. Enter its details again.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _chooseProtocol(Set<FastCatTestProtocol> selection) {
    final protocol = selection.single;
    if (_busy || _loading || protocol == _protocol) return;
    setState(() {
      _protocol = protocol;
      _form = GlobalKey<FormState>();
      _loading = true;
    });
    _load();
  }

  @override
  void dispose() {
    _server.dispose();
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _reportSavedChange(String message) async {
    if (!mounted) return;
    final active =
        FastCatTestProtocol.forProfile(ref.read(currentProfileIdProvider));
    if (_isIOS &&
        active != null &&
        active != _protocol &&
        ref.read(runTimeProvider) != null) {
      // The active test profile may have loaded this node for paired probes.
      try {
        await ref.read(coreGatewayProvider).applyCurrentProfile();
      } catch (_) {
        if (!mounted) return;
        message += _text('。请重连 VPN 以更新对照节点。',
            ' Reconnect the VPN to update the comparison node.');
      }
    }
    if (mounted) _message(message);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final node = FastCatTestNode(
          protocol: _protocol,
          server: _server.text.trim(),
          port: int.parse(_port.text),
          token: _token.text.isEmpty ? _savedToken : _token.text);
      final profile = (_profile ??
              Profile.normal(label: _protocol.node)
                  .copyWith(id: _protocol.profileId))
          .copyWith(
              autoUpdate: false,
              currentGroupName: _protocol.group,
              selectedMap: {
            _protocol.group: _protocol.node,
            'GLOBAL': _protocol.group
          });
      // The iOS tunnel is unavailable while disconnected. Validate this fixed
      // schema locally and encrypt it; the native core checks it on activation.
      await ProfileVault.instance.writeText(profile.id, node.configuration());
      final saved = profile.copyWith(lastUpdateDate: DateTime.now());
      ref.read(profilesProvider.notifier).setProfile(saved);
      await globalState.appController.savePreferences();
      _savedToken = node.token;
      _token.clear();
      if (mounted) {
        await _reportSavedChange(_text('节点已保存，点击“使用测试配置”开始测试',
            'Saved. Select Use test configuration to begin.'));
      }
    } catch (_) {
      if (mounted) {
        _message(_text('保存失败，请检查节点信息后重试',
            'Could not save. Check the node details and retry.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyAuto() async {
    final started = globalState.startTime;
    setState(() {
      _busy = true;
      _verification = '';
    });
    try {
      final response = await clashCore.streamingProbe(
          defaultTestUrl, fastCatAutoNode,
          followRedirects: false,
          timeout: const Duration(seconds: 18),
          maxBodySize: 1,
          phaseTiming: true);
      if (!mounted ||
          ref.read(currentProfileIdProvider) != fastCatAutoProfileId ||
          started != globalState.startTime ||
          ref.read(runTimeProvider) == null) {
        return;
      }
      final phases = response['phases'];
      final via = phases is Map ? phases['used-protocol'] : null;
      final ms = response['first-byte-ms'];
      if (response['ok'] != true ||
          response['status-code'] != 204 ||
          ms is! int ||
          (via != 'h2' && via != 'v1')) {
        throw StateError('Probe incomplete');
      }
      final name = via == 'h2' ? 'HTTP/2' : 'HTTPS v1';
      _verification = _text('已通过 $name 收到响应，首字节 $ms ms。',
          'Received a response via $name in $ms ms.');
      debugPrint('[FastCatAutoVerify] protocol=$via status=204 first_ms=$ms');
    } catch (_) {
      if (mounted) {
        _verification = _text('验证未完成，请检查连接后重试。',
            'Could not verify. Check the connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch({required bool restore, bool automatic = false}) async {
    setState(() => _busy = true);
    final old = ref.read(currentProfileIdProvider);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? next;
      final saved = ref.read(profilesProvider);
      final previousKey = automatic ? _autoPreviousKey : _previousKey;
      if (restore) {
        final previous = prefs.getString(previousKey);
        final candidates = saved
            .where((p) => automatic
                ? p.id != fastCatAutoProfileId
                : !isLocalFastCatProfile(p.id))
            .toList();
        for (final p in candidates) {
          if (p.id == previous) next = p.id;
        }
        next ??= candidates.isEmpty ? null : candidates.first.id;
        if (next == null) throw StateError('No previous profile');
      } else {
        if (automatic) {
          if (!FastCatTestProtocol.values.every((p) => saved
              .any((entry) => entry.id == p.profileId && entry.url.isEmpty))) {
            throw StateError('Missing local endpoints');
          }
          await resolveLocalAutoProfile(ProfileVault.instance.readText);
          await ProfileVault.instance
              .writeText(fastCatAutoProfileId, localAutoProfileMarker);
          final profile = Profile.normal(label: fastCatAutoNode).copyWith(
              id: fastCatAutoProfileId,
              autoUpdate: false,
              lastUpdateDate: DateTime.now(),
              currentGroupName: fastCatAutoGroup,
              selectedMap: {
                fastCatAutoGroup: fastCatAutoNode,
                'GLOBAL': fastCatAutoGroup
              });
          ref.read(profilesProvider.notifier).setProfile(profile);
          next = fastCatAutoProfileId;
        } else {
          if (_profile == null) throw StateError('No test profile');
          next = _protocol.profileId;
        }
        if (old != null &&
            (automatic || !isLocalFastCatProfile(old)) &&
            !await prefs.setString(previousKey, old)) {
          throw StateError('Cannot save previous profile');
        }
      }
      ref.read(currentProfileIdProvider.notifier).value = next;
      await ref.read(coreGatewayProvider).applyCurrentProfile();
      await globalState.appController.savePreferences();
      if (mounted && automatic && !restore) {
        _verification = '';
        _message(_text('已启用自动节点，返回首页即可连接。',
            'Automatic node selected. Connect from Home.'));
      } else if (mounted) {
        _message(_text(
            restore ? '已恢复原配置' : '已切换测试配置，请返回首页连接',
            restore
                ? 'Previous configuration restored.'
                : 'Test configuration selected. Connect from Home.'));
      }
    } catch (_) {
      ref.read(currentProfileIdProvider.notifier).value = old;
      var recovered = true;
      try {
        await ref.read(coreGatewayProvider).applyCurrentProfile();
      } catch (_) {
        recovered = false;
      }
      if (mounted) {
        _message(_text(
            recovered ? '切换失败，已保留原配置' : '切换失败，请断开后重新连接',
            recovered
                ? 'Switch failed. Previous configuration retained.'
                : 'Switch failed. Disconnect and reconnect.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(_text('删除测试节点？', 'Delete test node?')),
                content: Text(_text('将删除此节点及其认证令牌。',
                    'This removes the node and its authentication token.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(_text('取消', 'Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(_text('删除', 'Delete')))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await globalState.appController.deleteProfile(_protocol.profileId);
      await globalState.appController.savePreferences();
      _savedToken = '';
      _token.clear();
      if (mounted) {
        await _reportSavedChange(_text('测试节点已删除', 'Test node deleted.'));
      }
    } catch (_) {
      if (mounted) _message(_text('删除失败，请重试', 'Could not delete. Retry.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final saved = profiles.any((p) => p.id == _protocol.profileId);
    final currentId = ref.watch(currentProfileIdProvider);
    final active = currentId == _protocol.profileId;
    final autoActive = currentId == fastCatAutoProfileId;
    final bothSaved = FastCatTestProtocol.values.every((p) =>
        profiles.any((entry) => entry.id == p.profileId && entry.url.isEmpty));

    final disabled = _loading || _busy || active;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: XbUiTokens.pageBackground(context),
          appBar:
              AppBar(title: Text(_text('新协议测试节点', 'New protocol test node'))),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : autoActive
                  ? ListView(padding: const EdgeInsets.all(20), children: [
                      Text(_text('已启用自动节点，请在首页连接。',
                          'Automatic node selected. Connect from Home.')),
                      FilledButton(
                          onPressed: !_busy &&
                                  ref.watch(
                                      runTimeProvider.select((t) => t != null))
                              ? _verifyAuto
                              : null,
                          child:
                              Text(_text('验证当前自动节点', 'Verify automatic node'))),
                      if (_verification.isNotEmpty) Text(_verification),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _switch(restore: true, automatic: true),
                          child: Text(_text(
                              '恢复上一配置', 'Restore previous configuration'))),
                      if (_busy) const LinearProgressIndicator(),
                    ])
                  : Form(
                      key: _form,
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (_mobile && bothSaved) ...[
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _switch(
                                          restore: false, automatic: true),
                                  child: Text(_text(
                                      '启用自动连接', 'Use automatic connection'))),
                              const SizedBox(height: 16),
                            ],
                            if (_mobile)
                              SegmentedButton<FastCatTestProtocol>(
                                segments: const [
                                  ButtonSegment(
                                      value: FastCatTestProtocol.https,
                                      label: Text('HTTPS v1')),
                                  ButtonSegment(
                                      value: FastCatTestProtocol.h2,
                                      label: Text('HTTP/2')),
                                ],
                                selected: {_protocol},
                                onSelectionChanged:
                                    _busy ? null : _chooseProtocol,
                              )
                            else
                              Text(_text('单独保存测试配置。只有点击使用后才会切换线路。',
                                  'Save a separate test configuration. Your route changes only when you choose to use it.')),
                            if (_mobile && !bothSaved)
                              Text(_text('分别保存两个入口后可启用自动连接。',
                                  'Save both endpoints to enable automatic connection.')),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: _server,
                                enabled: !disabled,
                                autocorrect: false,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                    labelText: _text('服务器域名', 'Server domain')),
                                validator: (v) => FastCatTestNode.validServer(
                                        (v ?? '').trim())
                                    ? null
                                    : _text('请输入有效的服务器域名',
                                        'Enter a valid server domain')),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _port,
                                enabled: !disabled,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                    labelText: _text('端口', 'Port')),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  return n != null && n > 0 && n <= 65535
                                      ? null
                                      : _text('端口范围为 1–65535',
                                          'Use a port from 1 to 65535');
                                }),
                            const SizedBox(height: 16),
                            TextFormField(
                                controller: _token,
                                enabled: !disabled,
                                obscureText: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [],
                                keyboardType: TextInputType.visiblePassword,
                                decoration: InputDecoration(
                                    labelText:
                                        _text('认证令牌', 'Authentication token'),
                                    helperText: _savedToken.isEmpty
                                        ? (_protocol == FastCatTestProtocol.h2
                                            ? _text('输入 HTTP/2 服务端令牌',
                                                'Enter the HTTP/2 server token')
                                            : _text('输入 v1 服务端令牌',
                                                'Enter the v1 server token'))
                                        : _text('已保存；留空保留原令牌',
                                            'Saved. Leave blank to keep the current token.')),
                                validator: (v) => FastCatTestNode.validToken(
                                        (v ?? '').isEmpty ? _savedToken : v!)
                                    ? null
                                    : _text('请输入至少 24 位、不含空格的令牌',
                                        'Use at least 24 characters without spaces')),
                            const SizedBox(height: 20),
                            FilledButton(
                                onPressed: disabled ? null : _save,
                                child: Text(_text('保存节点', 'Save node'))),
                            if (saved) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _switch(restore: active),
                                  child: Text(_text(
                                      active ? '恢复原配置' : '使用测试配置',
                                      active
                                          ? 'Restore previous configuration'
                                          : 'Use test configuration'))),
                              TextButton(
                                  onPressed: _busy || active ? null : _delete,
                                  child: Text(
                                      _text('删除测试节点', 'Delete test node'))),
                            ],
                            if (_isIOS && saved && active && !_busy)
                              FastCatDeviceProbe(
                                  key: ValueKey(_protocol),
                                  nodeName: _protocol.node),
                            if (active)
                              Text(_text('当前正在使用测试配置。修改或删除前，请先恢复原配置。',
                                  'The test configuration is active. Restore your previous configuration before editing or deleting.')),
                            const SizedBox(height: 12),
                            Text(
                                _text('TLS 证书验证已开启，仅支持 TCP。',
                                    'TLS certificate verification is enabled. This version supports TCP only.'),
                                style: Theme.of(context).textTheme.bodySmall),
                            if (_busy)
                              const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: LinearProgressIndicator()),
                          ])),
        ));
  }
}
