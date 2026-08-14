import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClashManager extends ConsumerStatefulWidget {
  final Widget child;

  const ClashManager({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ClashManager> createState() => _ClashContainerState();
}

class _ClashContainerState extends ConsumerState<ClashManager>
    with AppMessageListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    clashMessage.addListener(this);
    ref.listenManual(needSetupProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.handleChangeProfile();
      }
    });
    ref.listenManual(coreStateProvider, (prev, next) async {
      if (prev != next) {
        await clashCore.setState(next);
      }
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        final isTunChange = prev?.tun != next.tun;
        globalState.appController.updateClashConfigDebounce(
          duration:
              isTunChange ? Duration.zero : const Duration(milliseconds: 600),
        );
      }
    });

    ref.listenManual(
      appSettingProvider.select((state) => state.openLogs),
      (prev, next) {
        if (next) {
          clashCore.startLog();
        } else {
          clashCore.stopLog();
        }
      },
    );
  }

  @override
  Future<void> dispose() async {
    clashMessage.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final appController = globalState.appController;
    appController.setDelay(delay);
    debouncer.call(
      FunctionTag.updateDelay,
      () async {
        await appController.updateGroupsDebounce();
      },
      duration: const Duration(milliseconds: 5000),
    );
  }

  @override
  void onLog(Log log) {
    ref.read(logsProvider.notifier).addLog(log);
    // Core warnings include configuration deprecations and transient network
    // notices. Keep them in the log page instead of interrupting the user.
    if (log.logLevel == LogLevel.error) {
      final payload = log.payload;
      final normalizedPayload = payload.toLowerCase();
      // 过滤延迟测试/代理拨测/连接测试产生的噪声日志:
      // 包含 URL、dial tcp/udp 的都是代理测速或健康检查,
      // 属于正常业务行为,不需要弹窗打扰用户。
      final isTestNoise = normalizedPayload.contains('http://') ||
          normalizedPayload.contains('https://') ||
          normalizedPayload.contains('dial ') ||
          normalizedPayload.contains('connect error') ||
          normalizedPayload.contains('context canceled') ||
          normalizedPayload.contains('url test') ||
          normalizedPayload.contains('delay test') ||
          normalizedPayload.contains('health check') ||
          normalizedPayload.contains('proxied request') ||
          normalizedPayload.contains('connection refused') ||
          normalizedPayload.contains('i/o timeout') ||
          normalizedPayload.contains('connectex:') ||
          normalizedPayload.contains('no such host');
      if (!isTestNoise) {
        globalState.showNotifier(SensitiveMasker.maskText(payload));
      }
    }
    super.onLog(log);
  }

  @override
  void onRequest(Connection connection) async {
    ref.read(requestsProvider.notifier).addRequest(connection);
    super.onRequest(connection);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    ref.read(providersProvider.notifier).setProvider(
          await clashCore.getExternalProvider(
            providerName,
          ),
        );
    await globalState.appController.updateGroupsDebounce();
    super.onLoaded(providerName);
  }
}
