import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatDnsSettingsPage extends ConsumerWidget {
  const FastCatDnsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overrideDns = ref.watch(overrideDnsProvider);
    final vpnSetting = ref.watch(vpnSettingProvider);
    final dns =
        ref.watch(patchClashConfigProvider.select((state) => state.dns));
    if (overrideDns && !dns.enable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _update(
          ref,
          (state) => state.copyWith.dns(enable: true),
        );
      });
    }

    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: const Text('DNS'),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => _confirmReset(context, ref),
            icon: const Icon(Icons.restart_alt_outlined),
            label: Text(_isChinese(context) ? '重置' : 'Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _section(context, l10n.options),
              _DnsCard(
                children: [
                  SwitchListTile(
                    secondary: const _DnsIcon(Icons.public_outlined),
                    title:
                        Text(_isChinese(context) ? 'IPv6 流量' : 'IPv6 traffic'),
                    subtitle: Text(_isChinese(context)
                        ? '允许 VPN/TUN 接收并转发 IPv6 流量'
                        : 'Allow VPN/TUN to receive and forward IPv6 traffic'),
                    value: vpnSetting.ipv6,
                    onChanged: (value) => ref
                        .read(vpnSettingProvider.notifier)
                        .updateState((state) => state.copyWith(ipv6: value)),
                  ),
                  SwitchListTile(
                    secondary: const _DnsIcon(Icons.layers_outlined),
                    title: Text(l10n.overrideDns),
                    subtitle: Text(l10n.overrideDnsDesc),
                    value: overrideDns,
                    onChanged: (value) {
                      if (value) {
                        _update(
                          ref,
                          (state) => state.copyWith.dns(enable: true),
                        );
                      }
                      ref.read(overrideDnsProvider.notifier).value = value;
                    },
                  ),
                  SwitchListTile(
                    secondary: const _DnsIcon(Icons.language_outlined),
                    title: const Text('DNS IPv6'),
                    subtitle: Text(_isChinese(context)
                        ? '允许 DNS 返回 IPv6（AAAA）解析结果'
                        : 'Allow DNS to return IPv6 (AAAA) records'),
                    value: dns.ipv6,
                    onChanged: overrideDns
                        ? (value) => _update(
                              ref,
                              (state) => state.copyWith.dns(ipv6: value),
                            )
                        : null,
                  ),
                  XbPointerCursor(
                    enabled: overrideDns,
                    child: ListTile(
                      leading: const _DnsIcon(Icons.route_outlined),
                      title: Text(l10n.dnsMode),
                      subtitle: Text(_modeLabel(dns.enhancedMode)),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: overrideDns,
                      onTap: overrideDns
                          ? () => _chooseMode(context, ref, dns.enhancedMode)
                          : null,
                    ),
                  ),
                ],
              ),
              _section(context, _isChinese(context) ? '服务器' : 'Servers'),
              _DnsCard(
                children: [
                  _serverTile(
                    context,
                    title: l10n.nameserver,
                    subtitle: l10n.nameserverDesc,
                    values: dns.nameserver,
                    enabled: overrideDns,
                    onChanged: (values) => _update(
                      ref,
                      (state) => state.copyWith.dns(nameserver: values),
                    ),
                  ),
                  _serverTile(
                    context,
                    title: l10n.proxyNameserver,
                    subtitle: l10n.proxyNameserverDesc,
                    values: dns.proxyServerNameserver,
                    enabled: overrideDns,
                    onChanged: (values) => _update(
                      ref,
                      (state) =>
                          state.copyWith.dns(proxyServerNameserver: values),
                    ),
                  ),
                  _serverTile(
                    context,
                    title: l10n.defaultNameserver,
                    subtitle: l10n.defaultNameserverDesc,
                    values: dns.defaultNameserver,
                    enabled: overrideDns,
                    onChanged: (values) => _update(
                      ref,
                      (state) => state.copyWith.dns(defaultNameserver: values),
                    ),
                  ),
                  _serverTile(
                    context,
                    title: l10n.fallback,
                    subtitle: l10n.fallbackDesc,
                    values: dns.fallback,
                    enabled: overrideDns,
                    onChanged: (values) => _update(
                      ref,
                      (state) => state.copyWith.dns(fallback: values),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                child: Text(
                  _isChinese(context)
                      ? '每行填写一个 DNS 地址，支持普通 DNS、DoH 和 DoT 地址。修改将在下次重新连接时完整生效。'
                      : 'Enter one DNS address per line. Plain DNS, DoH and DoT are supported. Changes fully apply after reconnecting.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isChinese(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  static Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(
          text,
          style: XbUiText.cardTitle(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  static void _update(
    WidgetRef ref,
    ClashConfig Function(ClashConfig state) update,
  ) {
    ref.read(patchClashConfigProvider.notifier).updateState(update);
  }

  static Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(_isChinese(context) ? '恢复初始设置？' : 'Restore defaults?'),
        content: Text(
          _isChinese(context)
              ? '将重置 IPv6 流量、DNS 覆盖开关、DNS IPv6、解析模式和全部 DNS 服务器地址。'
              : 'This resets IPv6 traffic, DNS override, DNS IPv6, DNS mode, and all DNS server addresses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_isChinese(context) ? '确认恢复' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    ref.read(vpnSettingProvider.notifier).updateState(
          (state) => state.copyWith(ipv6: defaultVpnProps.ipv6),
        );
    ref.read(overrideDnsProvider.notifier).value = false;
    _update(ref, (state) => state.copyWith(dns: defaultDns));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isChinese(context)
              ? 'DNS 已恢复初始设置，重新连接后完整生效'
              : 'DNS defaults restored. Reconnect to apply all changes.',
        ),
      ),
    );
  }

  static String _modeLabel(DnsMode mode) => switch (mode) {
        DnsMode.fakeIp => 'Fake-IP',
        DnsMode.redirHost => 'Redir-Host',
        DnsMode.normal => 'Normal',
        DnsMode.hosts => 'Hosts',
      };

  static Future<void> _chooseMode(
    BuildContext context,
    WidgetRef ref,
    DnsMode current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<DnsMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(l10n.dnsMode),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DnsMode.values
                .map(
                  (mode) => XbPointerCursor(
                    child: ListTile(
                      leading: Icon(
                        mode == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: mode == current
                            ? Theme.of(dialogContext).colorScheme.primary
                            : null,
                      ),
                      title: Text(_modeLabel(mode)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => Navigator.pop(dialogContext, mode),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (selected == null) return;
    _update(
      ref,
      (state) => state.copyWith.dns(enhancedMode: selected),
    );
  }

  static Widget _serverTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> values,
    required bool enabled,
    required ValueChanged<List<String>> onChanged,
  }) {
    return XbPointerCursor(
      enabled: enabled,
      child: ListTile(
        leading: const _DnsIcon(Icons.storage_outlined),
        title: Text(title),
        subtitle: Text(
          values.isEmpty ? subtitle : values.join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: enabled
            ? () => _editServers(
                  context,
                  title: title,
                  values: values,
                  onChanged: onChanged,
                )
            : null,
      ),
    );
  }

  static Future<void> _editServers(
    BuildContext context, {
    required String title,
    required List<String> values,
    required ValueChanged<List<String>> onChanged,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: values.join('\n'));
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'https://dns.alidns.com/dns-query\n1.1.1.1',
              helperText: _isChinese(context)
                  ? '每行一个地址，空行会被忽略'
                  : 'One address per line; empty lines are ignored',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final entries = controller.text
                  .split(RegExp(r'[\r\n]+'))
                  .map((entry) => entry.trim())
                  .where((entry) => entry.isNotEmpty)
                  .toSet()
                  .toList();
              Navigator.pop(dialogContext, entries);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) onChanged(result);
  }
}

class _DnsCard extends StatelessWidget {
  const _DnsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: XbUiCardStyle.elevation(context),
      shadowColor: XbUiCardStyle.shadowColor(context),
      color: XbUiCardStyle.background(context),
      shape: XbUiCardStyle.shape(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 68,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }
}

class _DnsIcon extends StatelessWidget {
  const _DnsIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 22,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
