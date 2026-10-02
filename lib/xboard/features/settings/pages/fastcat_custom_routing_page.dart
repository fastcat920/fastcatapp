import 'package:fl_clash/mihomo/mihomo.dart';
import '../utils/routing_rule.dart';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatCustomRoutingPage extends ConsumerStatefulWidget {
  const FastCatCustomRoutingPage({super.key});

  @override
  ConsumerState<FastCatCustomRoutingPage> createState() =>
      _FastCatCustomRoutingPageState();
}

class _FastCatCustomRoutingPageState
    extends ConsumerState<FastCatCustomRoutingPage> {
  final _hostController = TextEditingController();
  late List<Rule> _rules;
  String? _profileId;
  bool _useProxy = false;
  bool _isApplying = false;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _profileId = profile?.id;
    _rules = List.of(profile?.overrideData.rule.addedRules ?? const []);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _add(String? proxyTarget) async {
    if (_isApplying) return;
    try {
      if (_useProxy && proxyTarget == null) {
        throw const FormatException();
      }
      final value = buildRoutingRule(
          _hostController.text, _useProxy ? proxyTarget! : 'DIRECT');
      if (_rules.asMap().entries.any((entry) =>
          entry.key != _editingIndex &&
          sameRoutingDestination(entry.value.value, value))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_chinese
                  ? '此目标已有规则，请编辑原规则或调整顺序'
                  : 'A rule for this destination already exists. Edit it or change its order.')),
        );
        return;
      }
      final candidate = [..._rules];
      if (_editingIndex case final index?) {
        candidate[index] = Rule.value(value);
      } else {
        candidate.add(Rule.value(value));
      }
      if (await _applyRules(candidate) && mounted) {
        setState(() {
          _rules = candidate;
          _hostController.clear();
          _editingIndex = null;
        });
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_chinese
                  ? '请输入有效的域名、IP 或 CIDR'
                  : 'Enter a valid domain, IP address or CIDR.')),
        );
      }
    }
  }

  Future<bool> _applyRules(List<Rule> candidate) async {
    if (_isApplying) return false;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return false;
    setState(() => _isApplying = true);
    try {
      final updatedProfile = profile.copyWith(
        overrideData: profile.overrideData.copyWith(
          enable: profile.overrideData.enable || candidate.isNotEmpty,
          rule: profile.overrideData.rule.copyWith(
            type: OverrideRuleType.added,
            addedRules: candidate,
          ),
        ),
      );
      ref.read(profilesProvider.notifier).setProfile(updatedProfile);
      await ref.read(coreGatewayProvider).applyCurrentProfile();
      return ref.read(currentProfileIdProvider) == profile.id;
    } catch (_) {
      // 配置热更新失败时恢复上一份已知可用配置，避免 UI 显示已保存、
      // 实际核心仍运行旧规则的分裂状态。
      ref.read(profilesProvider.notifier).setProfile(profile);
      var restored = true;
      try {
        await ref.read(coreGatewayProvider).applyCurrentProfile();
      } catch (_) {
        restored = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restored
                ? (_chinese
                    ? '规则未生效，已恢复之前的配置'
                    : 'Rules could not be applied. The previous configuration was restored.')
                : (_chinese
                    ? '规则未生效；设置已还原，但内核恢复失败，请重新连接'
                    : 'Rules were not applied. Settings were restored but core recovery failed. Please reconnect.')),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _removeAt(int index) async {
    if (_isApplying) return;
    final candidate = [..._rules]..removeAt(index);
    if (await _applyRules(candidate) && mounted) {
      setState(() {
        _rules = candidate;
        _editingIndex = null;
        _hostController.clear();
      });
    }
  }

  Future<void> _move(int from, int to) async {
    if (_isApplying || to < 0 || to >= _rules.length) return;
    final candidate = [..._rules];
    candidate.insert(to, candidate.removeAt(from));
    if (await _applyRules(candidate) && mounted) {
      setState(() {
        _rules = candidate;
        _editingIndex = null;
        _hostController.clear();
      });
    }
  }

  void _edit(int index) {
    final parts = _rules[index].value.split(',');
    if (parts.length < 3) return;
    setState(() {
      _editingIndex = index;
      _hostController.text = parts[1];
      _useProxy = parts[2] != 'DIRECT';
    });
  }

  bool get _chinese => Localizations.localeOf(context).languageCode == 'zh';

  @override
  Widget build(BuildContext context) {
    ref.listen(currentProfileIdProvider, (_, next) {
      if (next == _profileId) return;
      final profile = ref.read(currentProfileProvider);
      setState(() {
        _profileId = next;
        _rules = List.of(profile?.overrideData.rule.addedRules ?? const []);
        _editingIndex = null;
        _hostController.clear();
      });
    });
    final chinese = _chinese;
    final proxyGroups = ref.watch(currentGroupsStateProvider).value;
    final preferredGroup = ref.watch(currentProfileProvider)?.currentGroupName;
    final proxyTarget = proxyGroups.isEmpty
        ? null
        : proxyGroups
                .where((group) => group.name == preferredGroup)
                .map((group) => group.name)
                .firstOrNull ??
            proxyGroups
                .where(
                    (group) => group.hidden != true && group.name != 'GLOBAL')
                .map((group) => group.name)
                .firstOrNull ??
            proxyGroups.first.name;
    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(chinese ? '自定义分流' : 'Custom routing'),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                chinese
                    ? '规则优先于订阅规则，域名默认包含所有子域名。'
                    : 'Rules take priority over subscription rules. Domains include subdomains.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    TextField(
                      controller: _hostController,
                      decoration: InputDecoration(
                        labelText:
                            chinese ? '域名、IP 或 CIDR' : 'Domain, IP or CIDR',
                        hintText: 'youtube.com / 8.8.8.8 / 1.1.1.0/24',
                      ),
                      onSubmitted: (_) => _add(proxyTarget),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: Text(!_useProxy ? '☑' : '☐',
                                  style: const TextStyle(fontSize: 18)),
                              label: Text(chinese ? '直连' : 'Direct',
                                  softWrap: false),
                            ),
                            ButtonSegment(
                              value: true,
                              enabled: proxyTarget != null,
                              icon: Text(_useProxy ? '☑' : '☐',
                                  style: const TextStyle(fontSize: 18)),
                              label: Text(chinese ? '代理' : 'Proxy',
                                  softWrap: false),
                            ),
                          ],
                          selected: {_useProxy},
                          onSelectionChanged: (value) =>
                              setState(() => _useProxy = value.first),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isApplying ? null : () => _add(proxyTarget),
                        icon: Icon(_editingIndex != null
                            ? Icons.save_outlined
                            : Icons.add),
                        label: Text(_editingIndex != null
                            ? (chinese ? '保存' : 'Save')
                            : (chinese ? '添加' : 'Add')),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              ..._rules.asMap().entries.map((entry) => Card(
                    child: ListTile(
                      title: Text(entry.value.value),
                      subtitle: Wrap(
                        children: [
                          IconButton(
                              tooltip: chinese ? '编辑' : 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed:
                                  _isApplying ? null : () => _edit(entry.key)),
                          IconButton(
                              tooltip: chinese ? '上移' : 'Move up',
                              icon: const Icon(Icons.arrow_upward),
                              onPressed: _isApplying || entry.key == 0
                                  ? null
                                  : () => _move(entry.key, entry.key - 1)),
                          IconButton(
                              tooltip: chinese ? '下移' : 'Move down',
                              icon: const Icon(Icons.arrow_downward),
                              onPressed:
                                  _isApplying || entry.key == _rules.length - 1
                                      ? null
                                      : () => _move(entry.key, entry.key + 1)),
                          IconButton(
                              tooltip: chinese ? '删除' : 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _isApplying
                                  ? null
                                  : () => _removeAt(entry.key)),
                        ],
                      ),
                    ),
                  )),
              if (_rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: Center(
                      child: Text(chinese ? '暂未添加规则' : 'No custom rules')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
