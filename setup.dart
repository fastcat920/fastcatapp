// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

enum Target {
  windows,
  linux,
  android,
  macos,
}

extension TargetExt on Target {
  String get os {
    if (this == Target.macos) {
      return "darwin";
    }
    return name;
  }

  bool get same {
    if (this == Target.android) {
      return true;
    }
    if (Platform.isWindows && this == Target.windows) {
      return true;
    }
    if (Platform.isLinux && this == Target.linux) {
      return true;
    }
    if (Platform.isMacOS && this == Target.macos) {
      return true;
    }
    return false;
  }

  String get dynamicLibExtensionName {
    final String extensionName;
    switch (this) {
      case Target.android || Target.linux:
        extensionName = ".so";
        break;
      case Target.windows:
        extensionName = ".dll";
        break;
      case Target.macos:
        extensionName = ".dylib";
        break;
    }
    return extensionName;
  }

  String get executableExtensionName {
    final String extensionName;
    switch (this) {
      case Target.windows:
        extensionName = ".exe";
        break;
      default:
        extensionName = "";
        break;
    }
    return extensionName;
  }
}

enum Mode { core, lib }

enum Arch { amd64, arm64, arm, universal }

class BuildItem {
  Target target;
  Arch? arch;
  String? archName;

  BuildItem({
    required this.target,
    this.arch,
    this.archName,
  });

  @override
  String toString() {
    return 'BuildLibItem{target: $target, arch: $arch, archName: $archName}';
  }
}

class Build {
  static List<BuildItem> get buildItems => [
        BuildItem(
          target: Target.macos,
          arch: Arch.arm64,
          archName: 'arm64',
        ),
        BuildItem(
          target: Target.macos,
          arch: Arch.amd64,
          archName: 'amd64',
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm,
          archName: 'armeabi-v7a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm64,
          archName: 'arm64-v8a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.amd64,
          archName: 'x86_64',
        ),
      ];

  static String get appName => _loadAppBrandConfig().appName;

