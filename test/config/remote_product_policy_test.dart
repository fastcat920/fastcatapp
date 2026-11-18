import 'dart:convert';
import 'dart:io';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/parsers/configuration_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'retired remote switches are excluded; product menus have fixed availability',
      () {
    final normalized = ConfigurationParser().extractConfigFromRemoteResult({
      'domains': ['https://panel.example.com'],
      'features': {
        'join_group_enabled': true,
        'traffic_details_enabled': false
      },
      'latency': {'display_discount_percent': 90},
      'ticket': {'imgbb_api_key': 'obsolete'},
    })!;
    expect(normalized.containsKey('features'), false);
    expect(normalized.containsKey('latency'), false);
    expect(normalized.containsKey('ticket'), false);
    expect(XBoardConfig.isJoinGroupEnabled, false);
    expect(XBoardConfig.isTicketsEnabled, false);
    expect(XBoardConfig.isTrafficDetailsEnabled, true);
    expect(XBoardConfig.isKnowledgeBaseEnabled, true);
    expect(XBoardConfig.isGiftCardEnabled, true);
    expect(XBoardConfig.isOrdersEnabled, true);
    expect(XBoardConfig.isDevicesEnabled, true);
    expect(XBoardConfig.isBalanceEnabled, true);
  });
  test(
      'complete OSS template has independent modern configuration for every client',
      () {
    final json = jsonDecode(
        File('docs/updating/remote-config-plaintext.example.json')
            .readAsStringSync()) as Map<String, dynamic>;
    for (final key in ['features', 'ticket', 'latency']) {
      expect(json.containsKey(key), false);
    }
    expect((json['contact'] as Map).containsKey('crisp_website_id'), false);
    final update =
        UpdateRichConfig.fromJson(Map<String, dynamic>.from(json['update']));
    expect(update.platforms.keys.toSet(),
        {'android', 'ios', 'tvos', 'windows', 'macos', 'linux'});
    expect(update.toJson().containsKey('latest'), false);
    expect(
        update.platformInfo('windows')!.artifacts.keys.toSet(), {'universal'});
    expect(update.platformInfo('linux')!.artifacts.keys.toSet(),
        {'x64_deb', 'x64_rpm'});
    final descriptions = <String>{};
    for (final platform in update.platforms.keys) {
      final info = update.platformInfo(platform)!;
      expect(info.changelog.keys.toSet(), {'zh_CN', 'en_US'});
      descriptions.add(update.localizedChangelog(platform, 'en'));
    }
    expect(descriptions.length, 6);
  });
}
