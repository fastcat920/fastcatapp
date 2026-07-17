import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/latency/providers/latency_display_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app.dart';
import 'config.dart';

part 'generated/state.g.dart';

@riverpod
Config configState(Ref ref) {
  final themeProps = ref.watch(themeSettingProvider);
  final patchClashConfig = ref.watch(patchClashConfigProvider);
  final appSetting = ref.watch(appSettingProvider);
  final profiles = ref.watch(profilesProvider);
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final overrideDns = ref.watch(overrideDnsProvider);
  final networkProps = ref.watch(networkSettingProvider);
  final vpnProps = ref.watch(vpnSettingProvider);
  final proxiesStyle = ref.watch(proxiesStyleSettingProvider);
  final scriptProps = ref.watch(scriptStateProvider);
  final hotKeyActions = ref.watch(hotKeyActionsProvider);
  final dav = ref.watch(appDAVSettingProvider);
  final windowProps = ref.watch(windowSettingProvider);
  return Config(
    dav: dav,
    windowProps: windowProps,
    hotKeyActions: hotKeyActions,
    scriptProps: scriptProps,
    proxiesStyle: proxiesStyle,
    vpnProps: vpnProps,
    networkProps: networkProps,
    overrideDns: overrideDns,
    currentProfileId: currentProfileId,
    profiles: profiles,
    appSetting: appSetting,
    themeProps: themeProps,
    patchClashConfig: patchClashConfig,
  );
}

@riverpod
GroupsState currentGroupsState(Ref ref) {
  final mode =
      ref.watch(patchClashConfigProvider.select((state) => state.mode));
  final groups = ref.watch(groupsProvider);
  return GroupsState(
    value: switch (mode) {
      Mode.direct => [],
      Mode.global => _buildGlobalModeGroups(groups),
      Mode.rule => _buildRuleModeGroups(groups),
    },
  );
}

List<Group> _buildRuleModeGroups(List<Group> groups) {
  final mainGroup = _findMainProxyGroup(groups);
  if (mainGroup == null) return [];
  final allProxies = _prioritizeComputedGroupProxies(mainGroup.all, groups);
  // 修正 now：若指向 DIRECT/REJECT 等不应显示的代理，fallback 到第一个有效代理
  String nowValue = mainGroup.now ?? '';
  if (nowValue.isNotEmpty && allProxies.isNotEmpty) {
    if (_isHiddenProxy(nowValue) ||
        !allProxies.any((p) => p.name == nowValue)) {
      nowValue = allProxies.first.name;
    }
  }
  return [
    mainGroup.copyWith(
      now: nowValue,
      all: allProxies,
    ),
  ];
}

List<Group> _buildGlobalModeGroups(List<Group> groups) {
  final globalGroup = groups.getGroup(GroupName.GLOBAL.name);
  final mainGroup = _findMainProxyGroup(groups);
  final sourceGroup = mainGroup ?? globalGroup;
  if (sourceGroup == null) return [];
  final allProxies = _prioritizeComputedGroupProxies(sourceGroup.all, groups);
  // Clash 默认 now 可能是 DIRECT/REJECT 或不在可见列表中的代理。
  // 此时 fallback 到 all 第一个有效代理（通常是 URLTest 自动选择组）。
  String nowValue = globalGroup?.now ?? sourceGroup.now ?? '';
  if (nowValue.isNotEmpty && allProxies.isNotEmpty) {
    if (_isHiddenProxy(nowValue) ||
        !allProxies.any((p) => p.name == nowValue)) {
      nowValue = allProxies.first.name;
    }
  }
  return [
    sourceGroup.copyWith(
      name: globalGroup?.name ?? sourceGroup.name,
      type: globalGroup?.type ?? sourceGroup.type,
      now: nowValue,
      testUrl: globalGroup?.testUrl ?? sourceGroup.testUrl,
      all: allProxies,
    ),
  ];
}

Group? _findMainProxyGroup(List<Group> groups) {
  final visibleGroups = groups
      .where((item) => item.hidden != true)
      .where((item) => item.name != GroupName.GLOBAL.name)
      .toList();
  final selectorGroups =
      visibleGroups.where((item) => item.type == GroupType.Selector).toList();
  if (selectorGroups.isNotEmpty) {
    return selectorGroups.firstWhere(
      (item) => item.all.any((proxy) => _isComputedGroupProxy(proxy, groups)),
      orElse: () => selectorGroups.first,
    );
  }
  return visibleGroups.firstOrNull;
}