  /// 读取 pubspec.yaml 中的版本号（如 3.3.5）
  static String get appVersion {
    final pubspecFile = File(join(current, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return '';
    final doc = loadYaml(pubspecFile.readAsStringSync());
    final version = doc['version']?.toString() ?? '';
    // 去掉构建号后缀（如 3.3.5+1 → 3.3.5）
    return version.split('+').first;
  }

  static String get appNameEn => _loadAppBrandConfig().appNameEn;

  static String get coreName => "fastcatCore";

  static String get libName => "libclash";

  static String get outDir => join(current, libName);

  static String get _coreDir => join(current, "core");

  static String get _servicesDir => join(current, "services", "helper");

  static String get distPath => join(current, "dist");

  static String get localNpmPrefix => join(current, ".dart_tool", "npm");

  static String get appdmgExecutable => join(
        localNpmPrefix,
        "node_modules",
        ".bin",
        Platform.isWindows ? "appdmg.cmd" : "appdmg",
      );

  static Map<String, String> commandEnvironment([
    Map<String, String>? overrides,
  ]) {
    final env = Map<String, String>.from(Platform.environment);
    final pathParts = [
      join(current, ".dart_tool", "npm", "node_modules", ".bin"),
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "/bin",
      "/usr/sbin",
      "/sbin",
      if (env["PATH"] != null) env["PATH"]!,
    ];
    env["PATH"] = pathParts.where((part) => part.isNotEmpty).join(":");
    if (overrides != null) {
      env.addAll(overrides);
    }
    return env;
  }

  static String _getCc(BuildItem buildItem) {
    final environment = Platform.environment;
    if (buildItem.target == Target.android) {
      final ndk = environment["ANDROID_NDK"];
      assert(ndk != null);
      final prebuiltDir =
          Directory(join(ndk!, "toolchains", "llvm", "prebuilt"));
      final prebuiltDirList = prebuiltDir.listSync();
      final map = {
        "armeabi-v7a": "armv7a-linux-androideabi21-clang",
        "arm64-v8a": "aarch64-linux-android21-clang",
        "x86": "i686-linux-android21-clang",
        "x86_64": "x86_64-linux-android21-clang"
      };
      return join(
        prebuiltDirList.first.path,
        "bin",
        map[buildItem.archName],
      );
    }
    return "gcc";
  }

  static get tags => "with_gvisor";

  static Future<void> exec(
    List<String> executable, {
    String? name,
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = true,
  }) async {
    if (name != null) print("run $name");
    final process = await Process.start(
      executable[0],
      executable.sublist(1),
      environment: commandEnvironment(environment),
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    process.stdout.listen((data) {
      try {
        print(utf8.decode(data));
      } catch (e) {
        // 如果UTF-8解码失败，使用latin1编码或直接输出原始数据
        print(String.fromCharCodes(data));
      }
    });
    process.stderr.listen((data) {
      try {
        print(utf8.decode(data));
      } catch (e) {
        // 如果UTF-8解码失败，使用latin1编码或直接输出原始数据
        print(String.fromCharCodes(data));
      }
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0 && name != null) throw "$name error";
  }

  static Future<String> calcSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw "File not exists";
    }
    final stream = file.openRead();
    return sha256.convert(await stream.reduce((a, b) => a + b)).toString();
  }

  static Future<List<String>> buildCore({
    required Mode mode,
    required Target target,
    Arch? arch,
  }) async {
    final isLib = mode == Mode.lib;

    final items = buildItems.where(
      (element) {
        return element.target == target &&
            (arch == null ? true : element.arch == arch);
      },
    ).toList();

    final List<String> corePaths = [];

    for (final item in items) {
      final outFileDir = join(
        outDir,
        item.target.name,
        item.archName,
      );

      final file = File(outFileDir);
      if (file.existsSync()) {
        file.deleteSync(recursive: true);
      }

      final fileName = isLib
          ? "$libName${item.target.dynamicLibExtensionName}"
          : "$coreName${item.target.executableExtensionName}";
      final outPath = join(
        outFileDir,
        fileName,
      );
      corePaths.add(outPath);

      final Map<String, String> env = {};
      env["GOOS"] = item.target.os;
      if (item.arch != null) {
        env["GOARCH"] = item.arch!.name;
      }
      if (isLib) {
        env["CGO_ENABLED"] = "1";
        env["CC"] = _getCc(item);
        env["CFLAGS"] = "-O3 -Werror";
      } else {
        env["CGO_ENABLED"] = "0";
      }

      final execLines = [
        "go",
        "build",
        "-ldflags=-w -s",
        "-tags=$tags",
        if (isLib) "-buildmode=c-shared",
        "-o",
        outPath,
      ];
      await exec(
        execLines,
        name: "build core",
        environment: env,
        workingDirectory: _coreDir,
      );
    }

    return corePaths;
  }

  static buildHelper(Target target, String token) async {
    await exec(
      [
        "cargo",
        "build",
        "--release",
        "--features",
        "windows-service",
      ],
      environment: {
        "TOKEN": token,
      },
      name: "build helper",
      workingDirectory: _servicesDir,
    );
    final outPath = join(
      _servicesDir,
      "target",
      "release",
      "helper${target.executableExtensionName}",
    );
    final targetPath = join(
      outDir,
      target.name,
      "fastcatHelperService${target.executableExtensionName}",
    );
    await File(outPath).copy(targetPath);
  }

  static List<String> getExecutable(String command) {
    return command.split(" ");
  }

  static getDistributor() async {
    final distributorDir = join(
      current,
      "plugins",
      "flutter_distributor",
      "packages",
      "flutter_distributor",
    );

    await exec(
      name: "clean distributor",
      Build.getExecutable("flutter clean"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "upgrade distributor",
      Build.getExecutable("flutter pub upgrade"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "get distributor",
      Build.getExecutable("dart pub global activate -s path $distributorDir"),
    );
  }

  static copyFile(String sourceFilePath, String destinationFilePath) {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw "SourceFilePath not exists";
    }
    final destinationFile = File(destinationFilePath);
    final destinationDirectory = destinationFile.parent;
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }
    try {
      sourceFile.copySync(destinationFilePath);
      print("File copied successfully!");
    } catch (e) {
      print("Failed to copy file: $e");
    }
  }
}

class _AppBrandConfig {
  final String appName;
  final String appNameEn;

  const _AppBrandConfig({
    required this.appName,
    required this.appNameEn,
  });
}

_AppBrandConfig? _cachedAppBrandConfig;

_AppBrandConfig _loadAppBrandConfig() {
  final cached = _cachedAppBrandConfig;
  if (cached != null) return cached;

  String? yamlAppName;
  String? yamlAppNameEn;
  final configFile = File(join(current, 'assets', 'config', 'config.yaml'));
  if (configFile.existsSync()) {
    try {
      final doc = loadYaml(configFile.readAsStringSync());
      if (doc is YamlMap) {
        yamlAppName = _nonEmptyString(doc['app_name']);
        yamlAppNameEn = _nonEmptyString(doc['app_name_en']);
      }
    } catch (e) {
      print('[setup.dart] ⚠️ 读取 assets/config/config.yaml 应用名称失败: $e');
    }
  }

  final envAppName = _nonEmptyString(Platform.environment['APP_NAME']);
  final envAppNameEn = _nonEmptyString(Platform.environment['APP_NAME_EN']);
  final appName = envAppName ?? yamlAppName ?? 'fastcat';
  final appNameEn = _safeAsciiAppName(envAppNameEn ?? yamlAppNameEn ?? appName);
  final config = _AppBrandConfig(appName: appName, appNameEn: appNameEn);
  _cachedAppBrandConfig = config;
  print('[setup.dart] 应用名称配置: appName=$appName, appNameEn=$appNameEn');
  return config;
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _safeAsciiAppName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '')
      .replaceAll(RegExp(r'\.+$'), '')
      .trim();
  return sanitized.isEmpty ? 'fastcat' : sanitized;
}

String _yamlScalar(String value) {
  if (RegExp(r'^[A-Za-z0-9._/:\\-]+$').hasMatch(value)) return value;
  return jsonEncode(value);
}

String _replaceYamlValue(String content, String key, String value) {
  final replacement = '$key: ${_yamlScalar(value)}';
  final pattern = RegExp('^$key:\\s*.*\$', multiLine: true);
  if (pattern.hasMatch(content)) {
    return content.replaceFirst(pattern, replacement);
  }
  final suffix = content.endsWith('\n') ? '' : '\n';
  return '$content$suffix$replacement\n';
}

String _safeAsciiDmgVolumeName(String value) {
  final explicit = Platform.environment["DMG_VOLUME_NAME"];
  final source = explicit?.trim().isNotEmpty == true ? explicit!.trim() : value;
  final ascii = source
      .replaceAll(RegExp(r"[^A-Za-z0-9._ -]+"), "")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
  final fallback = _loadAppBrandConfig()
      .appNameEn
      .replaceAll(RegExp(r"[^A-Za-z0-9._ -]+"), "")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
  final volumeName =
      ascii.isNotEmpty ? ascii : (fallback.isNotEmpty ? fallback : "fastcat");
  return volumeName.length <= 27 ? volumeName : volumeName.substring(0, 27);
}

Map<String, dynamic> _macosDmgConfigWithNames({
  required File sourceFile,
  required String productName,
  required String volumeName,
}) {
  final config =
      jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
  config["title"] = volumeName;

  final contents = config["contents"];
  if (contents is List) {
    for (final item in contents) {
      if (item is Map<String, dynamic> &&
          item["type"] == "file" &&
          "${item["path"]}".endsWith(".app")) {
        item["path"] = "$productName.app";
      }
    }
  }

  return config;
}

class BuildCommand extends Command {
  Target target;

