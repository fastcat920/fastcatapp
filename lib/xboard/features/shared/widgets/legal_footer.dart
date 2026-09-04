import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class FastCatLegalLinks {
  static const String _privacyPolicyUrl = String.fromEnvironment(
    'FASTCAT_PRIVACY_POLICY_URL',
    defaultValue: 'https://www.fastcat6.com/privacy',
  );
  static const String _termsOfServiceUrl = String.fromEnvironment(
    'FASTCAT_TERMS_OF_SERVICE_URL',
    defaultValue: 'https://www.fastcat6.com/terms',
  );

  static final Uri privacyPolicyUri = Uri.parse(_privacyPolicyUrl);
  static final Uri termsOfServiceUri = Uri.parse(_termsOfServiceUrl);

  static Future<bool> openPrivacyPolicy() {
    return launchUrl(
      privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> openTermsOfService() {
    return launchUrl(
      termsOfServiceUri,
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Public legal links shown without exposing their URLs in the UI.
class FastCatLegalFooter extends StatelessWidget {
  const FastCatLegalFooter({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final colorScheme = Theme.of(context).colorScheme;
    final legalStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: FastCatLegalLinks.openPrivacyPolicy,
              child:
                  Text(chinese ? '隐私政策' : 'Privacy Policy', style: legalStyle),
            ),
            Text(
              '|',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            TextButton(
              onPressed: FastCatLegalLinks.openTermsOfService,
              child: Text(chinese ? '服务条款' : 'Terms of Service',
                  style: legalStyle),
            ),
          ],
        ),
        SizedBox(height: compact ? 2 : 4),
        FastCatCopyrightNotice(compact: compact),
      ],
    );
  }
}

/// Mandatory legal acknowledgement shown before account registration.
class FastCatLegalAgreement extends StatelessWidget {
  const FastCatLegalAgreement({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
    final linkStyle = textStyle?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final linkButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Semantics(
      container: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 2,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (checked) => onChanged(checked ?? false),
            ),
          ),
          const SizedBox(width: 4),
          Text(chinese ? '我已阅读并同意' : 'I have read and agree to ',
              style: textStyle),
          TextButton(
            style: linkButtonStyle,
            onPressed: FastCatLegalLinks.openPrivacyPolicy,
            child: Text(
              chinese ? '《隐私政策》' : 'Privacy Policy',
              style: linkStyle,
            ),
          ),
          Text(chinese ? '和' : ' and ', style: textStyle),
          TextButton(
            style: linkButtonStyle,
            onPressed: FastCatLegalLinks.openTermsOfService,
            child: Text(
              chinese ? '《服务条款》' : 'Terms of Service',
              style: linkStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class FastCatCopyrightNotice extends StatelessWidget {
  const FastCatCopyrightNotice({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '© 2021–2026 FastCat Digital Labs LLC. All rights reserved.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: compact ? 11 : null,
            ),
      ),
    );
  }
}
