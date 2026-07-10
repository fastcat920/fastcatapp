import 'dart:io';

Future<void> bootDiagLog(String message) async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    return;
  }
  try {
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
    final file = File('${directory.path}${separator}boot_diag.log');
    await file.writeAsString(
      '${DateTime.now().toIso8601String()} [dart] $message\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}