  BuildCommand({
    required this.target,
  }) {
    if (target == Target.android || target == Target.linux) {
      argParser.addOption(
        "arch",
        valueHelp: arches.map((e) => e.name).join(','),
        help: 'The $name build desc',
      );
    } else {
      argParser.addOption(
        "arch",
        help: 'The $name build archName',
      );
    }
    argParser.addOption(
      "out",
      valueHelp: [
        if (target.same) "app",
        "core",
      ].join(','),
      help: 'The $name build arch',
    );
    argParser.addOption(
      "env",
      valueHelp: [
        "pre",
        "stable",
      ].join(','),
      help: 'The $name build env',
    );
  }

  @override
  String get description => "build $name application";

  @override
  String get name => target.name;

  List<Arch> get arches => Build.buildItems
      .where((element) => element.target == target && element.arch != null)
      .map((e) => e.arch!)
      .toList();

  _getLinuxDependencies(Arch arch) async {
    await Build.exec(
      Build.getExecutable("sudo apt update -y"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y ninja-build libgtk-3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y libayatana-appindicator3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt-get install -y libkeybinder-3.0-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y locate"),
    );
    if (arch == Arch.amd64) {
      await Build.exec(
        Build.getExecutable("sudo apt install -y rpm patchelf"),
      );
      await Build.exec(
        Build.getExecutable("sudo apt install -y libfuse2"),
      );

      final downloadName = arch == Arch.amd64 ? "x86_64" : "aarch64";
      await Build.exec(
        Build.getExecutable(
          "wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "chmod +x appimagetool",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "sudo mv appimagetool /usr/local/bin/",
        ),
      );
    }
  }

  _getMacosDependencies() async {
    final npmDir = Directory(Build.localNpmPrefix);
    if (!npmDir.existsSync()) {
      npmDir.createSync(recursive: true);
    }
    try {
      await Build.exec(
        ["npm", "install", "--prefix", Build.localNpmPrefix, "appdmg"],
        name: "install appdmg locally",
      );
    } catch (e) {
      print("[setup.dart] appdmg unavailable, will use hdiutil fallback: $e");
    }
  }

  /// 从 CI 环境变量构造 --build-dart-define 参数串
  ///
  /// XOR_KEY / OSS_URL_1..4 / PANEL_TYPE 由 build.yaml 在 Build 步骤中
  /// 通过 env: 注入，setup.dart 读取后转为 dart-define 传给 flutter build。
  String get _dartDefinesArgs {
    const keys = [
      'XOR_KEY',
      'OSS_URL_1',
      'OSS_URL_2',
      'OSS_URL_3',
      'OSS_URL_4',
      'PANEL_TYPE',
      'API_PREFIX',
      'APP_NAME',
      'APP_NAME_EN',
    ];
    final sb = StringBuffer();
    for (final key in keys) {
      var val = _dartDefineValueForKey(key);
      if (val != null && val.isNotEmpty) {
        // 修正 MSYS/Git Bash 路径转换：/api/v1 → C:/Program Files/Git/api/v1
        if (key == 'API_PREFIX' && RegExp(r'^[A-Z]:[/\\]').hasMatch(val)) {
          final original = val;
          val = val
              .replaceFirst(
                  RegExp(r'^[A-Z]:[/\\](?:Program Files[/\\]Git)?'), '')
              .replaceAll('\\', '/');
          if (!val.startsWith('/')) val = '/$val';
          print('[setup.dart] ⚠️ $key 被 MSYS 路径转换: $original → 已修正为: $val');
        }
        sb.write(' --build-dart-define=$key=$val');
        // 打印已注入的 key（隐藏敏感值）
        final masked = key == 'XOR_KEY'
            ? '***${val.length}chars***'
            : (val.length > 20 ? '${val.substring(0, 20)}...' : val);
        print('[setup.dart] dart-define: $key=$masked');
      } else {
        print('[setup.dart] dart-define: $key=(未设置)');
      }
    }
    return sb.toString();
  }

  /// Get dart-define flags as a string list for direct `flutter build` calls.
  /// Unlike [_dartDefinesArgs] (for flutter_distributor), this returns
  /// `--dart-define=KEY=VAL` format suitable for `flutter build apk` etc.
  List<String> _dartDefineList(String env) {
    const keys = [
      'XOR_KEY',
      'OSS_URL_1',
      'OSS_URL_2',
      'OSS_URL_3',
      'OSS_URL_4',
      'PANEL_TYPE',
      'API_PREFIX',
      'APP_NAME',
      'APP_NAME_EN',
    ];
    final result = <String>['--dart-define=APP_ENV=$env'];
    for (final key in keys) {
      var val = _dartDefineValueForKey(key);
      if (val != null && val.isNotEmpty) {
        // 修正 MSYS/Git Bash 路径转换
        if (key == 'API_PREFIX' && RegExp(r'^[A-Z]:[/\\]').hasMatch(val)) {
          val = val
              .replaceFirst(
                  RegExp(r'^[A-Z]:[/\\](?:Program Files[/\\]Git)?'), '')
              .replaceAll('\\', '/');
          if (!val.startsWith('/')) val = '/$val';
        }
        result.add('--dart-define=$key=$val');
      }
    }
    return result;
  }

  String? _dartDefineValueForKey(String key) {
    if (key == 'APP_NAME') return _loadAppBrandConfig().appName;
    if (key == 'APP_NAME_EN') return _loadAppBrandConfig().appNameEn;
    return Platform.environment[key];
  }

  String _appleScriptLiteral(String value) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }

