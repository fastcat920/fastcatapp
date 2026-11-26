import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 订阅URL辅助工具
///
/// 用于解析和处理订阅URL，提取token等信息
class SubscriptionUrlHelper {
  static bool _initialized = false;

  /// 初始化URL辅助工具
  ///
  /// 执行必要的初始化操作
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
  }

  /// 从订阅URL中提取token
  ///
  /// 支持多种URL格式：
  /// - https://domain.com/api/v1/client/subscribe?token=xxx
  /// - https://domain.com/api/v2/subscription-encrypt/xxx
  /// - https://domain.com/subscription/xxx
  static String? extractTokenFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // 方式1: 查询参数中的token
      if (uri.queryParameters.containsKey('token')) {
        return uri.queryParameters['token'];
      }

      // 方式2: 路径中的最后一段作为token
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // 验证是否像token（一般是32位或更长的十六进制字符串）
        if (lastSegment.length >= 16 &&
            RegExp(r'^[a-f0-9]+$').hasMatch(lastSegment)) {
          return lastSegment;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查URL是否为加密订阅URL
  ///
  /// 通过路径中是否包含 encrypt 关键字判断
  static bool isEncryptedSubscriptionUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();

      return path.contains('encrypt');
    } catch (e) {
      return false;
    }
  }

  /// 判断URL是否需要使用加密订阅服务
  ///
  /// 只有路径中明确包含 "encrypt" 关键字才走加密路径。
  /// 注意：不能用"能提取到 token"来判断，因为 v2board 和 XBoard 的普通订阅链接
  /// 都带有 ?token=xxx 参数，误判为加密路径会导致 v2board 订阅加载失败。
  static bool shouldUseEncryptedService(String url) {
    return isEncryptedSubscriptionUrl(url);
  }

  static bool _hasCoreSymbol(String name) {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final core = Platform.isAndroid
          ? DynamicLibrary.open('libclash.so')
          : DynamicLibrary.process();
      return core.providesSymbol(name);
    } on ArgumentError {
      return false;
    }
  }

  static int _nativeFCNVersion() {
    if (!_hasCoreSymbol('fastCatSupportsFCN')) return 0;
    final core = Platform.isAndroid
        ? DynamicLibrary.open('libclash.so')
        : DynamicLibrary.process();
    return core.lookupFunction<Int32 Function(), int Function()>(
        'fastCatSupportsFCN')();
  }

  static final Future<int> _desktopFCNVersion = _probeDesktopFCNVersion();

  static Future<int> _probeDesktopFCNVersion() async {
    Process? process;
    try {
      final core = p.join(
        p.dirname(Platform.resolvedExecutable),
        Platform.isWindows ? 'fastcatCore.exe' : 'fastcatCore',
      );
      final helper = await Process.start(
        core,
        ['--supports-fcn-v3'],
        mode: Platform.isWindows
            ? ProcessStartMode.detachedWithStdio
            : ProcessStartMode.normal,
      );
      process = helper;
      final output = helper.stdout.transform(utf8.decoder).join();
      final errors = helper.stderr.drain<void>();
      return await (() async {
        // Windows uses a detached process to avoid opening a console window.
        final status = Platform.isWindows ? 0 : await helper.exitCode;
        await errors;
        return status == 0 && (await output).trim() == 'fcn-v3' ? 3 : 0;
      })().timeout(const Duration(seconds: 2));
    } catch (_) {
      process?.kill();
      return 0;
    }
  }

  static Future<String> ensureFastCatFlagForCore(String url) async {
    final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final fcnVersion = desktop
        ? await _desktopFCNVersion
        : null;
    return ensureFastCatFlag(url, fcnVersion: fcnVersion);
  }

  static String ensureFastCatFlag(
    String url, {
    bool? supportsFCN,
    bool? supportsFCNPinning,
    int? fcnVersion,
  }) {
    const flag = String.fromEnvironment(
      'FASTCAT_SUBSCRIPTION_FLAG',
      defaultValue: 'fastcat-v1',
    );
    try {
      final uri = Uri.parse(url);
      final query = Map<String, dynamic>.of(uri.queryParametersAll);
      query.remove('fc_auto');
      query.remove('fc_v2');
      query.remove('fc_transport');
      query.remove('fc_fcn');
      query.remove('fc_fcn_pin');
      query.remove('fc_fcn3');
      final coreVersion = fcnVersion ?? _nativeFCNVersion();
      if (shouldUseEncryptedService(url) && coreVersion >= 3) {
        query['fc_fcn3'] = '1';
      }
      if (supportsFCN ?? (coreVersion >= 1)) {
        query['fc_fcn'] = '1';
        if (supportsFCNPinning ?? (coreVersion >= 2)) {
          query['fc_fcn_pin'] = '1';
        }
      }
      query['flag'] = flag;
      return uri.replace(queryParameters: query).toString();
    } catch (_) {
      return url;
    }
  }

  @Deprecated('Use ensureFastCatFlag')
  static String ensureMetaFlag(String url) => ensureFastCatFlag(url);
}