List<Proxy> _prioritizeComputedGroupProxies(
  List<Proxy> proxies,
  List<Group> groups,
) {
  final computedProxies =
      proxies.where((proxy) => _isComputedGroupProxy(proxy, groups)).toList();
  final nodeProxies =
      proxies.where((proxy) => !_isComputedGroupProxy(proxy, groups)).toList();
  return [...computedProxies, ...nodeProxies];
}

bool _isComputedGroupProxy(Proxy proxy, List<Group> groups) {
  final proxyGroup = groups.getGroup(proxy.name);
  final proxyType = GroupTypeExtension.getGroupType(proxy.type);
  return proxyGroup?.type.isComputedSelected == true ||
      proxyType?.isComputedSelected == true;
}

/// DIRECT 和 REJECT 是 Clash 内部特殊代理，不应作为默认选中项显示。
bool _isHiddenProxy(String name) {
  return name == UsedProxy.DIRECT.name || name == UsedProxy.REJECT.name;
}

@riverpod
NavigationItemsState navigationsState(Ref ref) {
  final openLogs = ref.watch(appSettingProvider).openLogs;
  final hasProxies = ref.watch(
      currentGroupsStateProvider.select((state) => state.value.isNotEmpty));
  return NavigationItemsState(
    value: navigation.getItems(
      openLogs: openLogs,
      hasProxies: hasProxies,
    ),
  );
}

@riverpod
NavigationItemsState currentNavigationsState(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final navigationItemsState = ref.watch(navigationsStateProvider);
  final navigationItemMode = viewWidth <= maxMobileWidth
      ? NavigationItemMode.mobile
      : NavigationItemMode.desktop;
  return NavigationItemsState(
    value: navigationItemsState.value
        .where(
          (element) => element.modes.contains(navigationItemMode),
        )
        .toList(),
  );
}

@riverpod
CoreState coreState(Ref ref) {
  final vpnProps = ref.watch(vpnSettingProvider);
  final currentProfile = ref.watch(currentProfileProvider);
  final onlyStatisticsProxy = ref.watch(appSettingProvider).onlyStatisticsProxy;
  final bypassDomain = ref.watch(
    networkSettingProvider.select((state) => state.bypassDomain),
  );
  return CoreState(
    vpnProps: vpnProps,
    onlyStatisticsProxy: onlyStatisticsProxy,
    currentProfileName: currentProfile?.label ?? currentProfile?.id ?? "",
    bypassDomain: bypassDomain,
  );
}

@riverpod
UpdateParams updateParams(Ref ref) {
  final routeMode = ref.watch(
    networkSettingProvider.select(
      (state) => state.routeMode,
    ),
  );
  return ref.watch(
    patchClashConfigProvider.select(
      (state) => UpdateParams(
        tun: state.tun.getRealTun(routeMode),
        allowLan: state.allowLan,
        findProcessMode: state.findProcessMode,
        mode: state.mode,
        logLevel: state.logLevel,
        ipv6: state.ipv6,
        tcpConcurrent: state.tcpConcurrent,
        externalController: state.externalController,
        unifiedDelay: state.unifiedDelay,
        mixedPort: state.mixedPort,
      ),
    ),
  );
}

@riverpod
ProxyState proxyState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final vm2 = ref.watch(networkSettingProvider.select(
    (state) => VM2(
      a: state.systemProxy,
      b: state.bypassDomain,
    ),
  ));
  final mixedPort = ref.watch(
    patchClashConfigProvider.select((state) => state.mixedPort),
  );
  return ProxyState(
    isStart: isStart,
    systemProxy: vm2.a,
    bassDomain: vm2.b,
    port: mixedPort,
  );
}

@riverpod
TrayState trayState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final networkProps = ref.watch(networkSettingProvider);
  final clashConfig = ref.watch(
    patchClashConfigProvider,
  );
  final appSetting = ref.watch(
    appSettingProvider,
  );
  final groups = ref
      .watch(
        currentGroupsStateProvider,
      )
      .value;
  final brightness = ref.watch(
    appBrightnessProvider,
  );

  final selectedMap = ref.watch(selectedMapProvider);

  return TrayState(
    mode: clashConfig.mode,
    port: clashConfig.mixedPort,
    autoLaunch: appSetting.autoLaunch,
    systemProxy: networkProps.systemProxy,
    tunEnable: clashConfig.tun.enable,
    isStart: isStart,
    locale: appSetting.locale,
    brightness: brightness,
    groups: groups,
    selectedMap: selectedMap,
  );
}

