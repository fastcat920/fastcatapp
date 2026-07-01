import 'dart:io';

import 'package:fl_clash/common/utils.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';

import 'constant.dart';
import 'window.dart';

class Tray {
  Traffic? _lastTitleTraffic;
  int _updateSerial = 0;
  String? _latestLocale;

  Future _updateSystemTray({
    required Brightness? brightness,
    bool force = false,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }
    if (Platform.isLinux || force) {
      await trayManager.destroy();
    }
    await trayManager.setIcon(
      utils.getTrayIconPath(
        brightness: brightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
      ),
      // macOS 使用 template 图标，交给系统按深浅色自适应渲染，
      // 避免状态栏文案/图标出现固定深色导致可读性问题。
      isTemplate: Platform.isMacOS,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(
        localizedAppName,
      );
    }
  }

  update({
    required TrayState trayState,
    bool focus = false,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }
    final updateSerial = ++_updateSerial;
    _latestLocale = trayState.locale;
    final l10n = await _loadTrayLocalizations(trayState.locale);
    if (updateSerial != _updateSerial) {
      await _loadTrayLocalizations(_latestLocale);
      return;
    }
    if (!Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        force: focus,
      );
    }
    List<MenuItem> menuItems = [];
    final showMenuItem = MenuItem(
      label: l10n.show,
      onClick: (_) {
        window?.show();
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem.checkbox(
      label: trayState.isStart ? l10n.trayDisconnect : l10n.trayStartConnection,
      onClick: (_) async {
        globalState.appController.updateStart();
      },
      checked: false,
    );
    menuItems.add(startMenuItem);
    menuItems.add(MenuItem.separator());
    for (final mode in Mode.values.where((mode) => mode != Mode.direct)) {
      menuItems.add(
        MenuItem.checkbox(
          label: _modeLabel(l10n, mode),
          onClick: (_) {
            globalState.appController.changeMode(mode);
          },
          checked: mode == trayState.mode,
        ),
      );
    }
    menuItems.add(MenuItem.separator());
    if (Platform.isMacOS) {
      for (final group in trayState.groups) {
        List<MenuItem> subMenuItems = [];
        for (final proxy in group.all) {
          subMenuItems.add(
            MenuItem.checkbox(
              label: proxy.name,
              checked: trayState.selectedMap[group.name] == proxy.name,
              onClick: (_) {
                final appController = globalState.appController;
                appController.updateCurrentSelectedMap(
                  group.name,
                  proxy.name,
                );
                appController.changeProxy(
                  groupName: group.name,
                  proxyName: proxy.name,
                );
              },
            ),
          );
        }
        menuItems.add(
          MenuItem.submenu(
            label: group.name,
            submenu: Menu(
              items: subMenuItems,
            ),
          ),
        );
      }
      if (trayState.groups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
    }
    if (trayState.isStart) {
      menuItems.add(
        MenuItem.checkbox(
          label: l10n.tun,
          onClick: (_) {
            globalState.appController.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          label: l10n.systemProxy,
          onClick: (_) {
            globalState.appController.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(MenuItem.separator());
    }
    final autoStartMenuItem = MenuItem.checkbox(
      label: l10n.autoLaunch,
      onClick: (_) async {
        globalState.appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final copyEnvVarMenuItem = MenuItem(
      label: l10n.copyEnvVar,
      onClick: (_) async {
        await _copyEnv(trayState.port);
      },
    );
    menuItems.add(autoStartMenuItem);
    menuItems.add(copyEnvVarMenuItem);
    menuItems.add(MenuItem.separator());
    final clearCacheAndRestartMenuItem = MenuItem(
      label: l10n.clearCacheAndRestart,
      onClick: (_) async {
        await globalState.appController.handleClearCacheAndRestart();
      },
    );
    menuItems.add(clearCacheAndRestartMenuItem);
    final exitMenuItem = MenuItem(
      label: l10n.exit,
      onClick: (_) async {
        await globalState.appController.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    if (updateSerial != _updateSerial) return;
    await trayManager.setContextMenu(menu);
    if (Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        force: focus,
      );
      if (trayState.isStart) {
        await updateTrayTitle(_lastTitleTraffic);
      }
    }
    if (!trayState.isStart) {
      await updateTrayTitle();
    }
  }

  Future<AppLocalizations> _loadTrayLocalizations(String? localeString) {
    return AppLocalizations.load(_resolveTrayLocale(localeString));
  }

  Locale _resolveTrayLocale(String? localeString) {
    final locale = utils.getLocaleForString(localeString) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return switch (locale.languageCode) {
      'zh' => const Locale.fromSubtags(
          languageCode: 'zh',
          countryCode: 'CN',
        ),
      'en' => const Locale.fromSubtags(languageCode: 'en'),
      _ => const Locale.fromSubtags(languageCode: 'en'),
    };
  }

  String _modeLabel(AppLocalizations l10n, Mode mode) {
    return switch (mode) {
      Mode.rule => l10n.rule,
      Mode.global => l10n.global,
      Mode.direct => l10n.direct,
    };
  }

  updateTrayTitle([Traffic? traffic]) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      return;
    }
    _lastTitleTraffic = traffic;
    if (traffic == null) {
      await trayManager.setTitle("");
      return;
    }
    final up = _compactTrafficText(traffic.up);
    final down = _compactTrafficText(traffic.down);
    await trayManager.setTitle(
      Platform.isLinux ? "↑$up ↓$down" : "↑$up\n↓$down",
    );
  }

  String _compactTrafficText(TrafficValue value) {
    return value.shortShow.replaceAll(' ', '');
  }

  Future<void> _copyEnv(int port) async {
    final url = "http://127.0.0.1:$port";

    final cmdline = Platform.isWindows
        ? "set \$env:all_proxy=$url"
        : "export all_proxy=$url";

    await Clipboard.setData(
      ClipboardData(
        text: cmdline,
      ),
    );
  }
}

final tray = Tray();
