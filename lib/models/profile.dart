// ignore_for_file: invalid_annotation_target
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/clash/core.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/subscription/utils/subscription_url_helper.dart';
import 'package:fl_clash/xboard/security/fastcat_subscription_decoder.dart';
import 'package:fl_clash/security/profile_vault.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

import 'clash_config.dart';

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

typedef SelectedMap = Map<String, String>;

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null) return const SubscriptionInfo();
    final list = info.split(";");
    Map<String, int?> map = {};
    for (final i in list) {
      final keyValue = i.trim().split("=");
      map[keyValue[0]] = int.tryParse(keyValue[1]);
    }
    return SubscriptionInfo(
      upload: map["upload"] ?? 0,
      download: map["download"] ?? 0,
      total: map["total"] ?? 0,
      expire: map["expire"] ?? 0,
    );
  }
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? label,
    String? currentGroupName,
    @Default("") String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) SelectedMap selectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverrideData()) OverrideData overrideData,
    @JsonKey(includeToJson: false, includeFromJson: false)
    @Default(false)
    bool isUpdating,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({
    String? label,
    String url = '',
  }) {
    return Profile(
      label: label,
      url: url,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      autoUpdateDuration: defaultUpdateDuration,
    );
  }
}

@freezed
class OverrideData with _$OverrideData {
  const factory OverrideData({
    @Default(false) bool enable,
    @Default(OverrideRule()) OverrideRule rule,
  }) = _OverrideData;

  factory OverrideData.fromJson(Map<String, Object?> json) =>
      _$OverrideDataFromJson(json);
}

extension OverrideDataExt on OverrideData {
  List<String> get runningRule {
    if (!enable) {
      return [];
    }
    return rule.rules.map((item) => item.value).toList();
  }
}

@freezed
class OverrideRule with _$OverrideRule {
  const factory OverrideRule({
    @Default(OverrideRuleType.added) OverrideRuleType type,
    @Default([]) List<Rule> overrideRules,
    @Default([]) List<Rule> addedRules,
  }) = _OverrideRule;

  factory OverrideRule.fromJson(Map<String, Object?> json) =>
      _$OverrideRuleFromJson(json);
}

extension OverrideRuleExt on OverrideRule {
  List<Rule> get rules => switch (type == OverrideRuleType.override) {
        true => overrideRules,
        false => addedRules,
      };

  OverrideRule updateRules(List<Rule> Function(List<Rule> rules) builder) {
    if (type == OverrideRuleType.added) {
      return copyWith(addedRules: builder(addedRules));
    }
    return copyWith(overrideRules: builder(overrideRules));
  }
}

extension ProfilesExt on List<Profile> {
  Profile? getProfile(String? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }
}

extension ProfileExtension on Profile {
  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  Future<void> checkAndUpdate() async {
    final isExists = await check();
    if (!isExists) {
      if (url.isNotEmpty) {
        await update();
      }
    }
  }

  Future<bool> check() async {
    await ProfileVault.instance.migrateLegacy(id);
    return ProfileVault.instance.exists(id);
  }

  Future<int> get profileLastModified async {
    return (await ProfileVault.instance.lastModified(id))
        .microsecondsSinceEpoch;
  }

  Future<Profile> update() async {
    // 动态获取最新的订阅 URL，并在远程配置提供多个订阅域名时
    // 并发竞速选择最快的可用地址。
    String updateUrl = url;
    if (url.isNotEmpty) {
      try {
        final sdk = XBoardSDK.instance;
        final subscription = await sdk.subscription.getSubscription();
        final token = subscription.token;

        if (token != null &&
            token.isNotEmpty &&
            XBoardConfig.subscriptionUrlList.length > 1) {
          final fastestUrl = await XBoardConfig.getFastestSubscriptionUrl(
            token,
            preferEncrypt: true,
          );
          if (fastestUrl != null && fastestUrl.isNotEmpty) {
            updateUrl = fastestUrl;
          }
        }

        // 竞速未配置、没有可用结果或只有一个订阅域名时，使用面板返回地址。
        if (updateUrl == url &&
            subscription.subscribeUrl != null &&
            subscription.subscribeUrl!.isNotEmpty) {
          updateUrl = subscription.subscribeUrl!;
        }
      } catch (_) {
        // SDK未初始化或获取失败时，回退使用原URL
        // 这样旧节点缓存仍然可用
      }
    }

    final response = await request.getFileResponseForUrl(
        SubscriptionUrlHelper.ensureFastCatFlag(updateUrl));
    final disposition = response.headers.value("content-disposition");
    final userinfo = response.headers.value('subscription-userinfo');
    return await copyWith(
      url: updateUrl, // 同步更新存储的URL为最新的
      label: label ?? utils.getFileNameForDisposition(disposition) ?? id,
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
    ).saveFile(Uint8List.fromList(utf8.encode(
      FastCatSubscriptionDecoder.decode(utf8.decode(response.data)),
    )));
  }

  Future<Profile> saveFile(Uint8List bytes) async {
    final message = await clashCore.validateConfig(utf8.decode(bytes));
    if (message.isNotEmpty) {
      throw message;
    }
    await ProfileVault.instance.writeText(id, utf8.decode(bytes));
    return copyWith(lastUpdateDate: DateTime.now());
  }

  Future<Profile> saveFileWithString(String value) async {
    final message = await clashCore.validateConfig(value);
    if (message.isNotEmpty) {
      throw message;
    }
    await ProfileVault.instance.writeText(id, value);
    return copyWith(lastUpdateDate: DateTime.now());
  }
}