@riverpod
VpnState vpnState(Ref ref) {
  final vpnProps = ref.watch(vpnSettingProvider);
  final stack = ref.watch(
    patchClashConfigProvider.select((state) => state.tun.stack),
  );

  return VpnState(
    stack: stack,
    vpnProps: vpnProps,
  );
}

@riverpod
HomeState homeState(Ref ref) {
  final pageLabel = ref.watch(currentPageLabelProvider);
  final navigationItems = ref.watch(currentNavigationsStateProvider).value;
  final viewMode = ref.watch(viewModeProvider);
  final locale = ref.watch(appSettingProvider).locale;
  return HomeState(
    pageLabel: pageLabel,
    navigationItems: navigationItems,
    viewMode: viewMode,
    locale: locale,
  );
}

@riverpod
DashboardState dashboardState(Ref ref) {
  final dashboardWidgets =
      ref.watch(appSettingProvider.select((state) => state.dashboardWidgets));
  final viewWidth = ref.watch(viewWidthProvider);
  return DashboardState(
    dashboardWidgets: dashboardWidgets,
    viewWidth: viewWidth,
  );
}

@riverpod
ProxiesActionsState proxiesActionsState(Ref ref) {
  final pageLabel = ref.watch(currentPageLabelProvider);
  final hasProviders = ref.watch(providersProvider.select(
    (state) => state.isNotEmpty,
  ));
  final type = ref.watch(proxiesStyleSettingProvider.select(
    (state) => state.type,
  ));
  return ProxiesActionsState(
    pageLabel: pageLabel,
    hasProviders: hasProviders,
    type: type,
  );
}

@riverpod
StartButtonSelectorState startButtonSelectorState(Ref ref) {
  final isInit = ref.watch(initProvider);
  final hasProfile =
      ref.watch(profilesProvider.select((state) => state.isNotEmpty));
  return StartButtonSelectorState(
    isInit: isInit,
    hasProfile: hasProfile,
  );
}

@riverpod
ProfilesSelectorState profilesSelectorState(Ref ref) {
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  final columns = ref.watch(
    viewWidthProvider.select(
      (state) => utils.getProfilesColumns(state),
    ),
  );
  return ProfilesSelectorState(
    profiles: profiles,
    currentProfileId: currentProfileId,
    columns: columns,
  );
}

@riverpod
ProxiesListSelectorState proxiesListSelectorState(Ref ref) {
  final groupNames = ref.watch(currentGroupsStateProvider.select((state) {
    return state.value.map((e) => e.name).toList();
  }));
  final currentUnfoldSet = ref.watch(unfoldSetProvider);
  final proxiesStyle = ref.watch(proxiesStyleSettingProvider);
  final sortNum = ref.watch(sortNumProvider);
  final columns = ref.watch(getProxiesColumnsProvider);
  final query = ref.watch(
    proxiesQueryProvider.select(
      (state) => state.toLowerCase(),
    ),
  );
  return ProxiesListSelectorState(
    groupNames: groupNames,
    currentUnfoldSet: currentUnfoldSet,
    proxiesSortType: proxiesStyle.sortType,
    proxyCardType: proxiesStyle.cardType,
    sortNum: sortNum,
    columns: columns,
    query: query,
  );
}

@riverpod
ProxiesSelectorState proxiesSelectorState(Ref ref) {
  final groupNames = ref.watch(
    currentGroupsStateProvider.select(
      (state) {
        return state.value.map((e) => e.name).toList();
      },
    ),
  );
  final currentGroupName = ref.watch(currentProfileProvider.select(
    (state) => state?.currentGroupName,
  ));
  return ProxiesSelectorState(
    groupNames: groupNames,
    currentGroupName: currentGroupName,
  );
}

@riverpod
GroupNamesState groupNamesState(Ref ref) {
  return GroupNamesState(
    groupNames: ref.watch(
      currentGroupsStateProvider.select(
        (state) {
          return state.value.map((e) => e.name).toList();
        },
      ),
    ),
  );
}

@riverpod
ProxyGroupSelectorState proxyGroupSelectorState(Ref ref, String groupName) {
  final proxiesStyle = ref.watch(
    proxiesStyleSettingProvider,
  );
  final group = ref.watch(
    currentGroupsStateProvider.select(
      (state) => state.value.getGroup(groupName),
    ),
  );
  final sortNum = ref.watch(sortNumProvider);
  final columns = ref.watch(getProxiesColumnsProvider);
  final query =
      ref.watch(proxiesQueryProvider.select((state) => state.toLowerCase()));
  final proxies = group?.all.where((item) {
        return item.name.toLowerCase().contains(query);
      }).toList() ??
      [];
  return ProxyGroupSelectorState(
    testUrl: group?.testUrl,
    proxiesSortType: proxiesStyle.sortType,
    proxyCardType: proxiesStyle.cardType,
    sortNum: sortNum,
    groupType: group?.type ?? GroupType.Selector,
    proxies: proxies,
    columns: columns,
  );
}

