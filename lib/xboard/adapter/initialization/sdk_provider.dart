import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/gateway_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/state.dart';

part 'generated/sdk_provider.g.dart';

const _logger = FileLogger('sdk_provider');

/// XBoard SDK Provider
///
/// 负责SDK的初始化和生命周期管理
/// - 使用 InitializationProvider 已选定的可用域名（逐个尝试后确定）
/// - 自动加载HTTP配置
/// - 缓存SDK实例
///
/// 注意：不要直接调用此 Provider，应该通过 InitializationProvider.initialize() 触发初始化
@Riverpod(keepAlive: true)
Future<XBoardSDK> xboardSdk(Ref ref) async {
  try {
    _logger.info('[XBoardSdkProvider] 开始初始化SDK');

    final runtime = GatewayRuntimeService.instance;
    await runtime.bootstrapFromCurrentConfig();
    await runtime.verifyAndActivateBestCandidate(
      userAgent: globalState.ua,
      preferCurrent: true,
    );

    // 使用统一网关运行时配置（支持热更新、故障转移、回退）
    final activeConfig = runtime.activeConfig ??
        GatewayEndpointConfig(
          baseUrl: gatewayBaseUrl,
          apiPrefix: currentGatewayApiPrefix,
          source: 'bootstrap_fallback',
          updatedAt: DateTime.now(),
        );
    final gatewayUrls = runtime.candidates.map((item) => item.baseUrl).toList();
    final selectedUrl = activeConfig.baseUrl;

    _logger.info(
      '[XBoardSdkProvider] 使用网关地址: ${gatewayDisplayLabel(selectedUrl)}',
    );


    // 2. 获取面板类型（通过provider接口）
    final panelType = XBoardConfig.provider.getPanelType();
    if (panelType.isEmpty) {
      throw Exception('无法获取面板类型，请检查配置');
    }

    _logger.info('[XBoardSdkProvider] 面板类型: $panelType');

    // 3. 使用直连（已移除域名竞速和代理逻辑）
    _logger.info('[XBoardSdkProvider] 使用直连');

    // 4. 加载HTTP配置
    _logger.info('[XBoardSdkProvider] 加载HTTP配置...');
    final httpConfig = await _loadHttpConfig(
      disableCertificatePinning: gatewayUrls.isNotEmpty,
    );
    _logger.info('[XBoardSdkProvider] HTTP配置加载完成');

    // 5. 获取 API 前缀
    final apiPrefix = activeConfig.apiPrefix;
    _logger.info('[XBoardSdkProvider] API前缀: $apiPrefix');

    // 6. 初始化SDK
    final sdk = XBoardSDK.instance;
    // 网关故障转移：连接失败时自动切换到备用地址（SDK nextUrlProvider 机制）
    final attemptedFailoverUrls = <String>{selectedUrl};

    await sdk.initialize(
      selectedUrl,
      panelType: panelType,
      httpConfig: httpConfig,
      apiPrefix: apiPrefix,
      nextEndpointProvider: () async {
        runtime.syncFromCurrentConfig();
        final next = runtime.nextFailoverCandidate(attemptedFailoverUrls);
        if (next == null) return null;
        attemptedFailoverUrls.add(next.baseUrl);
        return HttpEndpointConfig(
          baseUrl: next.baseUrl,
          apiPrefix: next.apiPrefix,
        );
      },
      onGatewayUrlsUpdated: (urls) {
        _logger.info(
          '[XBoardSdkProvider] 登录响应更新网关地址: ${urls.map(gatewayDisplayLabel).toList()}',
        );
        XBoardConfig.setGatewayUrls(urls);
        runtime.mergeGatewayUrls(
          urls,
          apiPrefix: sdk.httpService.apiPrefix,
          versionTag: XBoardConfig.configVersion,
        );
      },
      onFailoverSuccess: (url) {
        _logger.info(
          '[XBoardSdkProvider] 故障转移成功，提升 URL: ${gatewayDisplayLabel(url)}',
        );
        XBoardConfig.promoteGatewayUrl(url);
      },
      onEndpointFailoverSuccess: (endpoint) {
        runtime.markSuccess(
          endpoint.baseUrl,
          apiPrefix: endpoint.apiPrefix,
          source: 'sdk_failover',
          versionTag: activeConfig.versionTag ?? XBoardConfig.configVersion,
        );
      },
      onEndpointFailure: (endpoint, error) {
        runtime.markFailure(
          endpoint.baseUrl,
          apiPrefix: endpoint.apiPrefix,
          source: 'sdk_request',
          error: error,
        );
      },
    );

    final runtimeSub = runtime.stream.listen((snapshot) {
      final active = snapshot.activeConfig;
      if (active == null || !sdk.isInitialized) return;
      if (sdk.httpService.baseUrl == active.baseUrl &&
          sdk.httpService.apiPrefix == active.apiPrefix) {
        return;
      }
      _logger.info(
        '[XBoardSdkProvider] 运行时切换网关: ${gatewayDisplayLabel(active.baseUrl)}${active.apiPrefix}',
      );
      sdk.updateEndpoint(
        active.baseUrl,
        apiPrefix: active.apiPrefix,
      );
      attemptedFailoverUrls
        ..clear()
        ..add(active.baseUrl);
    });
    ref.onDispose(runtimeSub.cancel);

    final configSub = XBoardConfig.configChangeStream.listen((_) async {
      runtime.syncFromCurrentConfig();
      final verified = await runtime.verifyAndActivateBestCandidate(
        userAgent: globalState.ua,
        preferCurrent: true,
      );
      if (verified != null) {
        _logger.info(
          '[XBoardSdkProvider] 远程配置验证通过: ${gatewayDisplayLabel(verified.baseUrl)}${verified.apiPrefix}',
        );
      }
    });
    ref.onDispose(configSub.cancel);

    final eventSub = runtime.events.listen((event) {
      _logger.info(
        '[XBoardSdkProvider] GatewayEvent ${event.type}: ${event.message} ${event.payload}',
      );
    });
    ref.onDispose(eventSub.cancel);

    _logger.info('[XBoardSdkProvider] SDK初始化成功');
    return sdk;
  } catch (e, stackTrace) {
    _logger.error('[XBoardSdkProvider] SDK初始化失败', e, stackTrace);
    rethrow;
  }
}

/// 加载HTTP配置
Future<HttpConfig> _loadHttpConfig({
  bool disableCertificatePinning = false,
}) async {
  try {
    if (disableCertificatePinning) {
      return HttpConfig.development(userAgent: globalState.ua);
    }

    final certConfig = await ConfigFileLoaderHelper.getCertificateConfig();
    final certPath = certConfig['path'] as String?;
    final certEnabled = certConfig['enabled'] as bool? ?? true;

    return HttpConfig(
      userAgent: globalState.ua,
      certificatePath: certEnabled ? certPath : null,
      enableCertificatePinning: certEnabled && certPath != null,
    );
  } catch (e) {
    _logger.error('[XBoardSdkProvider] 加载HTTP配置失败，使用默认配置', e);
    return HttpConfig.defaultConfig();
  }
}
