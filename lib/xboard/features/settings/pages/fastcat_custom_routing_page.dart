import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/foundation.dart';
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
  late List<Rule> _initialRules;
  bool _useProxy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _rules = List.of(profile?.overrideData.rule.addedRules ?? const []);
    _initialRules = List.of(_rules);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  String _ruleFor(String input, String target) {
    final value = input.trim();
    final cidr = value.contains('/');
    final ip = InternetAddress.tryParse(value.split('/').first);
    if (ip != null) {
      if (cidr) {
        final prefix = int.tryParse(value.split('/').last);
        final maximum = ip.type == InternetAddressType.IPv6 ? 128 : 32;
        if (prefix == null || prefix < 0 || prefix > maximum) {
          throw const FormatException();
        }
      }
      final action =
          ip.type == InternetAddressType.IPv6 ? 'IP-CIDR6' : 'IP-CIDR';
      return '$action,$value,$target,no-resolve';
    }
    if (value.startsWith('+.')) {
      return 'DOMAIN-SUFFIX,${value.substring(2)},$target';
    }
    if (cidr || value.isEmpty || value.contains(RegExp(r'\s|[/,]'))) {
      throw const FormatException();
    }
    return 'DOMAIN-SUFFIX,$value,$target';
  }

  void _add(String? proxyTarget) {
    try {
      if (_useProxy && proxyTarget == null) {
        throw const FormatException();
      }
      final value =
          _ruleFor(_hostController.text, _useProxy ? proxyTarget! : 'DIRECT');
      if (_rules.any((rule) => rule.value == value)) return;
      setState(() {
        _rules.add(Rule.value(value));
        _hostController.clear();
      });
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的域名、IP 或 CIDR')),
      );
    }
  }

  bool get _hasUnsavedChanges => !listEquals(_rules, _initialRules);

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) return true;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text('未保存的修改', style: XbUiText.sectionTitle(dialogContext)),
        content: const Text('是否保存后返回？'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: XbUiButton.outlinedNeutral(dialogContext),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: XbUiButton.filledPrimary(dialogContext),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (save == true) await _save(close: false);
    return save != null;
  }

  Future<void> _save({bool close = true}) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;
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
    _initialRules = List.of(_rules);
    if (mounted && close) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final proxyGroups = ref.watch(currentGroupsStateProvider).value;
    final proxyTarget = proxyGroups.isEmpty ? null : proxyGroups.first.name;
    return WillPopScope(
      onWillPop: _confirmLeave,
      child: Scaffold(
        backgroundColor: XbUiTokens.pageBackground(context),
        appBar: AppBar(
          title: Text(chinese ? '自定义分流' : 'Custom routing'),
          backgroundColor: XbUiTokens.pageBackground(context),
          surfaceTintColor: Colors.transparent,
          actions: [
            TextButton(onPressed: _save, child: Text(chinese ? '保存' : 'Save')),
            const SizedBox(width: 8),
          ],
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
                          onPressed: () => _add(proxyTarget),
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
                          onPressed: () =>
                              setState(() => _rules.removeAt(entry.key)),
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
      ),
    );
  }
}