@riverpod
PackageListSelectorState packageListSelectorState(Ref ref) {
  final packages = ref.watch(packagesProvider);
  final accessControl =
      ref.watch(vpnSettingProvider.select((state) => state.accessControl));
  return PackageListSelectorState(
    packages: packages,
    accessControl: accessControl,
  );
}

@riverpod
MoreToolsSelectorState moreToolsSelectorState(Ref ref) {
  final viewMode = ref.watch(viewModeProvider);
  final navigationItems = ref.watch(navigationsStateProvider.select((state) {
    return state.value.where((element) {
      final isMore = element.modes.contains(NavigationItemMode.more);
      final isDesktop = element.modes.contains(NavigationItemMode.desktop);
      if (isMore && !isDesktop) return true;
      if (viewMode != ViewMode.mobile || !isMore) {
        return false;
      }
      return true;
    }).toList();
  }));

  return MoreToolsSelectorState(navigationItems: navigationItems);
}

@riverpod
bool isCurrentPage(
  Ref ref,
  PageLabel pageLabel, {
  bool Function(PageLabel pageLabel, ViewMode viewMode)? handler,
}) {
  final currentPageLabel = ref.watch(currentPageLabelProvider);
  if (pageLabel == currentPageLabel) {
    return true;
  }
  if (handler != null) {
    final viewMode = ref.watch(viewModeProvider);
    return handler(currentPageLabel, viewMode);
  }
  return false;
}

@riverpod
String getRealTestUrl(Ref ref, [String? testUrl]) {
  final currentTestUrl = ref.watch(appSettingProvider).testUrl;
  return testUrl.getSafeValue(currentTestUrl);
}

@riverpod
int? getDelay(
  Ref ref, {
  required String proxyName,
  String? testUrl,
}) {
  final currentTestUrl = ref.watch(getRealTestUrlProvider(testUrl));
  final proxyCardState = ref.watch(
    getProxyCardStateProvider(
      proxyName,
    ),
  );
  final delay = ref.watch(
    delayDataSourceProvider.select(
      (state) {
        final delayMap =
            state[proxyCardState.testUrl.getSafeValue(currentTestUrl)];
        return delayMap?[proxyCardState.proxyName];
      },
    ),
  );
  final discount = ref.watch(delayDiscountPercentProvider).valueOrNull ?? 0;
  return applyDelayDisplayDiscount(delay, discount);
}

@riverpod
SelectedMap selectedMap(Ref ref) {
  final selectedMap = ref.watch(
    currentProfileProvider.select((state) => state?.selectedMap ?? {}),
  );
  return selectedMap;
}

@riverpod
Set<String> unfoldSet(Ref ref) {
  final unfoldSet = ref.watch(
    currentProfileProvider.select((state) => state?.unfoldSet ?? {}),
  );
  return unfoldSet;
}

@riverpod
HotKeyAction getHotKeyAction(Ref ref, HotAction hotAction) {
  return ref.watch(
    hotKeyActionsProvider.select(
      (state) {
        final index = state.indexWhere((item) => item.action == hotAction);
        return index != -1
            ? state[index]
            : HotKeyAction(
                action: hotAction,
              );
      },
    ),
  );
}

@riverpod
Profile? currentProfile(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  return ref
      .watch(profilesProvider.select((state) => state.getProfile(profileId)));
}

@riverpod
int getProxiesColumns(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final proxiesLayout =
      ref.watch(proxiesStyleSettingProvider.select((state) => state.layout));
  return utils.getProxiesColumns(viewWidth, proxiesLayout);
}

ProxyCardState _getProxyCardState(
  List<Group> groups,
  SelectedMap selectedMap,
  ProxyCardState proxyDelayState,
) {
  if (proxyDelayState.proxyName.isEmpty) return proxyDelayState;
  final index =
      groups.indexWhere((element) => element.name == proxyDelayState.proxyName);
  if (index == -1) return proxyDelayState;
  final group = groups[index];
  final currentSelectedName = group
      .getCurrentSelectedName(selectedMap[proxyDelayState.proxyName] ?? '');
  if (currentSelectedName.isEmpty) {
    return proxyDelayState;
  }
  return _getProxyCardState(
    groups,
    selectedMap,
    proxyDelayState.copyWith(
      proxyName: currentSelectedName,
      testUrl: group.testUrl,
    ),
  );
}

