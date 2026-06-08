/// HTTP 配置类
class HttpConfig {
  /// User-Agent 字符串（null 时使用默认值）
  final String? userAgent;

  /// 是否启用证书固定（Certificate Pinning）
  final bool enableCertificatePinning;

  /// 证书文件路径（相对于 assets 目录）
  final String? certificatePath;

  /// 是否忽略证书主机名验证（仅开发环境）
  final bool ignoreCertificateHostname;

  /// HTTP 代理 URL（null 时直连）
  final String? proxyUrl;

  /// 连接超时（秒）
  final int connectTimeoutSeconds;

  /// 接收超时（秒）
  final int receiveTimeoutSeconds;

  /// 发送超时（秒）
  final int sendTimeoutSeconds;

  const HttpConfig({
    this.userAgent,
    this.enableCertificatePinning = false,
    this.certificatePath,
    this.ignoreCertificateHostname = false,
    this.proxyUrl,
    this.connectTimeoutSeconds = 30,
    this.receiveTimeoutSeconds = 30,
    this.sendTimeoutSeconds = 30,
  });

  factory HttpConfig.defaultConfig() {
    return const HttpConfig(
      enableCertificatePinning: false,
    );
  }

  factory HttpConfig.development({String? userAgent, String? proxyUrl}) {
    return HttpConfig(
      userAgent: userAgent,
      proxyUrl: proxyUrl,
      enableCertificatePinning: false,
      ignoreCertificateHostname: true,
    );
  }

  factory HttpConfig.production({
    required String userAgent,
    bool enableCertificatePinning = false,
    String? certificatePath,
  }) {
    if (enableCertificatePinning && certificatePath == null) {
      throw ArgumentError(
        'enableCertificatePinning 为 true 时必须提供 certificatePath',
      );
    }
    return HttpConfig(
      userAgent: userAgent,
      enableCertificatePinning: enableCertificatePinning,
      certificatePath: certificatePath,
      ignoreCertificateHostname: false,
    );
  }

  HttpConfig copyWith({
    String? userAgent,
    bool? enableCertificatePinning,
    String? certificatePath,
    bool? ignoreCertificateHostname,
    String? proxyUrl,
    int? connectTimeoutSeconds,
    int? receiveTimeoutSeconds,
    int? sendTimeoutSeconds,
  }) {
    return HttpConfig(
      userAgent: userAgent ?? this.userAgent,
      enableCertificatePinning: enableCertificatePinning ?? this.enableCertificatePinning,
      certificatePath: certificatePath ?? this.certificatePath,
      ignoreCertificateHostname: ignoreCertificateHostname ?? this.ignoreCertificateHostname,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      connectTimeoutSeconds: connectTimeoutSeconds ?? this.connectTimeoutSeconds,
      receiveTimeoutSeconds: receiveTimeoutSeconds ?? this.receiveTimeoutSeconds,
      sendTimeoutSeconds: sendTimeoutSeconds ?? this.sendTimeoutSeconds,
    );
  }

  @override
  String toString() {
    return 'HttpConfig('
        'userAgent: $userAgent, '
        'enableCertificatePinning: $enableCertificatePinning, '
        'ignoreCertificateHostname: $ignoreCertificateHostname, '
        'proxyUrl: $proxyUrl'
        ')';
  }
}
