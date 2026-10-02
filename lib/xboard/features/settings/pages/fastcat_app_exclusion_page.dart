import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Select Android applications that should bypass the VPN.
class FastCatAppExclusionPage extends ConsumerStatefulWidget {
  const FastCatAppExclusionPage({super.key});

  @override
  ConsumerState<FastCatAppExclusionPage> createState() =>
      _FastCatAppExclusionPageState();
}

class _FastCatAppExclusionPageState
    extends ConsumerState<FastCatAppExclusionPage> {
  final _searchController = TextEditingController();
  late Set<String> _excluded;
  late Set<String> _initialExcluded;
  bool _enabled = false;
  bool _initialEnabled = false;
  bool _showSystemApps = false;
  bool _initialShowSystemApps = false;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  final Map<String, Future<ImageProvider?>> _iconFutures = {};

  @override
  void initState() {
    super.initState();
    final accessControl = ref.read(vpnSettingProvider).accessControl;
    _enabled = accessControl.enable &&
        accessControl.mode == AccessControlMode.rejectSelected;
    _showSystemApps = !accessControl.isFilterSystemApp;
    _initialShowSystemApps = _showSystemApps;
    _excluded = Set.of(accessControl.rejectList);
    _initialExcluded = Set.of(_excluded);
    _initialEnabled = _enabled;
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    await globalState.appController.getPackages();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshPackages() async {
    _iconFutures.clear();
    await globalState.appController.getPackages(refresh: true);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _enabled != _initialEnabled ||
      _showSystemApps != _initialShowSystemApps ||
      !_excluded.containsAll(_initialExcluded) ||
      !_initialExcluded.containsAll(_excluded);

  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges) return true;
    final save = await _showUnsavedChangesDialog(context);
    if (save == true) return _save(close: false);
    return save == false;
  }

  Future<void> _handlePopAttempt() async {
    if (!await _confirmLeave() || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<bool?> _showUnsavedChangesDialog(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(dialogContext),
        title: Text(
          isChinese ? '未保存的修改' : 'Unsaved changes',
          style: XbUiText.sectionTitle(dialogContext),
        ),
        content:
            Text(isChinese ? '是否保存后返回？' : 'Save your changes before leaving?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: XbUiButton.outlinedNeutral(dialogContext),
            child: Text(isChinese ? '继续编辑' : 'Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isChinese ? '不保存' : 'Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: XbUiButton.filledPrimary(dialogContext),
            child: Text(isChinese ? '保存' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _save({bool close = true}) async {
    if (_saving) return false;
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final packages = ref.read(packagesProvider);
    final validPackageNames = packages.map((item) => item.packageName).toSet();
    final rejectList = _excluded
        .where(validPackageNames.contains)
        .where((name) => name != globalState.packageInfo.packageName)
        .toList()
      ..sort();
    final previous = ref.read(vpnSettingProvider);
    final next = previous.copyWith(
      accessControl: previous.accessControl.copyWith(
        enable: _enabled && rejectList.isNotEmpty,
        mode: AccessControlMode.rejectSelected,
        rejectList: rejectList,
        isFilterSystemApp: !_showSystemApps,
      ),
    );
    final wasConnected = ref.read(runTimeProvider) != null;
    if (wasConnected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: XbUiDialog.shape(),
          backgroundColor: XbUiDialog.background(dialogContext),
          title: Text(
            isChinese ? '重新连接以应用规则？' : 'Reconnect to apply rules?',
            style: XbUiText.sectionTitle(dialogContext),
          ),
          content: Text(isChinese
              ? 'Android 需要短暂重建 VPN 隧道，当前连接会自动断开并重新连接。'
              : 'Android must briefly rebuild the VPN tunnel. The current connection will reconnect automatically.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isChinese ? '取消' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: XbUiButton.filledPrimary(dialogContext),
              child: Text(isChinese ? '应用并重连' : 'Apply and reconnect'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;
    }

    if (mounted) setState(() => _saving = true);
    ref.read(vpnSettingProvider.notifier).updateState((_) => next);
    try {
      if (wasConnected) {
        final stopped = await globalState.appController.updateStatus(false);
        if (!stopped) throw StateError('VPN stop failed');
      }
      await globalState.appController.updateClashConfig();
      if (wasConnected) {
        final started = await globalState.appController.updateStatus(true);
        if (!started) throw StateError('VPN restart failed');
      }
      _initialExcluded = Set.of(_excluded);
      _initialEnabled = _enabled;
      _initialShowSystemApps = _showSystemApps;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isChinese ? '应用排除规则已生效' : 'App exclusion rules are now active'),
          ),
        );
      }
      if (mounted && close) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return true;
    } catch (_) {
      ref.read(vpnSettingProvider.notifier).updateState((_) => previous);
      try {
        await globalState.appController.updateClashConfig();
        if (wasConnected && ref.read(runTimeProvider) == null) {
          await globalState.appController.updateStatus(true);
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChinese
                ? '规则应用失败，已恢复之前的设置'
                : 'Could not apply rules. Previous settings were restored.'),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    final accessControl = ref.watch(vpnSettingProvider).accessControl;
    final packages = ref
        .watch(packagesProvider)
        .where((item) =>
            item.packageName != globalState.packageInfo.packageName &&
            (_showSystemApps || !item.system) &&
            (!accessControl.isFilterNonInternetApp || item.internet))
        .toList();
    final keyword = _searchController.text.trim().toLowerCase();
    final visible = keyword.isEmpty
        ? packages
        : packages
            .where((item) =>
                item.label.toLowerCase().contains(keyword) ||
                item.packageName.toLowerCase().contains(keyword))
            .toList();

    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePopAttempt();
      },
      child: Scaffold(
        backgroundColor: XbUiTokens.pageBackground(context),
        appBar: AppBar(
          title: Text(isChinese ? '应用排除' : 'App exclusion'),
          backgroundColor: XbUiTokens.pageBackground(context),
          surfaceTintColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: _loading || _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isChinese ? '保存' : 'Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _ExclusionCard(
                          child: SwitchListTile(
                            title: Text(
                                isChinese ? '启用应用排除' : 'Enable app exclusion'),
                            subtitle: Text(isChinese
                                ? '选中的应用将绕过 VPN，直接连接网络'
                                : 'Selected apps bypass the VPN and connect directly'),
                            value: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _ExclusionCard(
                          child: SwitchListTile(
                            title:
                                Text(isChinese ? '显示系统应用' : 'Show system apps'),
                            subtitle: Text(isChinese
                                ? '系统组件通常不建议排除'
                                : 'System components are usually best left unchanged'),
                            value: _showSystemApps,
                            onChanged: (value) =>
                                setState(() => _showSystemApps = value),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: isChinese ? '搜索应用' : 'Search apps',
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshPackages,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              final selected =
                                  _excluded.contains(item.packageName);
                              return _ExclusionCard(
                                child: CheckboxListTile(
                                  secondary: _PackageIcon(
                                    image: _iconFutures.putIfAbsent(
                                      item.packageName,
                                      () =>
                                          app?.getPackageIcon(
                                              item.packageName) ??
                                          Future.value(null),
                                    ),
                                    enabled: _enabled,
                                  ),
                                  title: Text(item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(item.packageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  value: selected,
                                  onChanged: (value) => setState(() {
                                    if (value == true) {
                                      _excluded.add(item.packageName);
                                    } else {
                                      _excluded.remove(item.packageName);
                                    }
                                  }),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PackageIcon extends StatelessWidget {
  const _PackageIcon({required this.image, required this.enabled});

  final Future<ImageProvider?> image;
  final bool enabled;

  static const _grayScale = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider?>(
        future: image,
        builder: (context, snapshot) {
          final avatar = SizedBox(
            width: 42,
            height: 42,
            child: snapshot.data == null
                ? const Icon(Icons.android, size: 30)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image(image: snapshot.data!, fit: BoxFit.contain),
                  ),
          );
          if (enabled) {
            return avatar;
          }
          return ColorFiltered(colorFilter: _grayScale, child: avatar);
        },
      );
}

class _ExclusionCard extends StatelessWidget {
  const _ExclusionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}