  Future<void> _reinforceMacosDmgFinderLayout({
    required File dmgFile,
    required String productName,
    required String volumeName,
  }) async {
    if (!Platform.isMacOS) return;

    final baseName = basenameWithoutExtension(dmgFile.path);
    final rwDmg = File(join(Build.distPath, "$baseName-layout-rw.dmg"));
    final finalDmg = File(join(Build.distPath, "$baseName-layout-final.dmg"));
    final mountPoint = Directory(join(Build.distPath, "dmg-layout-mount"));

    for (final file in [rwDmg, finalDmg]) {
      if (file.existsSync()) file.deleteSync();
    }
    if (mountPoint.existsSync()) {
      await mountPoint.delete(recursive: true);
    }
    await mountPoint.create(recursive: true);

    await Build.exec(
      [
        "hdiutil",
        "convert",
        dmgFile.path,
        "-format",
        "UDRW",
        "-o",
        rwDmg.path,
      ],
      name: "prepare macos dmg finder layout",
    );

    var attached = false;
    await Build.exec(
      [
        "hdiutil",
        "attach",
        rwDmg.path,
        "-readwrite",
        "-noverify",
        "-noautoopen",
        "-mountpoint",
        mountPoint.path,
      ],
      name: "mount macos dmg for finder layout",
    );
    attached = true;

    try {
      final backgroundCandidates = [
        File(join(mountPoint.path, ".background", "background.tiff")),
        File(join(mountPoint.path, ".background", "background.png")),
        File(join(mountPoint.path, "background.tiff")),
        File(join(mountPoint.path, "background.png")),
      ];
      final backgroundFile = backgroundCandidates.firstWhere(
        (file) => file.existsSync(),
        orElse: () => backgroundCandidates.last,
      );
      if (!backgroundFile.existsSync()) {
        throw "DMG background file not found in ${mountPoint.path}";
      }

      final appItemName = "$productName.app";
      final script = '''
tell application "Finder"
  set dmgWindowName to ${_appleScriptLiteral(volumeName)}
  try
    close every Finder window whose name is dmgWindowName
  end try
  activate
  set dmgFolder to (POSIX file ${_appleScriptLiteral(mountPoint.path)}) as alias
  open dmgFolder
  delay 1
  try
    set dmgWindow to container window of dmgFolder
  on error
    set dmgWindow to first Finder window whose name is dmgWindowName
  end try
  set current view of dmgWindow to icon view
  try
    set toolbar visible of dmgWindow to false
  end try
  try
    set statusbar visible of dmgWindow to false
  end try
  try
    set pathbar visible of dmgWindow to false
  end try
  set bounds of dmgWindow to {220, 120, 860, 562}
  set viewOptions to icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 144
  set background picture of viewOptions to (POSIX file ${_appleScriptLiteral(backgroundFile.path)}) as alias
  try
    set position of item ${_appleScriptLiteral(appItemName)} of dmgFolder to {172, 236}
  end try
  try
    set position of item "Applications" of dmgFolder to {476, 236}
  end try
  update dmgFolder without registering applications
  delay 1
  try
    close dmgWindow
  end try
  delay 0.5
end tell
''';

      await Build.exec(
        ["osascript", "-e", script],
        name: "apply macos dmg finder background",
      );
      try {
        await Build.exec(
          ["bless", "--folder", mountPoint.path],
          name: "bless macos dmg folder",
        );
      } catch (_) {
        print("[setup.dart] bless skipped (Apple Silicon or volume issue)");
      }
    } finally {
      if (attached) {
        await Build.exec(
          ["hdiutil", "detach", mountPoint.path, "-force"],
          name: "detach macos dmg finder layout",
        );
      }
    }

    await Build.exec(
      [
        "hdiutil",
        "convert",
        rwDmg.path,
        "-format",
        "UDZO",
        "-imagekey",
        "zlib-level=9",
        "-o",
        finalDmg.path,
      ],
      name: "compress macos dmg finder layout",
    );
    finalDmg.renameSync(dmgFile.path);
    rwDmg.deleteSync();
    if (mountPoint.existsSync()) {
      await mountPoint.delete(recursive: true);
    }
  }

  _buildDistributor({
    required Target target,
    required String targets,
    String args = '',
    required String env,
  }) async {
    _applyDistributorOptions();
    await Build.getDistributor();
    await Build.exec(
      name: name,
      Build.getExecutable(
        "flutter_distributor package --skip-clean --platform ${target.name} --targets $targets --flutter-build-args=verbose$args --build-dart-define=APP_ENV=$env",
      ),
    );
  }

