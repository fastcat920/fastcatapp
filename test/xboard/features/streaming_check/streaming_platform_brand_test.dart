import 'package:fl_clash/xboard/features/streaming_check/models/streaming_platform_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known platforms use branded vector icons', () {
    final netflix = StreamingPlatformBrand.forId('netflix');
    final youtube = StreamingPlatformBrand.forId('youtube');
    final claude = StreamingPlatformBrand.forId('claude');

    expect(netflix.icon, isNotNull);
    expect(youtube.icon, isNotNull);
    expect(claude.icon, isNotNull);
    expect(netflix.color, isNot(youtube.color));
  });

  test('dark mode gives monochrome brands a high contrast color', () {
    final tiktok = StreamingPlatformBrand.forId('tiktok');
    final appleTv = StreamingPlatformBrand.forId('apple_tv');

    expect(tiktok.colorFor(Brightness.dark), const Color(0xFF25F4EE));
    expect(
      tiktok.colorFor(Brightness.dark).computeLuminance(),
      greaterThan(tiktok.colorFor(Brightness.light).computeLuminance()),
    );
    expect(appleTv.colorFor(Brightness.dark), Colors.white);
  });

  test('unknown platform has a safe fallback icon', () {
    expect(StreamingPlatformBrand.forId('unknown').icon, isNotNull);
  });
}
