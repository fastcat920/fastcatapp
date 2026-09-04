import 'package:fl_clash/xboard/features/shared/widgets/legal_footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows Apple's required VPN data-use disclosure before the first user-
/// initiated connection on iOS.
abstract final class IosVpnPrivacyNotice {
  static const String _currentVersion = '2026-09';
  static const String _acceptedVersionKey =
      'fastcat_ios_vpn_privacy_notice_accepted_version';

  static Future<bool> ensureAccepted(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      // The disclosure can still be shown if local storage is unavailable.
    }
    if (preferences?.getString(_acceptedVersionKey) == _currentVersion) {
      return true;
    }
    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _VpnPrivacyNoticeDialog(),
        ) ??
        false;
    if (!accepted) return false;

    // A failed local write should not block the connection the user just
    // approved. It only means the notice will be shown again next time.
    try {
      await preferences?.setString(_acceptedVersionKey, _currentVersion);
    } catch (_) {
      // The notice will be shown again on the next connection attempt.
    }
    return true;
  }
}

class _VpnPrivacyNoticeDialog extends StatelessWidget {
  const _VpnPrivacyNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(
          Icons.shield_outlined,
          color: colorScheme.primary,
        ),
        title: Text(
          chinese ? 'VPN 数据与隐私说明' : 'VPN Data & Privacy Notice',
          textAlign: TextAlign.center,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chinese
                      ? '在连接 VPN 前，请了解 FastCat 为提供服务会处理以下数据：'
                      : 'Before connecting, please review the data FastCat handles to provide the VPN service:',
                ),
                const SizedBox(height: 14),
                _NoticeItem(
                  title: chinese ? '账户与服务信息' : 'Account and service data',
                  body: chinese
                      ? '邮箱、账户与订阅状态、套餐流量及订单记录，用于验证账户并确认服务资格。'
                      : 'Email, account and subscription status, plan usage, and order records are used to authenticate your account and confirm service eligibility.',
                ),
                const SizedBox(height: 12),
                _NoticeItem(
                  title: chinese ? '设备信息' : 'Device data',
                  body: chinese
                      ? '随机设备标识、设备名称、系统及应用版本，用于设备管理、安全保护和兼容性诊断。'
                      : 'A random device identifier, device name, OS version, and app version are used for device management, security, and compatibility diagnostics.',
                ),
                const SizedBox(height: 12),
                _NoticeItem(
                  title: chinese ? 'VPN 连接信息' : 'VPN connection data',
                  body: chinese
                      ? '建立 VPN 连接时，服务端会处理提供连接、安全保护和排查故障所必需的网络请求与连接信息。'
                      : 'When a VPN connection is established, our service processes the network request and connection information necessary to provide, secure, and troubleshoot the connection.',
                ),
                const SizedBox(height: 14),
                Text(
                  chinese
                      ? '这些信息仅用于提供和保护服务、管理设备及排查故障，不用于广告追踪或出售。'
                      : 'This information is used only to provide and secure the service, manage devices, and troubleshoot issues. It is not used for advertising tracking or sold.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: FastCatLegalLinks.openPrivacyPolicy,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    chinese ? '查看完整隐私政策' : 'View the full Privacy Policy',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(chinese ? '暂不使用' : 'Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(chinese ? '同意并继续' : 'Agree & Continue'),
          ),
        ],
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text:
                      '$title${Localizations.localeOf(context).languageCode == 'zh' ? '：' : ': '}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
