import 'dart:io';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/tv_focusable.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/update_check_state.dart';
import '../providers/update_check_provider.dart';
import '../services/update_download_service.dart';
import '../services/update_install_service.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.state});
  final UpdateCheckState state;
  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  late UpdateCheckState _offer = widget.state;
  bool _installing = false;
  String? _message;
  String? _instruction;
  String text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
  bool get _store => Platform.isIOS;
  String bytes(int value) => '${(value / 1048576).toStringAsFixed(1)} MB';
  String errorText(String? code) => switch (code) {
        'integrity' =>
          text('安装包校验失败，请重试。', 'Installer verification failed. Please retry.'),
        'metadata' || 'unsafe_url' || 'not_installer' => text(
            '更新配置缺少有效的直链或校验信息，请联系支持。',
            'A valid installer link and verification details are required. Contact support.'),
        'storage' => text('无法保存安装包，请检查剩余空间。',
            'Could not save the installer. Check free storage.'),
        'timeout' => text('下载超时，请重试。', 'Download timed out. Please retry.'),
        _ => text('下载失败，请检查网络后重试，已下载进度将保留。',
            'Download failed. Check your connection and retry; downloaded progress is retained.'),
      };
  Future<void> _update() async {
    if (_installing) {
      return;
    }
    setState(() => _message = null);
    if (_store) {
      setState(() => _installing = true);
      try {
        if (!await UpdateInstallService.openStore(_offer.updateUrl ?? '')) {
          throw const FormatException('store');
        }
        if (mounted) {
          setState(() => _message = text('请在 App Store 完成更新，安装后重新打开客户端。',
              'Update in the App Store, then open the app again.'));
        }
      } catch (_) {
        if (mounted) {
          setState(() => _message = text('无法打开 App Store，请检查商店地址和网络后重试。',
              'Could not open the App Store. Check the store link and connection.'));
        }
      } finally {
        if (mounted) {
          setState(() => _installing = false);
        }
      }
      return;
    }
    if (!_offer.trusted || _offer.artifact == null) {
      setState(() => _installing = true);
      await ref
          .read(updateCheckProvider.notifier)
          .checkForUpdates(refreshRemoteConfig: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _offer = ref.read(updateCheckProvider);
        _installing = false;
      });
    }
    final artifact = _offer.artifact;
    if (!_offer.hasUpdate ||
        !_offer.trusted ||
        artifact == null ||
        !artifact.isValid) {
      setState(() => _message = errorText('metadata'));
      return;
    }
    final download = ref.read(updateDownloadProvider);
    File? file = download.identity == '${artifact.sha256}.${artifact.type}' &&
            download.phase == UpdatePhase.ready
        ? download.file
        : null;
    file ??= await ref.read(updateDownloadProvider.notifier).start(artifact);
    if (!mounted || file == null) {
      return;
    }
    setState(() => _installing = true);
    try {
      final result = await UpdateInstallService().install(file, artifact,
          version: _offer.latestVersion ?? '', build: _offer.build);
      if (!mounted) {
        return;
      }
      setState(() {
        _instruction = result.status;
        _message = switch (result.status) {
          'permission_required' => text('请允许安装此来源的应用，返回后点击“继续安装”。',
              'Allow installs from this source, then return and choose Continue installation.'),
          'macos_manual' => text('安装镜像已打开。将客户端拖到“应用程序”并替换旧版，完成后重新打开。',
              'The disk image is open. Drag the app to Applications, replace the previous version, then reopen it.'),
          'appimage_manual' => text(
              '安装包所在文件夹已打开。请将文件复制到应用目录，赋予可执行权限并替换旧版，再打开新版本。',
              'The installer folder is open. Copy the file to your application folder, make it executable, replace the previous version and open it.'),
          'linux_manual' => text('请在系统安装工具中完成安装，再重新打开客户端。',
              'Finish installation in the system package installer, then reopen the app.'),
          _ => text('请在系统界面确认安装。安装完成后选择“打开”或从桌面打开客户端。',
              'Confirm installation in the system dialog. When finished, choose Open or launch the app.'),
        };
      });
      if (result.exitRequired) {
        await globalState.appController.handleExit();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = text('无法完成安装。请检查安装权限、安装包签名及系统兼容性后重试。',
            'Installation could not complete. Check installation permissions, package signature and system compatibility, then retry.'));
      }
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(updateDownloadProvider);
    final artifact = _offer.artifact;
    final size = artifact?.size;
    final matching = artifact != null &&
        task.identity == '${artifact.sha256}.${artifact.type}';
    final busy = _installing || (matching && task.busy);
    final ready = matching && task.phase == UpdatePhase.ready;
    return PopScope(
        canPop: !_offer.forceUpdate,
        child: AlertDialog(
          shape: XbUiDialog.shape(),
          backgroundColor: XbUiDialog.background(context),
          title: Text(_offer.forceUpdate
              ? text('必须更新至 ${_offer.latestVersion ?? ''}',
                  'Update required · ${_offer.latestVersion ?? ''}')
              : text('发现新版本 ${_offer.latestVersion ?? ''}',
                  'New version · ${_offer.latestVersion ?? ''}')),
          content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(text('当前版本：${_offer.currentVersion ?? ''}',
                        'Current version: ${_offer.currentVersion ?? ''}')),
                    if (_offer.releaseNotes?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(_offer.releaseNotes!)
                    ],
                    if (!_store && size != null) ...[
                      const SizedBox(height: 8),
                      Text(text(
                          '安装包：${bytes(size)}', 'Installer: ${bytes(size)}'))
                    ],
                    if (matching && task.phase == UpdatePhase.downloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                          value: task.total != null && task.total! > 0
                              ? (task.received / task.total!).clamp(0, 1)
                              : null),
                      const SizedBox(height: 8),
                      Text(
                          '${bytes(task.received)}${task.total != null ? ' / ${bytes(task.total!)} · ${(task.received / task.total! * 100).clamp(0, 100).toStringAsFixed(0)}%' : ''}'),
                    ],
                    if (matching && task.phase == UpdatePhase.verifying) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      Text(text('正在验证安装包…', 'Verifying installer…'))
                    ],
                    if (matching && task.phase == UpdatePhase.failed) ...[
                      const SizedBox(height: 12),
                      Text(errorText(task.error))
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!)
                    ],
                  ]))),
          actions: [
            if (!_offer.forceUpdate)
              OutlinedButton(
                      onPressed: () {
                        if (matching && task.busy) {
                          ref.read(updateDownloadProvider.notifier).cancel();
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text(text('取消', 'Cancel')))
                  .withTvFocus(autofocus: true),
            TVFocusable(
                focusableWhenDisabled: true,
                autofocus: _offer.forceUpdate,
                onPressed: busy ? null : _update,
                child: FilledButton.icon(
                    onPressed: busy ? null : _update,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_store ? Icons.open_in_new : Icons.download),
                    label: Text(busy
                        ? text('正在处理…', 'Working…')
                        : _store
                            ? text('更新', 'Update')
                            : _instruction == 'permission_required'
                                ? text('继续安装', 'Continue installation')
                                : ready
                                    ? text('安装更新', 'Install update')
                                    : text('更新', 'Update')))),
          ],
        ));
  }
}
