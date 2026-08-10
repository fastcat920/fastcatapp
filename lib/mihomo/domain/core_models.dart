enum MihomoRuntimeStatus { stopped, starting, running, stopping, failed }

class MihomoNode {
  const MihomoNode({
    required this.name,
    required this.type,
    this.delayMs,
  });

  final String name;
  final String type;
  final int? delayMs;

  bool get hasDelay => delayMs != null && delayMs! >= 0;
  bool get timedOut => delayMs != null && delayMs! < 0;
}

class MihomoGroup {
  const MihomoGroup({
    required this.name,
    required this.type,
    required this.nodes,
    this.selected,
    this.hidden = false,
    this.testUrl,
  });

  final String name;
  final String type;
  final List<MihomoNode> nodes;
  final String? selected;
  final bool hidden;
  final String? testUrl;
}

class MihomoTrafficSnapshot {
  const MihomoTrafficSnapshot({
    required this.uploadBytesPerSecond,
    required this.downloadBytesPerSecond,
    required this.totalUploadBytes,
    required this.totalDownloadBytes,
  });

  final int uploadBytesPerSecond;
  final int downloadBytesPerSecond;
  final int totalUploadBytes;
  final int totalDownloadBytes;
}
