import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/interface.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/state.dart';

class ClashService extends ClashHandlerInterface {
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;

  Process? process;

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    _initServer();
    reStart();
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
      final server = await ServerSocket.bind(
        address,
        0,
        shared: true,
      );
      serverCompleter.complete(server);
      await for (final socket in server) {
        await _destroySocket();
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
  reStart() async {
    if (isStarting == true) return;
    isStarting = true;
    socketCompleter = Completer();
    try {
      if (process != null) {
        await shutdown();
      }
      final serverSocket = await serverCompleter.future;
      // macOS 和 Windows 用 TCP，传端口号；Linux 用 Unix Socket，传路径
      final arg = (Platform.isWindows || Platform.isMacOS)
          ? "${serverSocket.port}"
          : serverSocket.address.address;
      final isAdmin = Platform.isWindows && await system.checkIsAdmin();
      if (isAdmin) {
        final isSuccess = await request.startCoreByHelper(arg);
        if (isSuccess) {
          return;
        }
      }
      final coreFile = File(appPath.corePath);
      if (!await coreFile.exists()) {
        final err = "Core binary not found: ${appPath.corePath}";
        commonPrint.log(err);
        if (!socketCompleter.isCompleted) {
          socketCompleter.completeError(Exception(err));
        }
        return;
      }
      commonPrint.log("Starting core: ${appPath.corePath}, arg: $arg");
      // macOS: 移除 Gatekeeper quarantine 属性，防止下载的 DMG 安装后核心被阻止执行
      if (Platform.isMacOS) {
        try {
          await Process.run('xattr', ['-rd', 'com.apple.quarantine', appPath.corePath]);
        } catch (_) {}
      }
      process = await Process.start(
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
        process?.exitCode.then((code) {
          if (code != 0 && !socketCompleter.isCompleted) {
            final err = "Core process exited with code $code";
            commonPrint.log(err);
            socketCompleter.completeError(Exception(err));
          }
        });
      }
    } catch (e) {
      commonPrint.log(e.toString());
      if (!socketCompleter.isCompleted) {
        socketCompleter.completeError(e);
      }
    } finally {
      isStarting = false;
    }
  }

  @override
  destroy() async {
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  sendMessage(String message) async {
    try {
      final socket = await socketCompleter.future;
      socket.writeln(message);
    } catch (e) {
      commonPrint.log("sendMessage failed (core not connected): $e");
    }
  }

  _deleteSocketFile() async {
    // 只有 Linux 使用 Unix Socket，才需要清理 socket 文件
    if (!Platform.isWindows && !Platform.isMacOS) {
      final file = File(unixSocketPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      await lastSocket.close();
      socketCompleter = Completer();
    }
  }

  @override
  shutdown() async {
    if (Platform.isWindows) {
      await request.stopCoreByHelper();
    }
    await _destroySocket();
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
