import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
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
  bool _useProxy = false;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _rules = List.of(profile?.overrideData.rule.addedRules ?? const []);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  String _ruleFor(String input, String target) {
    final value = input.trim();
    final parts = value.split('/');
    if (parts.length > 2) throw const FormatException();
    final cidr = parts.length == 2;
    final ip = InternetAddress.tryParse(parts.first);
    if (ip != null) {
      if (cidr) {
        final prefix = int.tryParse(parts.last);
        final maximum = ip.type == InternetAddressType.IPv6 ? 128 : 32;
        if (prefix == null || prefix < 0 || prefix > maximum) {
          throw const FormatException();
        }
      }
      final action =
          ip.type == InternetAddressType.IPv6 ? 'IP-CIDR6' : 'IP-CIDR';
      return '$action,$value,$target,no-resolve';
    }
    final domain = value.startsWith('+.') ? value.substring(2) : value;
    if (cidr ||
        domain.isEmpty ||
        domain.contains(RegExp(r'\s|[/,]')) ||
        !_isValidDomain(domain)) {
      throw const FormatException();
    }
    return 'DOMAIN-SUFFIX,$domain,$target';
  }

  bool _isValidDomain(String value) {
    if (value.length > 253 || !value.contains('.')) return false;
    return value.split('.').every((label) =>
        label.isNotEmpty &&
        label.length <= 63 &&
        RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$').hasMatch(label));
  }

  Future<void> _add(String? proxyTarget) async {
    if (_isApplying) return;
    try {
      if (_useProxy && proxyTarget == null) {
        throw const FormatException();
      }
      final value =
          _ruleFor(_hostController.text, _useProxy ? proxyTarget! : 'DIRECT');
      if (_rules.any((rule) => rule.value == value)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该规则已存在')),
        );
        return;
      }
      setState(() {
        _rules.add(Rule.value(value));
        _hostController.clear();
      });
      await _applyRules();
      if (!mounted) return;
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的域名、IP 或 CIDR')),
        );
      }
    }
  }

  Future<void> _applyRules() async {
    if (_isApplying) return;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
    setState(() => _isApplying = true);
    try {
      ref.read(profilesProvider.notifier).setProfile(profile.copyWith(
            overrideData: profile.overrideData.copyWith(
              enable: _rules.isNotEmpty,
              rule: profile.overrideData.rule.copyWith(
                type: OverrideRuleType.added,
                addedRules: _rules,
              ),
            ),
          ));
      await globalState.appController.updateClashConfig();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('规则保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _removeAt(int index) async {
    if (_isApplying) return;
    setState(() => _rules.removeAt(index));
    await _applyRules();
  }

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final proxyGroups = ref.watch(currentGroupsStateProvider).value;
    final proxyTarget = proxyGroups.isEmpty ? null : proxyGroups.first.name;
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
                        icon: const Icon(Icons.add),
                        label: Text(chinese ? '添加' : 'Add'),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              ..._rules.asMap().entries.map((entry) => Card(
                    child: ListTile(
                      title: Text(entry.value.value),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed:
                            _isApplying ? null : () => _removeAt(entry.key),
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
