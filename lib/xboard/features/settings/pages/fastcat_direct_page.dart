import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/security/local_test_profile_scope.dart';
import 'package:fl_clash/security/profile_vault.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fastcat_direct_node.dart';
import 'fastcat_v2_status_page.dart';

const _iosECHTrial = bool.fromEnvironment('FASTCAT_IOS_ECH_TRIAL');

bool get showFastCatDirect =>
    (kDebugMode && Platform.isAndroid) ||
    (Platform.isIOS && (kDebugMode || (kProfileMode && _iosECHTrial)));

class FastCatDirectPage extends ConsumerStatefulWidget {
  const FastCatDirectPage({super.key});
  @override
  ConsumerState<FastCatDirectPage> createState() => _DirectState();
}

class _DirectState extends ConsumerState<FastCatDirectPage> {
  static const _previousKey = 'fastcat_v2_direct_previous_profile';
  final _domain = TextEditingController(text: 'zlhk.fastcat.ink');
  final _h2Port = TextEditingController(text: '18445');
  final _h3Port = TextEditingController(text: '18445');
  final _h2Token = TextEditingController();
  final _h3Token = TextEditingController();
  String? _caPem, _entryDoH, _entryDoHIP;
  bool _busy = true;
  String _notice = '';

  bool get _selected =>
      ref.read(currentProfileIdProvider) == fastCatDirectProfileId;
  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    if (showFastCatDirect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initialize();
      });
    }
  }

  Future<File> _caFile() async =>
      File(p.join(await appPath.homeDirPath, 'fastcat-local-direct-v2-ca.pem'));

  void _populate(FastCatDirectNode n) {
    _domain.text = n.server;
    _h2Port.text = n.port.toString();
    _h3Port.text = n.h3Port.toString();
    _h2Token.text = n.token;
    _h3Token.text = n.h3Token;
    _caPem = n.caPem;
    _entryDoH = n.entryDoH;
    _entryDoHIP = n.entryDoHIP;
  }

  Future<FastCatDirectNode> _readFile(File file) async {
    if (await file.length() > FastCatDirectNode.maxBytes) {
      throw const FormatException('File too large');
    }
    return FastCatDirectNode.parse(await file.readAsString());
  }

  Future<void> _initialize() async {
    try {
      final temp = await getTemporaryDirectory();
      final handoff = File(p.join(temp.path, 'fastcat-v2-direct-import.json'));
      if (await handoff.exists()) {
        if (_selected && ref.read(runTimeProvider) != null) {
          _notice = _text('请断开后重新打开此页，载入 USB 节点文件。',
              'Disconnect and reopen this page to load the USB node.');
          return;
        }
        try {
          final node = await _readFile(handoff);
          if (mounted) {
            _populate(node);
            _notice = _text('已从 USB 载入节点。', 'Node loaded from USB.');
          }
        } finally {
          await handoff.delete();
        }
        return;
      }
      if (!mounted ||
          !ref
              .read(profilesProvider)
              .any((p) => p.id == fastCatDirectProfileId)) {
        return;
      }
      final cfg = jsonDecode(
          await ProfileVault.instance.readText(fastCatDirectProfileId));
      final proxy = Map<String, dynamic>.from((cfg['proxies'] as List).single);
      proxy.remove('sni');
      if (proxy['type'] == 'fastcat-auto-ech') proxy['type'] = 'fastcat-auto';
      final path = proxy.remove('ca-file');
      if (path != null) {
        final trusted = await _caFile();
        if (trusted.path != path) {
          throw const FormatException('Invalid CA path');
        }
        proxy['ca-pem'] = await trusted.readAsString();
      }
      final node = FastCatDirectNode.parse(jsonEncode(proxy));
      if (mounted) _populate(node);
    } catch (_) {
      if (mounted) {
        _notice = _text(
            '节点文件读取失败，请重新导入。', 'Could not read the node. Import it again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final source = result.files.single.path;
    if (source == null) throw const FormatException('Missing file');
    final file = File(source);
    final temp = await getTemporaryDirectory();
    try {
      final node = await _readFile(file);
      if (mounted) {
        _populate(node);
        _notice = _text('已载入节点。', 'Node loaded.');
      }
    } finally {
      // Android file_picker 8 copies content URIs here. Retire only our copy.
      if (p.isWithin(p.join(temp.path, 'file_picker'), p.normalize(source)) &&
          await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _restore(SharedPreferences prefs) async {
    if (!_selected) return;
    final id = prefs.getString(_previousKey);
    final previous =
        id != null && ref.read(profilesProvider).any((p) => p.id == id)
            ? id
            : null;
    ref.read(currentProfileIdProvider.notifier).value = previous;
    await globalState.appController.savePreferences();
    if (previous != null) {
      await globalState.appController.applyProfile(silence: true);
    }
    await prefs.remove(_previousKey);
  }

  Future<void> _connect() async {
    final node = FastCatDirectNode.parse(jsonEncode({
      'type': 'fastcat-auto',
      'udp': true,
      'server': _domain.text.trim(),
      'port': int.tryParse(_h2Port.text.trim()),
      'h3-port': int.tryParse(_h3Port.text.trim()),
      'token': _h2Token.text,
      'h3-token': _h3Token.text,
      if (_caPem != null) 'ca-pem': _caPem,
      if (_entryDoH != null) 'entry-doh': _entryDoH,
      if (_entryDoHIP != null) 'entry-doh-ip': _entryDoHIP,
    }));
    final controller = globalState.appController;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final epoch = ref.read(sessionEpochProvider);
    await controller.runProfileImport(() async {
      if (!mounted || ref.read(runTimeProvider) != null) {
        throw StateError('VPN is already running');
      }
      final old = ref.read(currentProfileIdProvider);
      final ca = await _caFile();
      if (node.caPem != null) {
        final staged = File('${ca.path}.new');
        await staged.writeAsString(node.caPem!, flush: true);
        await staged.rename(ca.path);
      }
      final profile = Profile.normal(label: fastCatDirectNodeName).copyWith(
        id: fastCatDirectProfileId,
        autoUpdate: false,
        lastUpdateDate: DateTime.now(),
        currentGroupName: fastCatDirectGroup,
        selectedMap: {
          'GLOBAL': fastCatDirectGroup,
          fastCatDirectGroup: fastCatDirectNodeName
        },
      );
      await ProfileVault.instance.writeText(
          profile.id,
          node.configuration(
              privateCAPath: node.caPem != null ? ca.path : null));
      if (node.caPem == null && await ca.exists()) await ca.delete();
      if (old != fastCatDirectProfileId) {
        final ok = old == null
            ? await prefs.remove(_previousKey)
            : await prefs.setString(_previousKey, old);
        if (!ok) throw StateError('Previous selection could not be saved');
      }
      if (!mounted || ref.read(sessionEpochProvider) != epoch) {
        throw StateError('Session changed');
      }
      ref.read(profilesProvider.notifier).setProfile(profile);
      ref.read(currentProfileIdProvider.notifier).value = profile.id;
      try {
        await controller.applyProfile(silence: true);
        if (!mounted || !_selected || ref.read(sessionEpochProvider) != epoch) {
          throw StateError('Selection changed');
        }
        await controller.savePreferences();
        await controller.restoreProfileConnection();
      } catch (_) {
        if (mounted && _selected && ref.read(sessionEpochProvider) == epoch) {
          await _restore(prefs);
        }
        rethrow;
      }
    });
  }

  Future<void> _disconnect() async {
    if (!_selected) return;
    if (ref.read(runTimeProvider) != null &&
        !await globalState.appController.updateStatus(false)) {
      throw StateError('Could not stop VPN');
    }
    final prefs = await SharedPreferences.getInstance();
    await globalState.appController.runProfileImport(() async {
      if (mounted && _selected) await _restore(prefs);
    });
  }

  Future<void> _forget() async {
    final controller = globalState.appController;
    await controller.runProfileImport(() async {
      if (_selected) return;
      await controller.deleteProfile(fastCatDirectProfileId);
      await controller.savePreferences();
      final ca = await _caFile();
      if (await ca.exists()) await ca.delete();
    });
    if (mounted) {
      _h2Token.clear();
      _h3Token.clear();
      _caPem = null;
      _entryDoH = null;
      _entryDoHIP = null;
      _notice = _text('已删除直连节点。', 'Direct node removed.');
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    if (!showFastCatDirect || _busy) return;
    setState(() {
      _busy = true;
      _notice = '';
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        _notice = e is FormatException
            ? _text('请检查域名、端口和两个令牌，或重新选择节点文件。',
                'Check the domain, ports and both tokens, or select the node file again.')
            : _text('操作未完成，请检查 VPN 状态和节点配置。',
                'Could not finish. Check the VPN state and node configuration.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_domain, _h2Port, _h3Port, _h2Token, _h3Token]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!showFastCatDirect) return const SizedBox.shrink();
    final active =
        ref.watch(currentProfileIdProvider) == fastCatDirectProfileId;
    final saved =
        ref.watch(profilesProvider).any((v) => v.id == fastCatDirectProfileId);
    final running = ref.watch(runTimeProvider) != null;
    final editable = !_busy && !running;
    Widget field(String label, TextEditingController c,
            {bool secret = false, bool numeric = false}) =>
        TextField(
            controller: c,
            enabled: editable,
            obscureText: secret,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [],
            keyboardType: numeric
                ? TextInputType.number
                : (secret ? TextInputType.visiblePassword : TextInputType.url),
            decoration: InputDecoration(labelText: label));

    return PopScope(
        canPop: !_busy,
        child: Scaffold(
            appBar: AppBar(
                title: Text(_text('FastCat v2 直连', 'FastCat v2 Direct'))),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              OutlinedButton.icon(
                  onPressed: editable ? () => _run(_pick) : null,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(_text('导入节点文件', 'Import node file'))),
              field(_text('服务器域名', 'Server domain'), _domain),
              field(_text('HTTP/2 端口', 'HTTP/2 port'), _h2Port, numeric: true),
              field(_text('HTTP/3 端口', 'HTTP/3 port'), _h3Port, numeric: true),
              field(_text('HTTP/2 令牌', 'HTTP/2 token'), _h2Token, secret: true),
              field(_text('HTTP/3 令牌', 'HTTP/3 token'), _h3Token, secret: true),
              if (_caPem != null)
                Text(_text('此节点使用导入的测试 CA 验证服务器身份。',
                    'This node verifies the server with the imported test CA.')),
              if (running && !active)
                Text(_text('请先断开当前 VPN，再测试直连。',
                    'Disconnect the current VPN before testing.')),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: editable
                      ? () => _run(_connect)
                      : (running && active && !_busy
                          ? () => _run(_disconnect)
                          : null),
                  child: Text(running && active
                      ? _text('断开并恢复原配置', 'Disconnect and restore')
                      : _text('连接', 'Connect'))),
              if (active && !running)
                TextButton(
                    onPressed: _busy ? null : () => _run(_disconnect),
                    child:
                        Text(_text('恢复原配置', 'Restore previous configuration'))),
              if (active && running)
                OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FastCatV2StatusPage())),
                    child: Text(_text('查看连接状态', 'Connection status'))),
              if (saved && !active)
                TextButton(
                    onPressed: _busy ? null : () => _run(_forget),
                    child:
                        Text(_text('删除已保存的直连节点', 'Remove saved direct node'))),
              if (_busy) const LinearProgressIndicator(),
              if (_notice.isNotEmpty) Text(_notice),
            ])));
  }
}
