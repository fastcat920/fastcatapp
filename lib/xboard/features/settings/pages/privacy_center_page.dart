import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/shared/widgets/legal_footer.dart';

/// In-app privacy notice. The public, versioned policy is maintained separately
/// and must be linked from App Store Connect before submission.
class PrivacyCenterPage extends StatelessWidget {
  const PrivacyCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final content = chinese ? _zhSections : _enSections;
    return Scaffold(
      appBar: AppBar(title: Text(chinese ? '数据与隐私' : 'Data & Privacy')),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              chinese ? '隐私说明' : 'Privacy Notice',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              chinese
                  ? '本说明概述快猫客户端处理数据的方式。完整、公开的隐私政策以官网发布版本为准。'
                  : 'This notice summarizes how the FastCat app handles data. The public policy published on our website is the controlling version.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final section in content) ...[
              Text(section.$1, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(section.$2, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: FastCatLegalLinks.openPrivacyPolicy,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  chinese ? '查看完整隐私政策' : 'View Full Privacy Policy',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _zhSections = <(String, String)>[
  ('我们处理的数据', '为登录和提供服务，应用会处理邮箱、账户与订阅状态、订单记录、设备标识、设备名称、系统版本及应用版本。'),
  ('VPN 服务', '建立 VPN 连接时，服务端会处理提供连接和排查故障所必需的网络请求信息。我们不会在应用内提供广告追踪功能。'),
  (
    '在线客服',
    '您主动打开 Crisp 在线客服时，邮箱、昵称、客户端与套餐摘要会发送给客服服务商；您主动发送的消息和图片附件也会由该服务处理。相机和相册仅在您选择发送图片时请求访问。'
  ),
  ('付款', '付款在外部浏览器的支付页面完成。应用不直接收集银行卡或支付账户凭据；我们会处理订单、套餐和支付结果以提供服务。'),
  (
    '您的选择',
    '您可以在账户信息页面注销账号。注销会使账号无法继续登录；订单或依法必须保留的记录可能在适用期限内保留。您也可以通过在线客服提出隐私问题或数据请求。'
  ),
];

const _enSections = <(String, String)>[
  (
    'Data we handle',
    'To sign in and provide the service, the app handles your email address, account and subscription status, order records, device identifier, device name, OS version, and app version.'
  ),
  (
    'VPN service',
    'When a VPN connection is established, our service processes the network request information necessary to provide the connection and troubleshoot it. The app does not provide advertising tracking.'
  ),
  (
    'Online support',
    'When you open Crisp support, your email, nickname, client and subscription summary are sent to the support provider. Messages and image attachments you choose to send are also handled by that provider. Camera and photo access is requested only when you choose an image.'
  ),
  (
    'Payments',
    'Payments are completed in an external browser. The app does not directly collect card or payment-account credentials; we handle orders, plans, and payment results to provide the service.'
  ),
  (
    'Your choices',
    'You can delete your account from Account Information. Deletion prevents future sign-in; order records or records we must retain by law may be kept for the applicable period. You can also contact support with privacy questions or data requests.'
  ),
];