  Future<void> _buildMacosDmg({
    required String? archName,
    required String env,
  }) async {
    await _getMacosDependencies();
    _applyMacosTrayTitleFontSize();

    await Build.exec(
      [
        "flutter",
        "build",
        "macos",
        "--release",
        ..._dartDefineList(env),
      ],
      name: "build macos app",
    );

    final productName = Platform.environment["APP_NAME"]?.isNotEmpty == true
        ? Platform.environment["APP_NAME"]!
        : Build.appName;
    final dmgVolumeName = _safeAsciiDmgVolumeName(productName);
    if (dmgVolumeName != productName) {
      print(
        "[setup.dart]   ✅ macOS DMG volume name → $dmgVolumeName "
        "(Finder background requires ASCII-safe volume alias)",
      );
    }
    final builtApp = Directory(join(
      current,
      "build",
      "macos",
      "Build",
      "Products",
      "Release",
      "$productName.app",
    ));
    if (!builtApp.existsSync()) {
      throw "Built macOS app not found: ${builtApp.path}";
    }

    final dmgRoot = Directory(join(Build.distPath, "dmg-root"));
    if (dmgRoot.existsSync()) {
      dmgRoot.deleteSync(recursive: true);
    }
    dmgRoot.createSync(recursive: true);

    await Build.exec(
      [
        "cp",
        "-R",
        builtApp.path,
        join(dmgRoot.path, "$productName.app"),
      ],
      name: "copy macos app to dmg root",
    );

    final dmgConfigSourcePath =
        join(current, "macos", "packaging", "dmg", "make_config.json");
    final version = Build.appVersion;
    final dmgFileName = version.isNotEmpty
        ? '${productName}-${version}.dmg'
        : '${productName}.dmg';
    final dmgFile = File(join(Build.distPath, dmgFileName));
    if (dmgFile.existsSync()) {
      dmgFile.deleteSync();
    }

    final dmgBackgroundHiddenDir = Directory(join(dmgRoot.path, ".background"));
    if (!dmgBackgroundHiddenDir.existsSync()) {
      dmgBackgroundHiddenDir.createSync(recursive: true);
    }

    final useAppDmg = File(Build.appdmgExecutable).existsSync() &&
        extension(dmgConfigSourcePath).toLowerCase() == ".json";
    if (useAppDmg) {
      final dmgConfigPath = join(dmgRoot.path, "make_config.json");
      final dmgConfig = _macosDmgConfigWithNames(
        sourceFile: File(dmgConfigSourcePath),
        productName: productName,
        volumeName: dmgVolumeName,
      );
      File(dmgConfigPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(dmgConfig)}\n',
        );
      final dmgBackgroundSourcePath =
          join(current, "macos", "packaging", "dmg", "background.png");
      final dmgBackgroundSource = File(dmgBackgroundSourcePath);
      if (dmgBackgroundSource.existsSync()) {
        dmgBackgroundSource.copySync(join(dmgRoot.path, "background.png"));
        dmgBackgroundSource.copySync(
          join(dmgBackgroundHiddenDir.path, "background.png"),
        );
      }
      final dmgRetinaBackgroundSource = File(join(
        current,
        "macos",
        "packaging",
        "dmg",
        "background@2x.png",
      ));
      if (dmgRetinaBackgroundSource.existsSync()) {
        dmgRetinaBackgroundSource.copySync(
          join(dmgRoot.path, "background@2x.png"),
        );
        dmgRetinaBackgroundSource.copySync(
          join(dmgBackgroundHiddenDir.path, "background@2x.png"),
        );
      }
      await Build.exec(
        [
          Build.appdmgExecutable,
          dmgConfigPath,
          dmgFile.path,
        ],
        name: "create macos dmg${archName == null ? "" : " $archName"}",
      );
      await _reinforceMacosDmgFinderLayout(
        dmgFile: dmgFile,
        productName: productName,
        volumeName: dmgVolumeName,
      );
    } else {
      await Build.exec(
        [
          "hdiutil",
          "create",
          "-volname",
          dmgVolumeName,
          "-srcfolder",
          dmgRoot.path,
          "-ov",
          "-format",
          "UDZO",
          dmgFile.path,
        ],
        name:
            "create macos dmg with hdiutil${archName == null ? "" : " $archName"}",
      );
      await _reinforceMacosDmgFinderLayout(
        dmgFile: dmgFile,
        productName: productName,
        volumeName: dmgVolumeName,
      );
    }
    print("macOS DMG created at: ${dmgFile.path}");
  }

  void _applyMacosTrayTitleFontSize() {
    const trayTitleState = r'''
    var statusItem: NSStatusItem?
    var trayImage: NSImage?
    var trayImagePosition: String = "left"
    var trayTitle: String = ""
''';
    const trayTitleRenderingMethods = r'''
    public func setImage(_ image: NSImage, _ imagePosition: String) {
        trayImage = image
        trayImagePosition = imagePosition
        renderStatusItem()
        self.frame = statusItem!.button!.frame
    }

    public func setImagePosition(_ imagePosition: String) {
        trayImagePosition = imagePosition
        renderStatusItem()
        self.frame = statusItem!.button!.frame
    }

    public func removeImage() {
        trayImage = nil
        renderStatusItem()
        self.frame = statusItem!.button!.frame
    }

    public func setTitle(_ title: String) {
        trayTitle = title
        renderStatusItem()
        self.frame = statusItem!.button!.frame
    }

    private func renderStatusItem() {
        guard let button = statusItem?.button else { return }

        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")

        if trayTitle.isEmpty {
            button.image = trayImage
            button.imagePosition = trayImagePosition == "right" ? NSControl.ImagePosition.imageRight : NSControl.ImagePosition.imageLeft
            statusItem?.length = NSStatusItem.variableLength
            return
        }

        button.imagePosition = .imageOnly
        button.image = makeStatusBarImage()
        statusItem?.length = NSStatusItem.variableLength
    }

    private func makeStatusBarImage() -> NSImage {
        let statusHeight = max(statusItem?.button?.bounds.height ?? 0, NSStatusBar.system.thickness, 22)
        let canvasHeight = max(18, statusHeight)
        let iconSide = trayImage == nil ? 0 : max(16, min(18, canvasHeight - 4))
        let gap: CGFloat = trayImage == nil ? 0 : 4
        let horizontalInset: CGFloat = 2
        let fontSize = max(7.5, min(9.6, floor((canvasHeight - 3) / 2)))
        let lineHeight = fontSize - 0.8
        let lines = trayTitle.components(separatedBy: "\n")
        let upperText = lines.indices.contains(0) ? lines[0] : ""
        let lowerText = lines.indices.contains(1) ? lines[1] : ""
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let upperSize = (upperText as NSString).size(withAttributes: textAttributes)
        let lowerSize = (lowerText as NSString).size(withAttributes: textAttributes)
        let textWidth = ceil(max(upperSize.width, lowerSize.width))
        let canvasWidth = horizontalInset * 2 + iconSide + gap + textWidth
        let image = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()

        if let trayImage = trayImage {
            let iconRect = NSRect(
                x: horizontalInset,
                y: (canvasHeight - iconSide) / 2,
                width: iconSide,
                height: iconSide
            )
            trayImage.draw(in: iconRect)
        }

        let textX = horizontalInset + iconSide + gap
        let totalTextHeight = lineHeight * 2
        let topY = (canvasHeight + totalTextHeight) / 2 - lineHeight - 0.5
        let bottomY = topY - lineHeight
        (upperText as NSString).draw(at: NSPoint(x: textX, y: topY), withAttributes: textAttributes)
        (lowerText as NSString).draw(at: NSPoint(x: textX, y: bottomY), withAttributes: textAttributes)
        image.unlockFocus()
        image.isTemplate = trayImage?.isTemplate ?? true
        return image
    }
''';
    final hostedRoot = Directory(join(
      Platform.environment['HOME'] ?? '',
      '.pub-cache',
      'hosted',
      'pub.dev',
    ));
    if (!hostedRoot.existsSync()) return;

    final trayManagerDirs = hostedRoot
        .listSync()
        .whereType<Directory>()
        .where((dir) => basename(dir.path).startsWith('tray_manager-'));

    for (final dir in trayManagerDirs) {
      final trayIconFile =
          File(join(dir.path, 'macos', 'Classes', 'TrayIcon.swift'));
      if (!trayIconFile.existsSync()) continue;

      final content = trayIconFile.readAsStringSync();
      var patched = content.replaceFirst(
        RegExp(
          r'    var statusItem: NSStatusItem\?\n(?:    var trayImage: NSImage\?\n    var trayImagePosition: String = "left"\n    var trayTitle: String = ""\n)?',
        ),
        trayTitleState,
      );
      patched = patched.replaceFirst(
        RegExp(
          r'    public func setImage\(_ image: NSImage, _ imagePosition: String\) \{[\s\S]*?\n    \}\n    \n    public func setToolTip',
        ),
        '$trayTitleRenderingMethods\n    public func setToolTip',
      );
      if (patched == content) continue;

      trayIconFile.writeAsStringSync(patched);
      print('[setup.dart]   ✅ tray_manager 状态栏流量渲染 → 菜单栏高度自适应两行');
    }
  }

