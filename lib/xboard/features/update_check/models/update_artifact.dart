import 'dart:ffi';

/// Describes an installer, never a web landing page. Integrity metadata is
/// carried by the signed remote configuration rather than by the download host.
class UpdateArtifact {
  const UpdateArtifact(
      {required this.url,
      required this.sha256,
      required this.type,
      this.size,
      this.mirrors = const []});
  final String url, sha256, type;
  final int? size;
  final List<String> mirrors;
  factory UpdateArtifact.fromJson(Map<String, dynamic> json) => UpdateArtifact(
      url: '${json['url'] ?? ''}',
      sha256: '${json['sha256'] ?? ''}'.toLowerCase(),
      type: '${json['package_type'] ?? ''}'.toLowerCase(),
      size: int.tryParse('${json['size'] ?? ''}'),
      mirrors: (json['mirrors'] is List ? json['mirrors'] as List : const [])
          .whereType<String>()
          .toList());
  Map<String, dynamic> toJson() => {
        'url': url,
        'sha256': sha256,
        'package_type': type,
        if (size != null) 'size': size,
        if (mirrors.isNotEmpty) 'mirrors': mirrors
      };
  bool get isValid =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) &&
      ['apk', 'exe', 'dmg', 'deb', 'rpm', 'appimage'].contains(type) &&
      [url, ...mirrors].every((s) {
        final u = Uri.tryParse(s);
        return u?.scheme == 'https' && u!.host.isNotEmpty && u.userInfo.isEmpty;
      }) &&
      (size == null || (size! > 0 && size! <= 2 * 1024 * 1024 * 1024));
  bool supportsPlatform(String platform) => switch (platform) {
        'android' || 'android_tv' => type == 'apk',
        'windows' => type == 'exe',
        'macos' => type == 'dmg',
        'linux' => ['deb', 'rpm', 'appimage'].contains(type),
        _ => false,
      };

  static List<String> architectureKeys([Abi? architecture]) {
    final abi = architecture ?? Abi.current();
    if ([Abi.androidArm64, Abi.linuxArm64, Abi.macosArm64, Abi.windowsArm64]
        .contains(abi)) {
      return ['arm64', 'arm64-v8a', 'aarch64', 'universal'];
    }
    if ([Abi.androidArm, Abi.linuxArm].contains(abi)) {
      return ['arm', 'armeabi-v7a', 'armv7', 'universal'];
    }
    if ([Abi.androidX64, Abi.linuxX64, Abi.macosX64, Abi.windowsX64]
        .contains(abi)) {
      return ['x64', 'x86_64', 'amd64', 'universal'];
    }
    return ['universal'];
  }
}
