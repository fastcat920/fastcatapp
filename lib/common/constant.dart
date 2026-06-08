import 'dart:convert' show base64Decode, utf8;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show Uint8List;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';

/// 应用名称（构建时由注入脚本替换）
const appName = "快猫";

/// 用于 HTTP User-Agent 的英文名称（UA 不允许非 ASCII 字符）
const appNameEn = "fastcat";
const appHelperService = "fastcatHelperService";
const coreName = "clash.meta";
const packageName = "com.fastcat.app";
final unixSocketPath = "/tmp/fastcatSocket_${Random().nextInt(10000)}.sock";
const helperPort = 47890;
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.ap,
  horizontal: 16.ap,
);

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 10000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const mmdbFileName = "geoip.metadb";
const asnFileName = "ASN.mmdb";
const geoIpFileName = "GeoIP.dat";
const geoSiteFileName = "GeoSite.dat";
final double kHeaderHeight = system.isDesktop
    ? !Platform.isMacOS
        ? 40
        : 28
    : 0;
const profilesDirectoryName = "profiles";
const localhost = "127.0.0.1";
const clashConfigKey = "clash_config";
const configKey = "config";
const closeConnectionsDefaultMigratedKey = 'close_connections_default_migrated';
const double dialogCommonWidth = 300;
const repository = "chen08209/FlClash";
const defaultExternalController = "127.0.0.1:9090";
const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = "https://www.gstatic.com/generate_204";
final commonFilter = ImageFilter.blur(
  sigmaX: 5,
  sigmaY: 5,
  tileMode: TileMode.mirror,
);

const navigationItemListEquality = ListEquality<NavigationItem>();
const connectionListEquality = ListEquality<Connection>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
  ViewMode.tv: [3, 2],
};

const defaultPrimaryColor = 0xFF4566AE;

double getWidgetHeight(num lines) {
  return max(lines * 84 + (lines - 1) * 16, 0).ap;
}

const maxLength = 150;

final mainIsolate = "fastcatMainIsolate";

final serviceIsolate = "fastcatServiceIsolate";

const defaultPrimaryColors = [
  0xFF795548,
  0xFF03A9F4,
  0xFFFFFF00,
  0XFFBBC9CC,
  0XFFABD397,
  defaultPrimaryColor,
  0XFF665390,
];

const scriptTemplate = """
const main = (config) => {
  return config;
}""";

// ── 内置 OSS 配置（XOR 混淆存储）──
const _builtinOssObfuscated =
    'DhUHBBBbWxZVVQ4WEhNOUEYMAwZfV0dNWk8XVkEfBxFeExYAGl5IWQkUXRkaEBdVXUQCTxAbDk4XWEYfDBIcGg==';
const _builtinOssKey = 'fastcat921fastcat921';

/// 获取内置 OSS config.json URL（运行时解密）
String get builtinOssUrl =>
    _xorDeobfuscate(_builtinOssObfuscated, _builtinOssKey);

String _xorDeobfuscate(String encoded, String key) {
  final encBytes = base64Decode(encoded);
  final keyBytes = utf8.encode(key);
  final result = Uint8List(encBytes.length);
  for (var i = 0; i < encBytes.length; i++) {
    result[i] = encBytes[i] ^ keyBytes[i % keyBytes.length];
  }
  return utf8.decode(result);
}