  Future<String?> get systemArch async {
    if (Platform.isWindows) {
      return Platform.environment["PROCESSOR_ARCHITECTURE"];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> run() async {
    final mode = target == Target.android ? Mode.lib : Mode.core;
    final String out = argResults?["out"] ?? (target.same ? "app" : "core");
    final rawArchName = argResults?["arch"];
    final archName = target == Target.macos &&
            (rawArchName == null || rawArchName.toString().trim().isEmpty)
        ? "universal"
        : rawArchName;
    final env = argResults?["env"] ?? "stable";
    final Arch? arch;
    if (archName == "universal" && target == Target.macos) {
      arch = Arch.universal;
    } else {
      final currentArches =
          arches.where((element) => element.name == archName).toList();
      arch = currentArches.isEmpty ? null : currentArches.first;
    }

    if (arch == null && target != Target.android) {
      throw "Invalid arch parameter";
    }

    // macOS universal: build both arm64 & amd64 cores, then lipo merge
    if (target == Target.macos && arch == Arch.universal) {
      final arm64Paths = await Build.buildCore(
        target: target,
        arch: Arch.arm64,
        mode: mode,
      );
      final amd64Paths = await Build.buildCore(
        target: target,
        arch: Arch.amd64,
        mode: mode,
      );

      // lipo merge into universal binary at the path Xcode expects
      final fileName = mode == Mode.lib
          ? "${Build.libName}${target.dynamicLibExtensionName}"
          : "${Build.coreName}${target.executableExtensionName}";
      final universalPath = join(Build.outDir, target.name, fileName);
      final universalDir = Directory(dirname(universalPath));
      if (!universalDir.existsSync()) {
        universalDir.createSync(recursive: true);
      }
      await Build.exec(
        [
          "lipo",
          "-create",
          arm64Paths.first,
          amd64Paths.first,
          "-output",
          universalPath,
        ],
        name: "lipo create universal binary",
      );
      print("Universal binary created at: $universalPath");

      if (out != "app") return;

      _dartDefinesArgs;
      _applyDartConstant();
      _applyMacosAppName();
      await _buildMacosDmg(archName: archName, env: env);
      return;
    }

    final corePaths = await Build.buildCore(
      target: target,
      arch: arch,
      mode: mode,
    );

    if (out != "app") {
      return;
    }

    final ddArgs = _dartDefinesArgs;

    switch (target) {
      case Target.windows:
        _applyDartConstant();
        _applyWindowsAppName();
        final token = target != Target.android
            ? await Build.calcSha256(corePaths.first)
            : null;
        await Build.buildHelper(target, token!);
        await _buildDistributor(
          target: target,
          targets: "zip,exe",
          args:
              " --description $archName --build-dart-define=CORE_SHA256=$token$ddArgs",
          env: env,
        );
        return;
      case Target.linux:
        _applyDartConstant();
        _applyLinuxAppName();
        final targetMap = {
          Arch.arm64: "linux-arm64",
          Arch.amd64: "linux-x64",
        };
        final targets = [
          "deb",
          if (arch == Arch.amd64) "appimage",
          if (arch == Arch.amd64) "rpm",
        ].join(",");
        final defaultTarget = targetMap[arch];
        await _getLinuxDependencies(arch!);
        await _buildDistributor(
          target: target,
          targets: targets,
          args:
              " --description $archName --build-target-platform $defaultTarget$ddArgs",
          env: env,
        );
        return;
      case Target.android:
        _applyDartConstant();
        _applyAndroidAppName();
        final platformMap = {
          Arch.arm: "android-arm",
          Arch.arm64: "android-arm64",
          Arch.amd64: "android-x64",
        };
        final defaultArches = [Arch.arm, Arch.arm64, Arch.amd64];
        final selectedArches = defaultArches
            .where((element) => arch == null ? true : element == arch)
            .toList();
        final targetPlatforms =
            selectedArches.map((e) => platformMap[e]).join(",");

        final distDir = Directory(Build.distPath);
        if (!distDir.existsSync()) {
          distDir.createSync(recursive: true);
        }

        final dartDefines = _dartDefineList(env);

        // Only the mobile APK is built. The mobile package still contains
        // runtime large-screen/remote-control adaptations for projector/TV use.
        final androidFlavor = Platform.environment['ANDROID_FLAVOR'] ?? '';
        if (androidFlavor.isNotEmpty && androidFlavor != 'mobile') {
          throw Exception('Unsupported Android flavor: $androidFlavor');
        }
        final flavors = ['mobile'];
        print('Android flavors to build: $flavors');

        for (final flavor in flavors) {
          print('\n========== Building $flavor APK ==========');
          await Build.exec(
            [
              'flutter',
              'build',
              'apk',
              '--release',
              '--flavor',
              flavor,
              '--target-platform',
              targetPlatforms,
              ...dartDefines,
            ],
            name: 'build $flavor APK',
          );

          // Copy universal APK (contains all selected ABIs) to dist/
          final apkOutputDir = join(
            current,
            'build',
            'app',
            'outputs',
            'flutter-apk',
          );
          final universalSrcCandidates = [
            join(apkOutputDir, 'app-$flavor-release.apk'),
            join(apkOutputDir, 'app-release.apk'),
          ];
          final universalSrc = universalSrcCandidates
              .firstWhere((path) => File(path).existsSync(), orElse: () => '');
          if (universalSrc.isEmpty) {
            throw Exception(
                'Universal APK not found. Tried: ${universalSrcCandidates.join(", ")}');
          }
          final dstApk =
              join(Build.distPath, '${Build.appName}-$flavor-universal.apk');
          Build.copyFile(universalSrc, dstApk);
          print('  ✅ $dstApk');
        }
        return;
      case Target.macos:
        // Copy core binary to the path Xcode expects (libclash/macos/)
        final macosCoreDest = join(Build.outDir, target.name,
            "${Build.coreName}${target.executableExtensionName}");
        Build.copyFile(corePaths.first, macosCoreDest);
        // 用 APP_NAME 环境变量替换应用名称
        _applyDartConstant();
        _applyMacosAppName();
        await _buildMacosDmg(archName: archName, env: env);
        return;
    }
  }
}

/// 用 app_name_en 同步 flutter_distributor 顶层分发名称。
void _applyDistributorOptions() {
  final appNameEn = _loadAppBrandConfig().appNameEn;
  final optionsPath = join(current, 'distribute_options.yaml');
  final optionsFile = File(optionsPath);
  if (!optionsFile.existsSync()) return;

  var content = optionsFile.readAsStringSync();
  content = _replaceYamlValue(content, 'app_name', appNameEn);
  optionsFile.writeAsStringSync(content);
  print('[setup.dart]   ✅ distribute_options.yaml app_name → $appNameEn');
}

/// 用 APP_NAME 环境变量替换 macOS 打包配置中的应用名称
///
/// macOS 架构：
///   PRODUCT_NAME  — .app 包名/可执行文件名，macOS 支持 Unicode
///   DISPLAY_NAME  — 用户可见名（Dock/Finder/关于），支持中文
///
/// 当 APP_NAME 含非 ASCII 字符（如中文）时：
///   PRODUCT_NAME 和 DISPLAY_NAME 设为中文名
///   .app 包名使用中文名；DMG 卷标使用 ASCII 名称以保证 Finder 背景图生效
void _applyMacosAppName() {
  final brand = _loadAppBrandConfig();
  final appName = brand.appName;
  print('[setup.dart] 🍎 macOS 应用名称: $appName');

  // macOS Xcode 原生支持 Unicode，PRODUCT_NAME 可直接使用中文
  // （不同于 Windows CMake / Linux deb 需要 ASCII）
  final productName = appName;

  // 1. AppInfo.xcconfig: PRODUCT_NAME + DISPLAY_NAME
  final xcconfigPath =
      join(current, 'macos', 'Runner', 'Configs', 'AppInfo.xcconfig');
  final xcconfigFile = File(xcconfigPath);
  if (xcconfigFile.existsSync()) {
    var content = xcconfigFile.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'PRODUCT_NAME\s*=\s*.+'),
      'PRODUCT_NAME = $productName',
    );
    content = content.replaceFirst(
      RegExp(r'DISPLAY_NAME\s*=\s*.+'),
      'DISPLAY_NAME = $appName',
    );
    xcconfigFile.writeAsStringSync(content);
    print(
        '[setup.dart]   ✅ AppInfo.xcconfig PRODUCT_NAME → $productName, DISPLAY_NAME → $appName');
  }

