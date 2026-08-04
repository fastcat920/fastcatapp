import 'dart:async';
import 'dart:io';

Future<void> _pendingBootDiagWrite = Future<void>.value();
int _bootDiagSequence = 0;
final String _bootDiagSession =
    '${DateTime.now().microsecondsSinceEpoch}-${pid.toRadixString(16)}';

Future<void> bootDiagLog(String message) {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return Future<void>.value();
  }

  final sequence = ++_bootDiagSequence;
  final line = '${DateTime.now().toIso8601String()} '
      '[dart][session=$_bootDiagSession][seq=$sequence][pid=$pid] $message\n';
  final completer = Completer<void>();
  _pendingBootDiagWrite = _pendingBootDiagWrite.then((_) async {
    try {
      final file = await _resolveBootDiagFile();
      await _rotateBootDiagIfNeeded(file);
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Diagnostics must never prevent the application from starting.
    } finally {
      completer.complete();
    }
  });
  return completer.future;
}

Future<File> _resolveBootDiagFile() async {
  final base = Platform.isWindows
      ? (Platform.environment['APPDATA'] ??
          '${Platform.environment['USERPROFILE'] ?? Directory.current.path}\\AppData\\Roaming')
      : Platform.isMacOS
          ? '${Platform.environment['HOME'] ?? Directory.current.path}/Library/Application Support'
          : (Platform.environment['XDG_DATA_HOME'] ??
              '${Platform.environment['HOME'] ?? Directory.current.path}/.local/share');
  final directory = Directory(
    Platform.isWindows ? '$base\\FastCat' : '$base/FastCat',
  );
  await directory.create(recursive: true);
  final separator = Platform.isWindows ? '\\' : '/';
  return File('${directory.path}${separator}boot_diag.log');
}

Future<void> _rotateBootDiagIfNeeded(File file) async {
  if (!await file.exists()) return;
  if (await file.length() < 1024 * 1024) return;
  final previous = File('${file.path}.previous');
  if (await previous.exists()) {
    await previous.delete();
  }
  await file.rename(previous.path);
}
