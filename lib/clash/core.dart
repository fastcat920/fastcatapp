import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

class ClashCore {
  static ClashCore? _instance;
  late ClashHandlerInterface clashInterface;

  ClashCore._internal() {
    if (Platform.isAndroid) {
      clashInterface = clashLib!;
    } else if (Platform.isIOS) {
      clashInterface = clashIOS!;
    } else {
      clashInterface = clashService!;
    }
  }

  factory ClashCore() {
    _instance ??= ClashCore._internal();
    return _instance!;
  }

  Future<bool> preload() {
    return clashInterface.preload();
  }

  static Future<void> initGeo() async {
    final homePath = await appPath.homeDirPath;
    final homeDir = Directory(homePath);
    final isExists = await homeDir.exists();
    if (!isExists) {
      await homeDir.create(recursive: true);
    }
    const geoFileNameList = [
      mmdbFileName,
      geoIpFileName,
      geoSiteFileName,
      asnFileName,
    ];
    for (final geoFileName in geoFileNameList) {
      final geoFile = File(
        join(homePath, geoFileName),
      );
      final isExists = await geoFile.exists();
      if (isExists) {
        continue;
      }
      try {
        final data = await rootBundle.load('assets/data/$geoFileName');
        List<int> bytes = data.buffer.asUint8List();
        await geoFile.writeAsBytes(bytes, flush: true);
      } on FlutterError {
        commonPrint.log("Built-in geodata not found: $geoFileName");
      }
    }
  }

  Future<bool> init() async {
    await initGeo();
    if (globalState.config.appSetting.openLogs) {
      clashCore.startLog();
    } else {
      clashCore.stopLog();
    }
    final homeDirPath = await appPath.homeDirPath;
    return await clashInterface.init(
      InitParams(
        homeDir: homeDirPath,
        version: globalState.appState.version,
      ),
    );
  }

  Future<bool> setState(CoreState state) async {
    return await clashInterface.setState(state);
  }

  shutdown() async {
    await clashInterface.shutdown();
  }

  FutureOr<bool> get isInit => clashInterface.isInit;

  FutureOr<String> validateConfig(String data) {
    return clashInterface.validateConfig(data);
  }

  Future<String> updateConfig(UpdateParams updateParams) async {
    return await clashInterface.updateConfig(updateParams);
  }

  Future<String> setupConfig(SetupParams setupParams) async {
    return await clashInterface.setupConfig(setupParams);
  }

  Future<List<Group>> getProxiesGroups() async {
    final proxies = await clashInterface.getProxies();
    if (proxies.isEmpty) return [];
    final globalProxy = proxies[UsedProxy.GLOBAL.name];
    if (globalProxy == null) return [];
    final allList = globalProxy["all"];
    if (allList == null || allList is! List) return [];
    final groupNames = [
      UsedProxy.GLOBAL.name,
      ...allList.where((e) {
        final proxy = proxies[e] ?? {};
        return GroupTypeExtension.valueList.contains(proxy['type']);
      })
    ];
    final groupsRaw = groupNames
        .map((groupName) {
          final group = proxies[groupName];
          if (group == null) return null;
          final groupMap = Map<String, dynamic>.from(group as Map);
          groupMap["all"] = ((groupMap["all"] ?? []) as List)
              .map((name) => proxies[name])
              .where((proxy) => proxy != null)
              .map((proxy) => Map<String, dynamic>.from(proxy as Map))
              .toList();
          return groupMap;
        })
        .where((g) => g != null)
        .toList();
    return groupsRaw
        .map(
          (e) => Group.fromJson(e!),
        )
        .toList();
  }

  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) async {
    return await clashInterface.changeProxy(changeProxyParams);
  }

  Future<List<Connection>> getConnections() async {
    final res = await clashInterface.getConnections();
    final connectionsData = json.decode(res) as Map;
    final connectionsRaw = connectionsData['connections'] as List? ?? [];
    return connectionsRaw.map((e) => Connection.fromJson(e)).toList();
  }

  closeConnection(String id) {
    clashInterface.closeConnection(id);
  }

  closeConnections() {
    clashInterface.closeConnections();
  }

  resetConnections() {
    clashInterface.resetConnections();
  }

  Future<List<ExternalProvider>> getExternalProviders() async {
    final externalProvidersRawString =
        await clashInterface.getExternalProviders();
    if (externalProvidersRawString.isEmpty) {
      return [];
    }
    return Isolate.run<List<ExternalProvider>>(
      () {
        final externalProviders =
            (json.decode(externalProvidersRawString) as List<dynamic>)
                .map(
                  (item) => ExternalProvider.fromJson(item),
                )
                .toList();
        return externalProviders;
      },
    );
  }

  Future<ExternalProvider?> getExternalProvider(
      String externalProviderName) async {
    final externalProvidersRawString =
        await clashInterface.getExternalProvider(externalProviderName);
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    return ExternalProvider.fromJson(json.decode(externalProvidersRawString));
  }

  Future<String> updateGeoData(UpdateGeoDataParams params) {
    return clashInterface.updateGeoData(params);
  }

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) {
    return clashInterface.sideLoadExternalProvider(
        providerName: providerName, data: data);
  }

  Future<String> updateExternalProvider({
    required String providerName,
  }) async {
    return clashInterface.updateExternalProvider(providerName);
  }

  startListener() async {
    await clashInterface.startListener();
  }

  stopListener() async {
    await clashInterface.stopListener();
  }

  Future<Delay> getDelay(String url, String proxyName) async {
    final data = await clashInterface.asyncTestDelay(url, proxyName);
    if (data.isEmpty) {
      return Delay(name: proxyName, url: url, value: -1);
    }
    try {
      return Delay.fromJson(json.decode(data));
    } catch (_) {
      return Delay(name: proxyName, url: url, value: -1);
    }
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final profilePath = await appPath.getProfilePath(id);
    final res = await clashInterface.getConfig(profilePath);
    if (res.isSuccess) {
      return Map<String, dynamic>.from(res.data as Map);
    } else {
      throw res.message;
    }
  }

  Future<Traffic> getTraffic() async {
    final trafficString = await clashInterface.getTraffic();
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<IpInfo?> getCountryCode(String ip) async {
    final countryCode = await clashInterface.getCountryCode(ip);
    if (countryCode.isEmpty) {
      return null;
    }
    return IpInfo(
      ip: ip,
      countryCode: countryCode,
    );
  }

  Future<Traffic> getTotalTraffic() async {
    final totalTrafficString = await clashInterface.getTotalTraffic();
    if (totalTrafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(totalTrafficString));
  }

  Future<int> getMemory() async {
    final value = await clashInterface.getMemory();
    if (value.isEmpty) {
      return 0;
    }
    return int.parse(value);
  }

  resetTraffic() {
    clashInterface.resetTraffic();
  }

  startLog() {
    clashInterface.startLog();
  }

  stopLog() {
    clashInterface.stopLog();
  }

  requestGc() {
    clashInterface.forceGc();
  }

  destroy() async {
    await clashInterface.destroy();
  }
}

final clashCore = ClashCore();
