import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:path/path.dart';

class Windows {
  static Windows? _instance;
  late DynamicLibrary _shell32;

  Windows._internal() {
    _shell32 = DynamicLibrary.open('shell32.dll');
  }

  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  bool runas(String command, String arguments, {bool show = false}) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    final shellExecute = _shell32.lookupFunction<
        Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd),
        int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd)>('ShellExecuteW');

    // show=true: SW_SHOWNORMAL=1（GUI工具如EnableLoopback.exe）
    // show=false: SW_HIDE=0（cmd.exe 等后台命令不需要窗口）
    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      show ? 1 : 0,
    );

    calloc.free(commandPtr);
    calloc.free(argumentsPtr);
    calloc.free(operationPtr);

    commonPrint.log("windows runas: $command $arguments resultCode:$result");

    if (result < 42) {
      return false;
    }
    return true;
  }

  /// 用 "open" verb 启动带 UAC manifest 的 GUI 程序。
  /// 适用于 exe 已声明 highestAvailable / requireAdministrator 的情况：
  /// 由 exe 自身 manifest 触发提权，避免 "runas" 与 manifest 冲突。
  bool launch(String command) {
    final commandPtr = command.toNativeUtf16();
    final operationPtr = 'open'.toNativeUtf16();

    final shellExecute = _shell32.lookupFunction<
        Int32 Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            Int32 nShowCmd),
        int Function(
            Pointer<Utf16> hwnd,
            Pointer<Utf16> lpOperation,
            Pointer<Utf16> lpFile,
            Pointer<Utf16> lpParameters,
            Pointer<Utf16> lpDirectory,
            int nShowCmd)>('ShellExecuteW');

    final result = shellExecute(
      nullptr,
      operationPtr,
      commandPtr,
      nullptr,
      nullptr,
      1, // SW_SHOWNORMAL
    );

    calloc.free(commandPtr);
    calloc.free(operationPtr);

    commonPrint.log("windows launch: $command resultCode:$result");
    return result > 32;
  }

  /// 以隐藏窗口模式运行进程并捕获输出，避免黑框闪烁
  Future<ProcessResult> _runHidden(
      String executable, List<String> arguments) async {
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detachedWithStdio,
    );
    final stdout =
        await process.stdout.transform(const SystemEncoding().decoder).join();
    final stderr =
        await process.stderr.transform(const SystemEncoding().decoder).join();
    // Dart 3.x 的 detachedWithStdio 不允许访问 exitCode（会抛 StateError）
    // 通过输出内容推断：stdout 有内容则认为成功（exitCode=0），否则失败（exitCode=1）
    int exitCode;
    try {
      exitCode = await process.exitCode;
    } on StateError catch (_) {
      exitCode = stdout.isNotEmpty ? 0 : 1;
    }
    return ProcessResult(process.pid, exitCode, stdout, stderr);
  }

  _killProcess(int port) async {
    final result = await _runHidden('netstat', ['-ano']);
    final lines = result.stdout.toString().trim().split('\n');
    for (final line in lines) {
      if (!line.contains(":$port") || !line.contains("LISTENING")) {
        continue;
      }
      final parts = line.trim().split(RegExp(r'\s+'));
      final pid = int.tryParse(parts.last);
      if (pid != null) {
        await _runHidden('taskkill', ['/PID', pid.toString(), '/F']);
      }
    }
  }

  Future<WindowsHelperServiceStatus> checkService() async {
    // 优先 ping 探测：服务运行时立即成功，避免启动 sc.exe 导致黑框闪烁
    if (await request.pingHelper()) {
      return WindowsHelperServiceStatus.running;
    }
    // Ping 失败时才查询 SCM，区分"未安装"和"已安装但未运行"
    final result = await _runHidden('sc', ['query', appHelperService]);
    if (result.exitCode != 0) {
      return WindowsHelperServiceStatus.none;
    }
    return WindowsHelperServiceStatus.presence;
  }

  /// 解析 `sc query` 输出，返回 {state, win32ExitCode}
  /// state: 1=STOPPED, 2=START_PENDING, 4=RUNNING
  Map<String, int> _parseScQuery(String output) {
    final stateMatch = RegExp(r'STATE\s*:\s*(\d+)').firstMatch(output);
    final exitMatch =
        RegExp(r'WIN32_EXIT_CODE\s*:\s*(\d+)').firstMatch(output);
    return {
      'state': int.tryParse(stateMatch?.group(1) ?? '0') ?? 0,
      'win32ExitCode': int.tryParse(exitMatch?.group(1) ?? '0') ?? 0,
    };
  }

  /// 轮询 sc query，精确等待服务进入 RUNNING(4) 状态。
  /// 一旦检测到 STOPPED + win32ExitCode!=0（启动失败），立即返回 false，
  /// 不等超时——这是 service 方式失败的核心诊断手段。
  Future<bool> _waitForServiceRunning({int maxMs = 12000}) async {
    final steps = maxMs ~/ 500;
    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final result =
          await _runHidden('sc', ['query', appHelperService]);
      if (result.exitCode != 0) continue; // 服务条目尚未写入注册表，继续等
      final info = _parseScQuery(result.stdout.toString());
      final state = info['state'] ?? 0;
      final exitCode = info['win32ExitCode'] ?? 0;
      if (state == 4) return true; // RUNNING ✓
      if (state == 1 && exitCode != 0) {
        // STOPPED + 错误码：服务启动失败，快速退出
        commonPrint.log(
            'registerService: service STOPPED win32ExitCode=$exitCode');
        return false;
      }
      // state=1 exitCode=0（刚 create 未 start）或 state=2（START_PENDING）→ 继续等
    }
    return false;
  }

  /// 轮询 pingHelper HTTP 端口，最多等 [maxMs] 毫秒
  Future<bool> _waitForHelper({int maxMs = 4000}) async {
    final steps = maxMs ~/ 500;
    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await request.pingHelper()) return true;
    }
    return false;
  }

  Future<bool> registerService() async {
    if (await request.pingHelper()) return true;

    // 预检：helper 二进制必须存在才能继续
    final helperExe = appPath.helperPath;
    if (!File(helperExe).existsSync()) {
      commonPrint.log('registerService: helper not found: $helperExe');
      return false;
    }

    await _killProcess(helperPort);
    final status = await checkService();

    // ── Phase 1: Windows Service（单次 UAC）────────────────────────────
    // cmd.exe /c 串联：(可选 delete &&) create && start
    // 用 _waitForServiceRunning 轮询 sc query STATE，快速感知成功/失败
    final svcCmd = [
      '/c',
      if (status == WindowsHelperServiceStatus.presence) ...[
        'sc', 'delete', appHelperService, '&&',
      ],
      'sc', 'create', appHelperService,
      'binPath= "$helperExe"',
      'start= auto', '&&',
      'sc', 'start', appHelperService,
    ].join(' ');

    if (runas('cmd.exe', svcCmd)) {
      if (await _waitForServiceRunning(maxMs: 12000)) {
        // 服务进程已进入 RUNNING，等 HTTP 服务器就绪（通常 <1s）
        if (await _waitForHelper(maxMs: 4000)) return true;
        commonPrint.log('registerService: service running but HTTP not ready');
      }
      commonPrint.log('registerService: service phase failed, trying fallback');
    }

    // ── Phase 2: 直接以管理员身份运行 helper 进程（绕过 SCM）──────────
    // 适用于 Win11 Smart App Control / 安全策略阻止服务安装的场景
    commonPrint.log('registerService: launching helper as elevated process');
    if (runas(helperExe, '')) {
      if (await _waitForHelper(maxMs: 6000)) return true;
      commonPrint.log('registerService: direct elevated process timed out');
    }

    return false;
  }

  Future<bool> registerTask(String appName) async {
    final taskXml = '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Triggers>
    <LogonTrigger/>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"${Platform.resolvedExecutable}"</Command>
    </Exec>
  </Actions>
</Task>''';
    final taskPath = join(await appPath.tempPath, "task.xml");
    await File(taskPath).create(recursive: true);
    await File(taskPath)
        .writeAsBytes(taskXml.encodeUtf16LeWithBom, flush: true);
    final commandLine = [
      '/Create',
      '/TN',
      appName,
      '/XML',
      "%s",
      '/F',
    ].join(" ");
    return runas(
      'schtasks',
      commandLine.replaceFirst("%s", taskPath),
    );
  }
}

final windows = Platform.isWindows ? Windows() : null;