@riverpod
ProxyCardState getProxyCardState(Ref ref, String proxyName) {
  final groups = ref.watch(groupsProvider);
  final selectedMap = ref.watch(selectedMapProvider);
  return _getProxyCardState(
      groups, selectedMap, ProxyCardState(proxyName: proxyName));
}

@riverpod
String? getProxyName(Ref ref, String groupName) {
  final proxyName =
      ref.watch(selectedMapProvider.select((state) => state[groupName]));
  return proxyName;
}

@riverpod
String? getSelectedProxyName(Ref ref, String groupName) {
  final proxyName = ref.watch(getProxyNameProvider(groupName));
  final group = ref.watch(
    groupsProvider.select(
      (state) => state.getGroup(groupName),
    ),
  );
  return group?.getCurrentSelectedName(proxyName ?? '');
}

@riverpod
String getProxyDesc(Ref ref, Proxy proxy) {
  final groupTypeNamesList = GroupType.values.map((e) => e.name).toList();
  if (!groupTypeNamesList.contains(proxy.type)) {
    return proxy.type;
  } else {
    final groups = ref.watch(groupsProvider);
    final index = groups.indexWhere((element) => element.name == proxy.name);
    if (index == -1) return proxy.type;
    final state = ref.watch(getProxyCardStateProvider(proxy.name));
    return "${proxy.type}(${state.proxyName.isNotEmpty ? state.proxyName : '*'})";
  }
}

@riverpod
class ProfileOverrideState extends _$ProfileOverrideState {
  @override
  ProfileOverrideStateModel build() {
    return ProfileOverrideStateModel(
      selectedRules: {},
    );
  }

  updateState(
    ProfileOverrideStateModel? Function(ProfileOverrideStateModel state)
        builder,
  ) {
    final value = builder(state);
    if (value == null) {
      return;
    }
    state = value;
  }
}

@riverpod
OverrideData? getProfileOverrideData(Ref ref, String profileId) {
  return ref.watch(
    profilesProvider.select(
      (state) => state.getProfile(profileId)?.overrideData,
    ),
  );
}

@riverpod
VM2? layoutChange(Ref ref) {
  final viewWidth = ref.watch(viewWidthProvider);
  final textScale =
      ref.watch(themeSettingProvider.select((state) => state.textScale));
  return VM2(
    a: viewWidth,
    b: textScale,
  );
}

@riverpod
VM2<int, bool> checkIp(Ref ref) {
  final checkIpNum = ref.watch(checkIpNumProvider);
  final containsDetection = ref.watch(
    dashboardStateProvider.select(
      (state) =>
          state.dashboardWidgets.contains(DashboardWidget.networkDetection),
    ),
  );
  return VM2(
    a: checkIpNum,
    b: containsDetection,
  );
}

@riverpod
ColorScheme genColorScheme(
  Ref ref,
  Brightness brightness, {
  Color? color,
  bool ignoreConfig = false,
}) {
  final schemeVariant = ref.watch(
    themeSettingProvider.select((state) => state.schemeVariant),
  );
  return ColorScheme.fromSeed(
    // 显式 color 仅用于颜色预览组件；应用主题始终使用 config.yaml。
    seedColor: color ?? globalState.configuredThemeColor,
    brightness: brightness,
    dynamicSchemeVariant: schemeVariant,
  );
}

@riverpod
VM3<String?, String?, Dns?> needSetup(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  final content = ref.watch(
      scriptStateProvider.select((state) => state.currentScript?.content));
  final overrideDns = ref.watch(overrideDnsProvider);
  final dns = overrideDns == true
      ? ref.watch(patchClashConfigProvider.select(
          (state) => state.dns,
        ))
      : null;
  return VM3(
    a: profileId,
    b: content,
    c: dns,
  );
}

@riverpod
VM2<bool, bool> autoSetSystemDnsState(Ref ref) {
  final isStart = ref.watch(runTimeProvider.select((state) => state != null));
  final realTunEnable = ref.watch(realTunEnableProvider);
  final autoSetSystemDns = ref.watch(
    networkSettingProvider.select(
      (state) => state.autoSetSystemDns,
    ),
  );
  return VM2(
    a: isStart ? realTunEnable : false,
    b: autoSetSystemDns,
  );
}
