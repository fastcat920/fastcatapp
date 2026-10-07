import 'package:fl_clash/common/single_flight.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';

/// Shared by startup and early SDK consumers. Does not depend on SDK readiness
/// (startup itself awaits the SDK, so doing so would introduce a deadlock).
class ConfigurationBootstrap {
  ConfigurationBootstrap({
    required this.isInitialized,
    required this.hasConfiguration,
    required this.initializeModule,
    required this.refreshConfiguration,
    this.timeout = const Duration(seconds: 35),
  });

  final bool Function() isInitialized;
  final bool Function() hasConfiguration;
  final Future<void> Function() initializeModule;
  final Future<void> Function() refreshConfiguration;
  final Duration timeout;
  final _initialization = SingleFlight<void>();
  final _loading = SingleFlight<void>();

  Future<void> initialize() => _initialization.run(() async {
        if (!isInitialized()) await initializeModule();
      });

  Future<void> ensureReady({bool forceRefresh = false}) {
    if (!_loading.isRunning && !forceRefresh && hasConfiguration()) {
      return Future.value();
    }
    return _loading.run(() async {
      await initialize();
      await refreshConfiguration().timeout(timeout);
      if (!hasConfiguration()) {
        throw StateError('没有可用的 fastcat-config-v2 签名配置');
      }
    });
  }
}

final sdkConfigurationBootstrap = ConfigurationBootstrap(
  isInitialized: () => XBoardConfig.isInitialized,
  hasConfiguration: () =>
      XBoardConfig.isInitialized && XBoardConfig.allPanelUrls.isNotEmpty,
  initializeModule: () => XBoardConfig.initialize(),
  refreshConfiguration: () => XBoardConfig.refresh(),
);
