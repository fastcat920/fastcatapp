import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/common/diagnostic_log_buffer.dart';
import 'package:fl_clash/state.dart';
import 'dart:io';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatLogsPage extends ConsumerStatefulWidget {
  const FastCatLogsPage({super.key});

  @override
  ConsumerState<FastCatLogsPage> createState() => _FastCatLogsPageState();
}

class _FastCatLogsPageState extends ConsumerState<FastCatLogsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buffer = DiagnosticLogBuffer.fromList(ref.watch(logsProvider));
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final logs = buffer
        .displayLogs(chinese: chinese)
        .reversed
        .where((log) => _matches(context, log))
        .toList();
    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(l10n.logs),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _hideLogsLabel(context),
            onPressed: _hideLogs,
            icon: const Icon(Icons.visibility_off_outlined),
          ),
          IconButton(
            tooltip: l10n.copyLogs,
            onPressed: () => _copy(context),
            icon: const Icon(Icons.content_copy_outlined),
          ),
          IconButton(
            tooltip: l10n.clearLogs,
            onPressed: () => ref.read(logsProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: SearchBar(
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    XbUiCardStyle.background(context),
                  ),
                  side: WidgetStatePropertyAll(
                    BorderSide(color: XbUiTokens.cardBorder(context)),
                  ),
                  leading: const Icon(Icons.search),
                  hintText: l10n.search,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  chinese
                      ? '已保留 ${buffer.length} 条 · 已淘汰 ${buffer.evictedRecords} 条 · 重复合并 ${buffer.mergedOccurrences} 次'
                      : '${buffer.length} retained · ${buffer.evictedRecords} evicted · ${buffer.mergedOccurrences} repeats merged',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? Center(child: Text(l10n.logsDesc))
                    : Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        elevation: XbUiCardStyle.elevation(context),
                        shadowColor: XbUiCardStyle.shadowColor(context),
                        color: XbUiCardStyle.background(context),
                        shape: XbUiCardStyle.shape(context),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: XbUiTokens.cardBorder(context),
                          ),
                          itemBuilder: (context, index) => _LogTile(
                            log: logs[index],
                            payload: _localizedPayload(
                              context,
                              logs[index].payload,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hideLogsLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh'
          ? '隐藏日志'
          : 'Hide logs';

  void _hideLogs() {
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(logCapture: false, openLogs: false),
        );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  bool _matches(BuildContext context, Log log) {
    final query = _query.trim().toLowerCase();
    final localizedPayload = _localizedPayload(context, log.payload);
    return query.isEmpty ||
        log.payload.toLowerCase().contains(query) ||
        localizedPayload.toLowerCase().contains(query);
  }

  String _localizedPayload(BuildContext context, String payload) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return _LogPayloadLocalizer.localize(payload, chinese: zh);
  }

  Future<void> _copy(BuildContext context) async {
    final buffer = DiagnosticLogBuffer.fromList(ref.read(logsProvider));
    final text = buffer.export(
      chinese: Localizations.localeOf(context).languageCode == 'zh',
      clientVersion: globalState.isInit
          ? '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}'
          : null,
      systemVersion:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      localize: (payload) => _localizedPayload(context, payload),
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copySuccess)),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.log,
    required this.payload,
  });

  final Log log;
  final String payload;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(
        SensitiveMasker.maskText(payload),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      subtitle: Text(log.dateTime),
    );
  }
}

class _LogPayloadLocalizer {
  static const _pairs = <(String, String)>[
    ('开始初始化', 'Starting initialization'),
    ('初始化完成', 'Initialization completed'),
    ('初始化成功', 'Initialization succeeded'),
    ('初始化失败', 'Initialization failed'),
    ('开始登录', 'Starting sign-in'),
    ('登录成功', 'Sign-in succeeded'),
    ('登录失败', 'Sign-in failed'),
    ('登录出错', 'Sign-in error'),
    ('开始注册', 'Starting registration'),
    ('注册成功', 'Registration succeeded'),
    ('注册失败', 'Registration failed'),
    ('开始获取用户信息', 'Fetching user information'),
    ('获取用户信息失败', 'Failed to fetch user information'),
    ('开始获取订阅信息', 'Fetching subscription information'),
    ('获取订阅信息失败', 'Failed to fetch subscription information'),
    ('订阅配置导入成功', 'Subscription configuration imported'),
    ('订阅配置导入失败', 'Failed to import subscription configuration'),
    ('开始下载配置', 'Downloading configuration'),
    ('下载配置失败', 'Failed to download configuration'),
    ('加密订阅获取成功', 'Encrypted subscription fetched'),
    ('加密配置下载失败', 'Failed to download encrypted configuration'),
    ('请求失败', 'Request failed'),
    ('请求成功', 'Request succeeded'),
    ('请求取消', 'Request cancelled'),
    ('响应', 'Response'),
    ('成功', 'Succeeded'),
    ('失败', 'Failed'),
    ('超时', 'Timed out'),
    ('已取消', 'Cancelled'),
    ('读取缓存', 'Reading cache'),
    ('缓存加载完成', 'Cache loaded'),
    ('清除缓存', 'Clearing cache'),
    ('开始检查域名状态', 'Checking domain status'),
    ('域名检查成功', 'Domain check succeeded'),
    ('未找到可用域名', 'No available domain found'),
    ('刷新域名缓存', 'Refreshing domain cache'),
    ('开始测试', 'Starting test'),
    ('测试完成', 'Test completed'),
    ('测试失败', 'Test failed'),
    ('重新连接', 'Reconnecting'),
    ('断开连接', 'Disconnecting'),
    ('网络异常', 'Network error'),
    ('配置加载完成', 'Configuration loaded'),
    ('配置加载失败', 'Failed to load configuration'),
    ('加载配置文件失败', 'Failed to load configuration file'),
    ('保存配置', 'Saving configuration'),
    ('状态更新取消', 'State update cancelled'),
    ('错误堆栈', 'Error stack'),
    ('应用完成', 'Apply completed'),
    ('重试', 'Retrying'),
    ('警告', 'Warning'),
    ('错误', 'Error'),
  ];

  static String localize(String payload, {required bool chinese}) {
    var result = payload;
    for (final pair in _pairs) {
      final source = chinese ? pair.$2 : pair.$1;
      final target = chinese ? pair.$1 : pair.$2;
      result = result.replaceAll(source, target);
    }
    return result;
  }
}
