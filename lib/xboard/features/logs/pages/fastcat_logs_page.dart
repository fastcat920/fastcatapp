import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FastCatLogsPage extends ConsumerStatefulWidget {
  const FastCatLogsPage({super.key});

  @override
  ConsumerState<FastCatLogsPage> createState() => _FastCatLogsPageState();
}

class _FastCatLogsPageState extends ConsumerState<FastCatLogsPage> {
  static const _levelFilterKey = 'fastcat_log_level_filter';

  String _query = '';
  late Set<LogLevel> _selectedLevels;

  @override
  void initState() {
    super.initState();
    final configuredLevel = ref.read(patchClashConfigProvider).logLevel;
    _selectedLevels = {configuredLevel, LogLevel.app};
    _restoreLevelFilter();
  }

  Future<void> _restoreLevelFilter() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_levelFilterKey);
    if (stored == null || stored.isEmpty || !mounted) return;
    final restored =
        LogLevel.values.where((level) => stored.contains(level.name)).toSet();
    if (restored.isEmpty) return;
    setState(() => _selectedLevels = restored);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logs = ref.watch(logsProvider).list.reversed.where(_matches).toList();
    return Scaffold(
      backgroundColor: XbUiTokens.pageBackground(context),
      appBar: AppBar(
        title: Text(l10n.logs),
        backgroundColor: XbUiTokens.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: l10n.logLevel,
            onPressed: () => _showLevelFilter(context),
            icon: Badge(
              isLabelVisible: _selectedLevels.length != LogLevel.values.length,
              smallSize: 7,
              child: const Icon(Icons.filter_alt_outlined),
            ),
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
                          itemBuilder: (context, index) =>
                              _LogTile(log: logs[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matches(Log log) {
    final query = _query.trim().toLowerCase();
    return _selectedLevels.contains(log.logLevel) &&
        (query.isEmpty ||
            log.payload.toLowerCase().contains(query) ||
            log.logLevel.name.toLowerCase().contains(query));
  }

  Future<void> _showLevelFilter(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final draft = Set<LogLevel>.of(_selectedLevels);
    final result = await showDialog<Set<LogLevel>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allSelected = draft.length == LogLevel.values.length;
          return AlertDialog(
            shape: XbUiDialog.shape(),
            backgroundColor: XbUiDialog.background(context),
            title: Text(l10n.logLevel, style: XbUiText.sectionTitle(context)),
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: allSelected,
                    title: Text(_allLevelsLabel(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onChanged: (_) => setDialogState(() {
                      if (allSelected) {
                        draft.clear();
                      } else {
                        draft.addAll(LogLevel.values);
                      }
                    }),
                  ),
                  const Divider(height: 1),
                  for (final level in LogLevel.values)
                    CheckboxListTile(
                      value: draft.contains(level),
                      title: Text(_levelLabel(context, level)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onChanged: (selected) => setDialogState(() {
                        if (selected == true) {
                          draft.add(level);
                        } else {
                          draft.remove(level);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: draft.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, draft),
                child: Text(_confirmLabel(context)),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedLevels = result);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _levelFilterKey,
      result.map((level) => level.name).toList(),
    );
  }

  String _allLevelsLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh'
          ? '全部等级'
          : 'All levels';

  String _confirmLabel(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh' ? '确定' : 'Apply';

  String _levelLabel(BuildContext context, LogLevel level) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return switch (level) {
      LogLevel.debug => zh ? '调试' : 'Debug',
      LogLevel.info => zh ? '信息' : 'Info',
      LogLevel.warning => zh ? '警告' : 'Warning',
      LogLevel.error => zh ? '错误' : 'Error',
      LogLevel.silent => zh ? '静默' : 'Silent',
      LogLevel.app => zh ? '应用' : 'App',
    };
  }

  Future<void> _copy(BuildContext context) async {
    final text = ref.read(logsProvider).list.map((log) {
      return '${log.dateTime} [${log.logLevel.name}] '
          '${SensitiveMasker.maskText(log.payload)}';
    }).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copySuccess)),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final Log log;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(
        SensitiveMasker.maskText(log.payload),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      subtitle: Text('${log.dateTime} · ${log.logLevel.name}'),
    );
  }
}
