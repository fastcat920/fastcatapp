import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'zh_CN', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'en', 'name': 'English', 'flag': '🌐'},
    {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final appSetting = ref.watch(appSettingProvider);
    final currentLocale = appSetting.locale;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: '切换语言 / Switch Language',
      onSelected: (String languageCode) {
        ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(locale: languageCode),
            );
      },
      itemBuilder: (BuildContext context) {
        return supportedLanguages.map<PopupMenuEntry<String>>(
          (Map<String, String> language) {
            final isSelected = language['code'] == currentLocale;
            return PopupMenuItem<String>(
              value: language['code'],
              child: Row(
                children: [
                  Text(
                    language['flag']!,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      language['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                ],
              ),
            );
          },
        ).toList();
      },
    );
  }
}
