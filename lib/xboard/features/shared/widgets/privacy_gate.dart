import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legal_footer.dart';

/// Display before mounting the signed-in application (and its auto-connect
/// lifecycle). This acknowledgement is not a replacement for a legal policy.
class PrivacyGate extends StatefulWidget {
  const PrivacyGate(
      {super.key,
      required this.preferences,
      required this.child,
      this.localeTag});
  final SharedPreferences preferences;
  final Widget child;
  final String? localeTag;
  static const preferenceKey = 'fastcat.privacy-disclosure';
  static const legacyApplePreferenceKey = 'fastcat.apple.privacy-disclosure';
  static const version = '2026-10-v1';

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> with WidgetsBindingObserver {
  late bool _accepted;
  bool _saving = false;
  bool _declined = false;
  String? _error;
  bool get _chinese {
    final configured = widget.localeTag;
    final language = configured != null && configured.isNotEmpty
        ? configured.replaceAll('_', '-').split('-').first
        : WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return language.toLowerCase() == 'zh';
  }

  @override
  void initState() {
    super.initState();
    final acceptedVersion =
        widget.preferences.getString(PrivacyGate.preferenceKey) ??
            widget.preferences.getString(PrivacyGate.legacyApplePreferenceKey);
    _accepted = acceptedVersion == PrivacyGate.version;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted && (widget.localeTag == null || widget.localeTag!.isEmpty)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String copy(String zh, String en) => _chinese ? zh : en;

  Future<void> _continue() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.preferences
          .setString(PrivacyGate.preferenceKey, PrivacyGate.version);
      if (!saved) throw StateError('Acknowledgement not saved');
      if (mounted) setState(() => _accepted = true);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = copy('无法保存，请重试。', 'Unable to save. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(Future<bool> Function() launch) async {
    try {
      if (await launch()) return;
    } catch (_) {/* Show a readable error, not a URL or platform exception. */}
    if (mounted) {
      setState(() => _error = copy('无法打开页面，请检查网络后重试。',
          'Unable to open the page. Check your network and try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xff2c4c96)),
      home: Scaffold(
        appBar: AppBar(title: Text(copy('VPN 数据使用说明', 'VPN Data Use'))),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(
                copy('使用 FastCat 前，请了解以下信息。',
                    'Before using FastCat, please review how the service handles data.'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Text(
                copy(
                    '账号与设备：邮箱、账号标识、设备标识及设备信息用于登录、设备数量限制和会话管理。\n\n套餐与订单：套餐、流量用量和订单信息用于提供服务及核对付款。\n\nVPN 流量：连接时，客户端和所选节点会处理目标地址、DNS 查询及网络流量，以完成转发和分流。\n\n诊断与客服：网络检测会联系检测服务；提交诊断报告、客服消息或附件时，相应信息会发送给所选服务。请勿提交密码或其他敏感信息。\n\n详细的数据收集、保存、第三方处理和删除规则，请阅读隐私政策。',
                    'Account and devices: Your email, account identifier, device identifier and device information support sign-in, device limits and session management.\n\nPlans and orders: Plan details, traffic usage and order information support service delivery and payment verification.\n\nVPN traffic: While connected, the client and selected server process destination addresses, DNS queries and network traffic to route your connections.\n\nDiagnostics and support: Network checks contact testing services. When you submit diagnostic reports, support messages or attachments, that information is sent to the selected service. Do not submit passwords or other sensitive information.\n\nRead the Privacy Policy for the detailed collection, retention, third-party processing and deletion rules.'),
                style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),
            _buttonPair(
              TextButton(
                  onPressed: () => _open(FastCatLegalLinks.openPrivacyPolicy),
                  child: Text(copy('阅读隐私政策', 'Read Privacy Policy'),
                      textAlign: TextAlign.center)),
              TextButton(
                  onPressed: () => _open(FastCatLegalLinks.openTermsOfService),
                  child: Text(copy('阅读服务条款', 'Read Terms of Service'),
                      textAlign: TextAlign.center)),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_declined)
              Text(copy('你可以关闭应用；在继续之前不会进入登录或连接界面。',
                  'You may close the app. Sign-in and connection screens remain unavailable until you continue.')),
            const SizedBox(height: 16),
            _buttonPair(
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB3261E)),
                  onPressed:
                      _saving ? null : () => setState(() => _declined = true),
                  child: Text(copy('暂不使用', 'Not now'),
                      textAlign: TextAlign.center)),
              FilledButton(
                  onPressed: _saving ? null : _continue,
                  child: Text(copy('同意并继续', 'Agree and Continue'),
                      textAlign: TextAlign.center)),
            ),
          ]),
        ))),
      ),
    );
  }

  Widget _buttonPair(Widget left, Widget right) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: left)),
          const SizedBox(width: 12),
          Expanded(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: right)),
        ]),
      );
}
