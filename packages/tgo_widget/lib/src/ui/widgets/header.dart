import 'remote_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/tgo_theme.dart';
import '../../i18n/tgo_localizations.dart';

/// Header widget for the chat screen
class ChatHeader extends StatelessWidget {
  final String title;
  final String? logoUrl;
  final VoidCallback? onClose;
  final bool showClose;
  final bool soundEnabled;
  final String locale;
  final VoidCallback? onToggleSound;

  const ChatHeader({
    super.key,
    required this.title,
    this.logoUrl,
    this.onClose,
    this.showClose = true,
    this.soundEnabled = true,
    this.locale = 'en',
    this.onToggleSound,
  });

  @override
  Widget build(BuildContext context) {
    final theme = TgoThemeProvider.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.bgPrimary,
        border: Border(
          bottom: BorderSide(color: theme.borderPrimary),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
            height: 48,
            child: Row(
              children: [
                // Logo
                if (logoUrl != null && logoUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RemoteImage(
                        url: logoUrl!, size: 20, fallback: _defaultLogo(theme)),
                  )
                else
                  _defaultLogo(theme),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary))),
                IconButton(
                    onPressed: onToggleSound,
                    icon: Icon(
                        soundEnabled
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        color: theme.textSecondary),
                    tooltip: TgoLocalizations(locale: locale)
                        .get(soundEnabled ? 'mute_sound' : 'enable_sound')),
              ],
            )),
      ),
    );
  }

  Widget _defaultLogo(TgoTheme theme) {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      package: 'tgo_widget',
      width: 20,
      height: 20,
      placeholderBuilder: (BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.support_agent,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
