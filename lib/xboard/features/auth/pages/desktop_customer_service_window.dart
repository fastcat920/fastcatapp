import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/pages/crisp_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

const desktopCustomerServiceWindowArg = '--fastcat-customer-service-window';
const _windowTitle = '在线客服';
const _windowSize = Size(420, 680);

Process? _customerServiceWindowProcess;

String? desktopCustomerServiceWindowConfigPathFromArgs(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == desktopCustomerServiceWindowArg && i + 1 < args.length) {
      return args[i + 1];
    }
    const prefix = '$desktopCustomerServiceWindowArg=';
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

bool isDesktopCustomerServiceWindowArgs(List<String> args) {
  return desktopCustomerServiceWindowConfigPathFromArgs(args) != null;
}

class DesktopCustomerServiceWindowLauncher {
  DesktopCustomerServiceWindowLauncher._();

  static bool get isSupported => Platform.isWindows || Platform.isLinux;

  static Future<bool> open({
    required String websiteId,
    String? crispProxyUrl,
    String? userScript,
  }) async {
    if (!isSupported) return false;
    if (_customerServiceWindowProcess != null) return true;

    Directory? configDirectory;
    try {
      configDirectory =
          await Directory.systemTemp.createTemp('fastcat-support-');
      final configFile = File(
        '${configDirectory.path}${Platform.pathSeparator}customer_service.json',
      );
      final config = DesktopCustomerServiceWindowConfig(
        websiteId: websiteId,
        crispProxyUrl: crispProxyUrl,
        userScript: userScript,
      );
      await configFile.writeAsString(jsonEncode(config.toJson()));

      final executable = Platform.resolvedExecutable;
      final process = await Process.start(
        executable,
        ['$desktopCustomerServiceWindowArg=${configFile.path}'],
        workingDirectory: File(executable).parent.path,
      );
      _customerServiceWindowProcess = process;
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      unawaited(process.exitCode.whenComplete(() {
        if (identical(_customerServiceWindowProcess, process)) {
          _customerServiceWindowProcess = null;
        }
      }));
      return true;
    } catch (_) {
      if (configDirectory != null) {
        unawaited(_deleteDirectory(configDirectory));
      }
      return false;
    }
  }
}

Future<void> runDesktopCustomerServiceWindow(List<String> args) async {
  final configPath = desktopCustomerServiceWindowConfigPathFromArgs(args);
  if (configPath == null) {
    exit(64);
  }

  WidgetsFlutterBinding.ensureInitialized();
  final config = await _readWindowConfig(configPath);
  await windowManager.ensureInitialized();

  runApp(DesktopCustomerServiceWindowApp(config: config));

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: _windowTitle,
      size: _windowSize,
      minimumSize: _windowSize,
      maximumSize: _windowSize,
      center: true,
      skipTaskbar: false,
    ),
    () async {
      await windowManager.setTitle(_windowTitle);
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

Future<DesktopCustomerServiceWindowConfig> _readWindowConfig(
  String configPath,
) async {
  try {
    final file = File(configPath);
    final json = jsonDecode(await file.readAsString());
    return DesktopCustomerServiceWindowConfig.fromJson(
      json is Map<String, dynamic> ? json : <String, dynamic>{},
    );
  } finally {
    unawaited(_deleteConfigPath(configPath));
  }
}

Future<void> _deleteConfigPath(String configPath) async {
  try {
    final file = File(configPath);
    if (await file.exists()) {
      await file.delete();
    }
    final parent = file.parent;
    if (await parent.exists() && parent.path.contains('fastcat-support-')) {
      await parent.delete();
    }
  } catch (_) {}
}

Future<void> _deleteDirectory(Directory directory) async {
  try {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  } catch (_) {}
}

class DesktopCustomerServiceWindowApp extends StatelessWidget {
  final DesktopCustomerServiceWindowConfig config;

  const DesktopCustomerServiceWindowApp({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _windowTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale?.languageCode == 'zh') {
          return const Locale.fromSubtags(
            languageCode: 'zh',
            countryCode: 'CN',
          );
        }
        return const Locale.fromSubtags(languageCode: 'en');
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: DesktopCrispChatPage(
        websiteId: config.websiteId,
        crispProxyUrl: config.crispProxyUrl,
        userScript: config.userScript,
        showAppBar: false,
      ),
    );
  }
}

class DesktopCustomerServiceWindowConfig {
  final String websiteId;
  final String? crispProxyUrl;
  final String? userScript;

  const DesktopCustomerServiceWindowConfig({
    required this.websiteId,
    this.crispProxyUrl,
    this.userScript,
  });

  factory DesktopCustomerServiceWindowConfig.fromJson(
    Map<String, dynamic> json,
  ) {
    return DesktopCustomerServiceWindowConfig(
      websiteId: json['websiteId']?.toString() ?? '',
      crispProxyUrl: _nullableString(json['crispProxyUrl']),
      userScript: _nullableString(json['userScript']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'websiteId': websiteId,
      if (crispProxyUrl != null) 'crispProxyUrl': crispProxyUrl,
      if (userScript != null) 'userScript': userScript,
    };
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