  // 2. DMG make_config.json: title 用 ASCII 卷标，.app path 用 PRODUCT_NAME。
  // appdmg 写入的 Finder 背景图 alias 在中文卷标下可能无法解析。
  final dmgConfigPath =
      join(current, 'macos', 'packaging', 'dmg', 'make_config.json');
  final dmgConfigFile = File(dmgConfigPath);
  if (dmgConfigFile.existsSync()) {
    final dmgVolumeName = _safeAsciiDmgVolumeName(appName);
    final config = _macosDmgConfigWithNames(
      sourceFile: dmgConfigFile,
      productName: productName,
      volumeName: dmgVolumeName,
    );
    dmgConfigFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(config)}\n',
    );
    print(
        '[setup.dart]   ✅ make_config.json title → $dmgVolumeName, path → $productName.app');
  }

  // 3. Runner.xcscheme: BuildableName 用 PRODUCT_NAME
  final schemePath = join(current, 'macos', 'Runner.xcodeproj', 'xcshareddata',
      'xcschemes', 'Runner.xcscheme');
  final schemeFile = File(schemePath);
  if (schemeFile.existsSync()) {
    var content = schemeFile.readAsStringSync();
    content = content.replaceAll(
      RegExp(r'BuildableName\s*=\s*"[^"]+\.app"'),
      'BuildableName = "$productName.app"',
    );
    schemeFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ Runner.xcscheme BuildableName → $productName.app');
  }
}

