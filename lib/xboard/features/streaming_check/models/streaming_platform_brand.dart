import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';

class StreamingPlatformBrand {
  const StreamingPlatformBrand({
    required this.color,
    required this.icon,
    this.darkColor,
    this.mark = '',
  });

  final Color color;
  final Color? darkColor;
  final String mark;
  final IconData? icon;

  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor ?? color : color;

  static StreamingPlatformBrand forId(String id) => switch (id) {
        'netflix' => const StreamingPlatformBrand(
            color: Color(0xFFE50914), icon: SimpleIcons.netflix),
        'disney' => const StreamingPlatformBrand(
            color: Color(0xFF113CCF),
            darkColor: Color(0xFF8EA9FF),
            icon: null,
            mark: 'D+'),
        'youtube' => const StreamingPlatformBrand(
            color: Color(0xFFFF0000), icon: SimpleIcons.youtube),
        'prime_video' => const StreamingPlatformBrand(
            color: Color(0xFF00A8E1),
            darkColor: Color(0xFF35C5F4),
            icon: Icons.play_circle_fill_rounded),
        'max' => const StreamingPlatformBrand(
            color: Color(0xFF002BE7),
            darkColor: Color(0xFF8EA4FF),
            icon: SimpleIcons.max),
        'apple_tv' => const StreamingPlatformBrand(
            color: Color(0xFF111111),
            darkColor: Colors.white,
            icon: SimpleIcons.appletv),
        'bbc_iplayer' => const StreamingPlatformBrand(
            color: Color(0xFFFF4C98), icon: null, mark: 'BBC'),
        'dazn' => const StreamingPlatformBrand(
            color: Color(0xFF0C161C),
            darkColor: Colors.white,
            icon: SimpleIcons.dazn),
        'chatgpt' => const StreamingPlatformBrand(
            color: Color(0xFF10A37F), icon: Icons.hub_rounded),
        'claude' => const StreamingPlatformBrand(
            color: Color(0xFFD97757), icon: SimpleIcons.claude),
        'gemini' => const StreamingPlatformBrand(
            color: Color(0xFF4E82EE), icon: SimpleIcons.googlegemini),
        'copilot' => const StreamingPlatformBrand(
            color: Color(0xFF258FFA), icon: SimpleIcons.githubcopilot),
        'crunchyroll' => const StreamingPlatformBrand(
            color: Color(0xFFF47521), icon: SimpleIcons.crunchyroll),
        'tiktok' => const StreamingPlatformBrand(
            color: Color(0xFF111111),
            darkColor: Color(0xFF25F4EE),
            icon: SimpleIcons.tiktok),
        'grok' => const StreamingPlatformBrand(
            color: Color(0xFF111111),
            darkColor: Colors.white,
            icon: SimpleIcons.x),
        'google_ai_studio' => const StreamingPlatformBrand(
            color: Color(0xFF4285F4), icon: SimpleIcons.google),
        _ => const StreamingPlatformBrand(
            color: Color(0xFF607D8B), icon: Icons.live_tv_outlined),
      };
}
