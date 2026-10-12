import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/services/core_switch_status.dart';
import 'package:fl_clash/state.dart';

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;
  Future<void>? _restartFuture;
  bool _restartRequiresHelper = false;
  bool _acceptConnections = false;
  Socket? _connectedSocket;
  final Duration connectionTimeout;
  final Future<ServerSocket> Function()? _bindServer;
  final Future<void> Function(String)? _launchCore;
  final Future<void> Function()? _stopCore;

  Process? process;

  bool get isConnected => _acceptConnections && _connectedSocket != null;

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal()
      : connectionTimeout = const Duration(seconds: 10),
        _bindServer = null,
        _launchCore = null,
        _stopCore = null {
    _initServer();
    unawaited(reStart().catchError((Object error) {
      commonPrint.log('[CoreRestart] initial start failed: $error');
    }));
  }

  @visibleForTesting
  ClashService.forTesting({
    required Future<ServerSocket> Function() bindServer,
    required Future<void> Function(String) launchCore,
    required Future<void> Function() stopCore,
    this.connectionTimeout = const Duration(seconds: 10),
  })  : _bindServer = bindServer,
        _launchCore = launchCore,
        _stopCore = stopCore {
    _initServer();
  }

  _initServer() async {
    runZonedGuarded(() async {
      // macOS sandbox 禁止在 /tmp 创建 Unix Socket（errno=1），
      // 因此 macOS 和 Windows 统一使用 TCP localhost
      final useUnixSocket = !Platform.isWindows && !Platform.isMacOS;
      final address = useUnixSocket
          ? InternetAddress(
              unixSocketPath,
              type: InternetAddressType.unix,
            )
          : InternetAddress(
              localhost,
              type: InternetAddressType.IPv4,
            );
      await _deleteSocketFile();
      final server = await (_bindServer?.call() ??
          ServerSocket.bind(address, 0, shared: true));
      serverCompleter.complete(server);
      await for (final socket in server) {
        // A late connection from a failed/stopped core must not revive it.
        if (!_acceptConnections || socketCompleter.isCompleted) {
          socket.destroy();
          continue;
        }
        _connectedSocket = socket;
        socketCompleter.complete(socket);
        socket
            .transform(uint8ListToListIntConverter)
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen(
          (data) {
            try {
              handleResult(
                ActionResult.fromJson(
                  json.decode(data.trim()),
                ),
              );
            } catch (e) {
              commonPrint.log("decode error: $e");
            }
          },
          onError: (Object error) {
            commonPrint.log('[CoreRestart] channel error: $error');
            if (identical(_connectedSocket, socket)) _destroySocket();
          },
          onDone: () {
            if (identical(_connectedSocket, socket)) _destroySocket();
          },
        );
      }
    }, (error, stack) {
      commonPrint.log("_initServer error: $error");
      // 关键：如果 ServerSocket.bind 失败，必须 complete serverCompleter，
      // 否则 preload() 会永久挂起，导致 runApp() 永远不执行（macOS 黑屏）
      if (!serverCompleter.isCompleted) {
        serverCompleter.completeError(error);
      }
      if (error is SocketException) {
        globalState.showNotifier(error.toString());
      }
    });
  }

  @override
  Future<void> reStart({bool requireHelper = false}) {
    // All callers wait for the same restart, not just the launch request.
    if (_restartFuture != null && requireHelper && !_restartRequiresHelper) {
      return Future.error(
          StateError('An unprivileged core restart is in progress'));
    }
    if (_restartFuture == null) _restartRequiresHelper = requireHelper;
    return _restartFuture ??=
        _restart(requireHelper: requireHelper).whenComplete(() {
      _restartFuture = null;
    });
  }

  Future<void> _restart({required bool requireHelper}) async {
    isStarting = true;
    try {
      // A Helper-owned core has no Dart Process handle. It still must stop
      // before replacing its channel, otherwise /start may reuse the old core.
      await shutdown();
      socketCompleter = Completer();
      // Observe errors immediately, even if launch fails before waitForSocket.
      unawaited(
          socketCompleter.future.then<void>((_) {}, onError: (Object _) {}));
      final serverSocket =
          await serverCompleter.future.timeout(connectionTimeout);
      // macOS 和 Windows 用 TCP，传端口号；Linux 用 Unix Socket，传路径
      final arg =
          (_bindServer != null || Platform.isWindows || Platform.isMacOS)
              ? "${serverSocket.port}"
              : serverSocket.address.address;
      _acceptConnections = true;
      globalState.updateCoreSwitchStatus(CoreSwitchStage.coreConnecting);
      commonPrint.log('[CoreRestart] waiting for core channel');
      if (_launchCore != null) {
        await _launchCore!(arg);
      } else {
        await _startCore(arg, requireHelper: requireHelper);
      }
      await socketCompleter.future.timeout(connectionTimeout);
      if (!isConnected) throw StateError('Core channel closed during startup');
      commonPrint.log('[CoreRestart] core channel connected');
    } catch (e) {
      commonPrint.log('[CoreRestart] failed: $e');
      // Stop this attempt before releasing the repair lock. A Future.timeout
      // on the entire repair would leave a late restart running in background.
      await shutdown();
      rethrow;
    } finally {
      isStarting = false;
    }
  }

  Future<void> _startCore(String arg, {required bool requireHelper}) async {
    final isAdmin = Platform.isWindows && await system.checkIsAdmin();
    if (isAdmin || requireHelper) {
      globalState.updateCoreSwitchStatus(
        CoreSwitchStage.coreConnecting,
      );
      final isSuccess = await request.startCoreByHelper(arg);
      if (isSuccess) {
        return;
      }
      if (requireHelper) {
        // An ordinary process is not an authorized TUN replacement.
        throw StateError('Helper failed to start the authorized core');
      }
    }
    final coreFile = File(appPath.corePath);
    if (!await coreFile.exists()) {
      final err = "Core binary not found: ${appPath.corePath}";
      commonPrint.log(err);
      throw StateError(err);
    }
    commonPrint.log("Starting core: ${appPath.corePath}, arg: $arg");
    globalState.updateCoreSwitchStatus(
      CoreSwitchStage.coreConnecting,
    );
    // macOS: 移除 Gatekeeper quarantine 属性，防止下载的 DMG 安装后核心被阻止执行
    if (Platform.isMacOS) {
      try {
        await Process.run(
            'xattr', ['-rd', 'com.apple.quarantine', appPath.corePath]);
      } catch (_) {}
    }
    final startedProcess = await Process.start(
      appPath.corePath,
      [
        arg,
      ],
      // detachedWithStdio: 在 Windows 上以 DETACHED_PROCESS 标志启动，
      // 防止 fastcatCore.exe（控制台程序）弹出黑色 CMD 窗口
      mode: Platform.isWindows
          ? ProcessStartMode.detachedWithStdio
          : ProcessStartMode.normal,
    );
    process = startedProcess;
    process?.stdout.listen((_) {});
    process?.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((error) {
      if (error.isNotEmpty) {
        commonPrint.log(error);
      }
    });
    // 监听进程退出：如果核心进程异常退出且 socket 尚未连接，通知等待方
    // 注意：Windows 以 detachedWithStdio 启动，Dart 不支持对 detached 进程
    // 访问 exitCode（会抛 StateError: Process is detached），必须跳过
    if (!Platform.isWindows) {
      startedProcess.exitCode.then((code) {
        if (!identical(process, startedProcess)) {
          return;
        }
        if (!socketCompleter.isCompleted) {
          final err = "Core process exited with code $code";
          commonPrint.log(err);
          socketCompleter.completeError(Exception(err));
        }
      });
    }
  }

  @override
  destroy() async {
    await shutdown();
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  sendMessage(String message) async {
    try {
      // Startup may still be stopping the previous Helper-owned process.
      // Do not attach initialization messages to its retired completer.
      final restarting = _restartFuture;
      if (restarting != null) await restarting;
      final socket = await socketCompleter.future.timeout(connectionTimeout);
      if (!identical(socket, _connectedSocket) || !_acceptConnections) {
        throw StateError('Core channel replaced before sending');
      }
      socket.writeln(message);
    } catch (e) {
      commonPrint.log("sendMessage failed (core not connected): $e");
    }
  }

  _deleteSocketFile() async {
    // 只有 Linux 使用 Unix Socket，才需要清理 socket 文件
    if (_bindServer == null && !Platform.isWindows && !Platform.isMacOS) {
      final file = File(unixSocketPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  void _destroySocket() {
    _acceptConnections = false;
    _connectedSocket?.destroy();
    _connectedSocket = null;
    if (!socketCompleter.isCompleted) {
      unawaited(
          socketCompleter.future.then<void>((_) {}, onError: (Object _) {}));
      socketCompleter.completeError(StateError('Core channel closed'));
    }
  }

  @override
  shutdown() async {
    _destroySocket();
    if (_stopCore != null) {
      await _stopCore!();
    } else if (Platform.isWindows) {
      await request.stopCoreByHelper();
    }
    process?.kill();
    process = null;
    return true;
  }

  @override
  Future<bool> preload() async {
    try {
      await serverCompleter.future.timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      commonPrint.log("preload failed: $e");
      return false;
    }
  }
}

final clashService = system.isDesktop ? ClashService() : null;