/// 用 APP_NAME 替换 Android strings.xml 中的应用名称
void _applyAndroidAppName() {
  final appName = _loadAppBrandConfig().appName;
  print('[setup.dart] 🤖 Android 应用名称: $appName');

  final stringsPath = join(
      current, 'android', 'app', 'src', 'main', 'res', 'values', 'strings.xml');
  final stringsFile = File(stringsPath);
  if (stringsFile.existsSync()) {
    var content = stringsFile.readAsStringSync();
    content = content.replaceAll(
      RegExp(r'<string name="app_name">[^<]+</string>'),
      '<string name="app_name">$appName</string>',
    );
    content = content.replaceAll(
      RegExp(r'<string name="fl_clash">[^<]+</string>'),
      '<string name="fl_clash">$appName</string>',
    );
    stringsFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ strings.xml app_name → $appName');
  }

  // debug manifest
  final debugManifestPath =
      join(current, 'android', 'app', 'src', 'debug', 'AndroidManifest.xml');
  final debugManifestFile = File(debugManifestPath);
  if (debugManifestFile.existsSync()) {
    var content = debugManifestFile.readAsStringSync();
    content = content.replaceAll(
      RegExp(r'android:label="[^"]+"'),
      'android:label="$appName Debug"',
    );
    debugManifestFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ debug AndroidManifest.xml label → $appName Debug');
  }
}

/// 用 APP_NAME 替换 Dart 常量（应用内 UI 名称、托盘 tooltip 等）
void _applyDartConstant() {
  final brand = _loadAppBrandConfig();
  final appName = brand.appName;
  final appNameEn = brand.appNameEn;
  print('[setup.dart] 📝 Dart constant.dart 应用名称: $appName');

  final constantPath = join(current, 'lib', 'common', 'constant.dart');
  final constantFile = File(constantPath);
  if (constantFile.existsSync()) {
    var content = constantFile.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'const appName\s*=\s*"[^"]*"'),
      'const appName = "$appName"',
    );
    content = content.replaceFirst(
      RegExp(r'const appNameEn\s*=\s*"[^"]*"'),
      'const appNameEn = "$appNameEn"',
    );
    constantFile.writeAsStringSync(content);
    print(
        '[setup.dart]   ✅ constant.dart appName → $appName, appNameEn → $appNameEn');
  }
}

/// 用 app_name / app_name_en 替换 Windows 原生标题和安装包配置
void _applyWindowsAppName() {
  final brand = _loadAppBrandConfig();
  final appName = brand.appName;
  final appNameEn = brand.appNameEn;
  final exeName = '$appNameEn.exe';
  print('[setup.dart] 🪟 Windows 应用名称: $appName ($exeName)');

  final mainCppPath = join(current, 'windows', 'runner', 'main.cpp');
  final mainCppFile = File(mainCppPath);
  if (mainCppFile.existsSync()) {
    var content = mainCppFile.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'window\.Create\(L"[^"]+"'),
      'window.Create(L"$appName"',
    );
    mainCppFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ main.cpp window title → $appName');
  }

  final cmakePath = join(current, 'windows', 'CMakeLists.txt');
  final cmakeFile = File(cmakePath);
  if (cmakeFile.existsSync()) {
    var content = cmakeFile.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'project\([A-Za-z0-9._-]+\s+LANGUAGES\s+CXX\)'),
      'project($appNameEn LANGUAGES CXX)',
    );
    content = content.replaceFirst(
      RegExp(r'set\(BINARY_NAME\s+"[^"]+"\)'),
      'set(BINARY_NAME "$appNameEn")',
    );
    cmakeFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ CMake project / BINARY_NAME → $appNameEn');
  }

  final rcPath = join(current, 'windows', 'runner', 'Runner.rc');
  final rcFile = File(rcPath);
  if (rcFile.existsSync()) {
    var content = rcFile.readAsStringSync();
    content = content.replaceFirst(
      RegExp(r'VALUE "FileDescription", "[^"]*" "\\0"'),
      'VALUE "FileDescription", "$appName" "\\0"',
    );
    content = content.replaceFirst(
      RegExp(r'VALUE "InternalName", "[^"]*" "\\0"'),
      'VALUE "InternalName", "$appNameEn" "\\0"',
    );
    content = content.replaceFirst(
      RegExp(r'VALUE "OriginalFilename", "[^"]*" "\\0"'),
      'VALUE "OriginalFilename", "$exeName" "\\0"',
    );
    content = content.replaceFirst(
      RegExp(r'VALUE "ProductName", "[^"]*" "\\0"'),
      'VALUE "ProductName", "$appName" "\\0"',
    );
    rcFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ Runner.rc 元信息 → $appName / $exeName');
  }

  final makeConfigPath =
      join(current, 'windows', 'packaging', 'exe', 'make_config.yaml');
  final makeConfigFile = File(makeConfigPath);
  if (makeConfigFile.existsSync()) {
    var content = makeConfigFile.readAsStringSync();
    content = _replaceYamlValue(content, 'app_name', appName);
    content = _replaceYamlValue(content, 'display_name', appName);
    content = _replaceYamlValue(content, 'executable_name', exeName);
    content = _replaceYamlValue(content, 'output_base_file_name', exeName);
    makeConfigFile.writeAsStringSync(content);
    print(
        '[setup.dart]   ✅ exe make_config.yaml → display=$appName, exe=$exeName');
  }
}

/// 用 APP_NAME 替换 Linux 原生窗口标题
void _applyLinuxAppName() {
  final appName = _loadAppBrandConfig().appName;
  print('[setup.dart] 🐧 Linux 应用名称: $appName');

  final appPath = join(current, 'linux', 'my_application.cc');
  final appFile = File(appPath);
  if (appFile.existsSync()) {
    var content = appFile.readAsStringSync();
    content = content.replaceAll(
      RegExp(r'gtk_header_bar_set_title\(header_bar,\s*"[^"]+"\)'),
      'gtk_header_bar_set_title(header_bar, "$appName")',
    );
    content = content.replaceAll(
      RegExp(r'gtk_window_set_title\(window,\s*"[^"]+"\)'),
      'gtk_window_set_title(window, "$appName")',
    );
    appFile.writeAsStringSync(content);
    print('[setup.dart]   ✅ my_application.cc window title → $appName');
  }
}

main(args) async {
  final runner = CommandRunner("setup", "build Application");
  runner.addCommand(BuildCommand(target: Target.android));
  runner.addCommand(BuildCommand(target: Target.linux));
  runner.addCommand(BuildCommand(target: Target.windows));
  runner.addCommand(BuildCommand(target: Target.macos));
  await runner.run(args);
}
