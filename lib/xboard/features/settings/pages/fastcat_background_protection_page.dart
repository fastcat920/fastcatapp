import 'dart:async';
import 'package:fl_clash/common/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

/// Power-policy checks are advisory: Android exposes no reliable OEM auto-start
/// grant, so we never label vendor protection as enabled based on navigation.
class FastCatBackgroundProtectionPage extends StatefulWidget {
  const FastCatBackgroundProtectionPage({super.key});

  @override
  State<FastCatBackgroundProtectionPage> createState() =>
      _FastCatBackgroundProtectionPageState();
}

class _FastCatBackgroundProtectionPageState
    extends State<FastCatBackgroundProtectionPage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('app');
  Map<String, dynamic>? _status;
  bool _unavailable = false;
  bool _opening = false;
  bool _refreshing = false;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool notify = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    var success = false;
    try {
      final status = await _channel
          .invokeMapMethod<String, dynamic>(
            'getBackgroundProtection',
          )
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _status = status;
        _unavailable = status == null;
        if (status != null) _lastChecked = DateTime.now();
      });
      success = status != null;
    } on PlatformException {
      if (mounted) {
        setState(() {
          _status = null;
          _unavailable = true;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _status = null;
          _unavailable = true;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _status = null;
          _unavailable = true;
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    if (notify && mounted) {
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(success
                ? (zh ? '状态已更新' : 'Status updated')
                : (zh
                    ? '检查失败，请重试'
                    : 'Unable to check status. Please try again.'))));
    }
  }

  Future<void> _open(String target) async {
    if (_opening) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'openBackgroundProtectionSettings',
        {'target': target},
      ).timeout(const Duration(seconds: 5));
      opened = response?['opened'] == true;
      if (mounted && opened && response?['route'] == 'app_details') {
        final zh = Localizations.localeOf(context).languageCode == 'zh';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(zh
                ? '已打开应用信息，请按本页说明查找对应设置。菜单名称可能因系统版本而异。'
                : 'App info opened. Follow this page’s instructions; menu names vary by system version.')));
      }
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    } on TimeoutException {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(zh
            ? '无法打开，请在系统设置中手动查找'
            : 'Open this option manually in system settings.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final brandName = localizedAppNameForLocale(
        Localizations.localeOf(context).toLanguageTag());
    final status = _status;
    final manufacturer =
        (status?['manufacturer'] as String? ?? '').toLowerCase();
    final family = status?['vendorFamily'] as String? ?? manufacturer;
    final unavailable = zh ? '状态暂不可用' : 'Status unavailable';
    String check(String key, String yes, String no) =>
        status?[key] is! bool || _unavailable
            ? unavailable
            : status![key] == true
                ? yes
                : no;
    final notificationText = status == null || _unavailable
        ? unavailable
        : status['appNotificationsEnabled'] == false
            ? (zh
                ? '应用通知已关闭，先开启通知总开关，再检查连接通知渠道。'
                : 'App notifications are off. Enable them first, then check the connection channel.')
            : status['notificationChannelExists'] == false
                ? (zh
                    ? '连接通知渠道尚未建立，连接一次后重新检查。'
                    : 'Connection channel not created yet. Connect once, then check again.')
                : check(
                    'notificationsEnabled',
                    zh ? '已允许' : 'Allowed',
                    zh
                        ? '连接通知已关闭，请在系统设置中开启。'
                        : 'Connection notifications are off. Enable them in system settings.');
    final guide = _vendorGuide(family, brandName, zh);
    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(title: Text(zh ? '连接保护' : 'Connection protection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(zh
              ? '部分手机会在划掉应用时强停 VPN。请按需检查以下设置；普通返回或切换应用不会主动断开连接。'
              : 'Some phones stop the VPN when the app is swiped away. Review these settings. Leaving the app normally does not disconnect it.'),
          if (manufacturer.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${status?['manufacturer']} · Android ${status?['androidVersion'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 16),
          Card(
              child: Column(children: [
            _tile(
                Icons.notifications_outlined,
                zh ? '连接通知' : 'Connection notification',
                notificationText,
                'notifications'),
            _tile(
                Icons.battery_saver_outlined,
                zh ? '电池优化' : 'Battery optimization',
                check(
                    'batteryExempt',
                    zh
                        ? '标准电池优化已豁免，仍需检查厂商后台管理。'
                        : 'Not optimized; check vendor background settings too.',
                    zh
                        ? '仍受电池优化限制，找到 $brandName 并允许后台运行'
                        : 'Optimized; find $brandName and allow background activity. This does not verify vendor restrictions.'),
                'battery'),
            _tile(
                Icons.settings_applications_outlined,
                zh ? '应用启动与后台运行' : 'App launch and background activity',
                '${zh ? '需手动确认' : 'Verify manually.'}\n$guide',
                'startup'),
          ])),
          if (status?['backgroundRestricted'] == true)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(zh
                    ? '系统当前限制了此应用的后台运行，请同时检查应用电池设置。'
                    : 'The system currently restricts this app in the background.')),
          const SizedBox(height: 16),
          Text(zh
              ? '最近任务锁定：需手动确认。若手机仍会清理 VPN，可在最近任务中锁定 $brandName（如系统支持）。电池设置与厂商启动管理是不同的限制；打开设置页不代表已经获得保护。系统强行停止整个应用后，客户端无法保证自行恢复，请重新打开并连接。'
              : 'Recent-app lock: verify manually. If the phone still stops the VPN, lock $brandName in recent apps if supported. Battery optimization and vendor launch management are separate restrictions. Opening a settings page does not grant protection. After the system force-stops the app, recovery cannot be guaranteed; reopen and connect.'),
          if (_lastChecked != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${zh ? '最近检查' : 'Last checked'}: ${_lastChecked!.hour.toString().padLeft(2, '0')}:${_lastChecked!.minute.toString().padLeft(2, '0')}:${_lastChecked!.second.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                )),
          OutlinedButton.icon(
            onPressed: _refreshing ? null : () => _refresh(notify: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(_refreshing
                ? (zh ? '正在检查…' : 'Checking…')
                : (zh ? '重新检查状态' : 'Refresh status')),
          ),
        ],
      ),
    );
  }

  String _vendorGuide(String family, String app, bool zh) {
    switch (family) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return zh
            ? '找到 $app，允许后台自启动，并将应用省电策略设为“无限制”。MIUI 与澎湃 OS 的入口可能不同。'
            : 'Find $app, allow background autostart, and select No restrictions for battery use. MIUI and HyperOS menus may differ.';
      case 'honor':
      case 'huawei':
        return zh
            ? '进入启动管理，找到 $app，关闭自动管理并允许自启动、关联启动和后台活动。'
            : 'In launch management, find $app, disable automatic management, and allow auto-launch, secondary launch and background activity.';
      case 'oppo':
      case 'oneplus':
      case 'realme':
        return zh
            ? '找到 $app，检查自启动、关联启动与允许后台活动。ColorOS、氢／氧 OS 和 realme UI 的名称可能不同。'
            : 'Find $app and check auto-launch, secondary launch and background activity. Names vary across ColorOS, OxygenOS and realme UI.';
      case 'vivo':
      case 'iqoo':
        return zh
            ? '找到 $app，允许自启动，并在后台耗电管理中允许后台运行。菜单名称因 OriginOS 或 Funtouch OS 而异。'
            : 'Find $app, allow autostart and background activity in battery management. Names vary across OriginOS and Funtouch OS.';
      case 'samsung':
        return zh
            ? '在 $app 的电池设置中允许后台运行，并检查是否被加入休眠或深度休眠应用。可将其加入不休眠应用。'
            : 'Allow background use for $app. Check Sleeping and Deep sleeping apps, and use Never sleeping apps if available.';
      default:
        return zh
            ? '在应用设置中找到 $app，允许后台运行；如有自启动开关，请一并检查。此设置无法自动核实。'
            : 'Find $app in app settings, allow background activity, and check any autostart option. These settings cannot be verified automatically.';
    }
  }

  Widget _tile(IconData icon, String title, String subtitle, String target) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _opening ? null : () => _open(target),
      );
}
