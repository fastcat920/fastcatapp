import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/update_check/providers/update_check_provider.dart';
import 'package:fl_clash/xboard/features/update_check/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class Contributor {
  final String avatar;
  final String name;
  final String link;

  const Contributor({
    required this.avatar,
    required this.name,
    required this.link,
  });
}

class AboutView extends ConsumerWidget {
  const AboutView({super.key});

  _checkUpdate(BuildContext context, WidgetRef ref) async {
    final commonScaffoldState = context.commonScaffoldState;

    Future<void> runCheck() async {
      final updateNotifier = ref.read(updateCheckProvider.notifier);
      await updateNotifier.checkForUpdates();
    }

    try {
      if (commonScaffoldState?.mounted == true) {
        await commonScaffoldState!
            .loadingRun<void>(runCheck, title: appLocalizations.checkUpdate);
      } else {
        await runCheck();
      }

      // 检查更新结果
      final updateState = ref.read(updateCheckProvider);
      if (updateState.hasUpdate) {
        // 有更新，显示更新弹窗
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => UpdateDialog(state: updateState),
          );
        }
      } else if (updateState.error != null) {
        // 检查失败，显示错误对话框（避免 SnackBar 跨页面残留）
        if (context.mounted) {
          String errorMessage = '检查更新失败';
          if (updateState.error!.contains('530')) {
            errorMessage = '更新服务暂时不可用，请稍后重试';
          } else if (updateState.error!.contains('SSL') ||
              updateState.error!.contains('HandshakeException') ||
              updateState.error!.contains('TLSV1_ALERT_INTERNAL_ERROR')) {
            errorMessage = 'SSL连接失败，请检查网络或稍后重试';
          } else if (updateState.error!.contains('timeout')) {
            errorMessage = '网络连接超时，请检查网络连接';
          } else if (updateState.error!.contains('connection')) {
            errorMessage = '无法连接到更新服务器';
          }
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('检查更新失败'),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _checkUpdate(context, ref);
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
      } else {
        // 已是最新版本
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已是最新版本'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('检查更新失败'),
            content: Text(e.toString()),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final version = globalState.packageInfo.version;

    return Consumer(builder: (_, ref, ___) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── 蓝色版本卡片（连点5次进入开发者模式）─────────────────
          _DeveloperModeDetector(
            onEnterDeveloperMode: () {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(developerMode: true),
                  );
              context.showNotifier(appLocalizations.developerModeEnableTip);
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  // 徽章：✓ Vx.x.x
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'V$version',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appLocalizations.desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ), // _DeveloperModeDetector
          const SizedBox(height: 20),
          // ── 检查更新 ──────────────────────────────────────────
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.system_update_outlined,
                    color: theme.colorScheme.primary, size: 20),
              ),
              title: Text(appLocalizations.checkUpdate),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _checkUpdate(context, ref),
            ),
          ),
        ],
      );
    });
  }
}

class Avatar extends StatelessWidget {
  final Contributor contributor;

  const Avatar({
    super.key,
    required this.contributor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircleAvatar(
              foregroundImage: AssetImage(
                contributor.avatar,
              ),
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            contributor.name,
            style: context.textTheme.bodySmall,
          )
        ],
      ),
      onTap: () {
        globalState.openUrl(contributor.link);
      },
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
