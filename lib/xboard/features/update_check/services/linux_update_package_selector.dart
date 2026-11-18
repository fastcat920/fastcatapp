import 'dart:io';

/// Keeps an installed DEB/RPM package in its current package manager. For a
/// portable build, only an explicitly recognized distribution family is used.
class LinuxUpdatePackageSelector {
  LinuxUpdatePackageSelector({
    Future<String> Function()? osRelease,
    Future<ProcessResult> Function(String, List<String>)? run,
    String? executable,
  })  : _osRelease = osRelease ?? _readOsRelease,
        _run = run ?? ((command, args) => Process.run(command, args)),
        _executable = executable ?? Platform.resolvedExecutable;
  final Future<String> Function() _osRelease;
  final Future<ProcessResult> Function(String, List<String>) _run;
  final String _executable;

  static Future<String> _readOsRelease() async {
    for (final path in ['/etc/os-release', '/usr/lib/os-release']) {
      try {
        return await File(path).readAsString();
      } on FileSystemException catch (_) {}
    }
    return '';
  }

  static String? fromOsRelease(String source) {
    final values = <String, String>{};
    for (final line in source.split('\n')) {
      final match = RegExp(r'^(ID|ID_LIKE)=(.*)$').firstMatch(line.trim());
      if (match != null) {
        values[match[1]!] =
            match[2]!.replaceAll(RegExp('["\']'), '').trim().toLowerCase();
      }
    }
    const families = {
      'debian': 'deb',
      'ubuntu': 'deb',
      'linuxmint': 'deb',
      'pop': 'deb',
      'elementary': 'deb',
      'kali': 'deb',
      'deepin': 'deb',
      'fedora': 'rpm',
      'rhel': 'rpm',
      'centos': 'rpm',
      'rocky': 'rpm',
      'almalinux': 'rpm',
      'opensuse': 'rpm',
      'opensuse-leap': 'rpm',
      'opensuse-tumbleweed': 'rpm',
      'sles': 'rpm'
    };
    final direct = families[values['ID']];
    if (direct != null) return direct;
    final matches = (values['ID_LIKE'] ?? '')
        .split(RegExp(r'\s+'))
        .map((id) => families[id])
        .whereType<String>()
        .toSet();
    return matches.length == 1 ? matches.single : null;
  }

  Future<bool> _owns(String command, List<String> arguments) async {
    try {
      final result =
          await _run(command, arguments).timeout(const Duration(seconds: 2));
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<String?> detect() async {
    final owned = await Future.wait([
      _owns('dpkg-query', ['-S', '--', _executable]),
      _owns('rpm', ['-qf', '--', _executable]),
    ]);
    if (owned[0] && owned[1]) return null;
    if (owned[0]) return 'deb';
    if (owned[1]) return 'rpm';
    return fromOsRelease(await _osRelease());
  }
}
