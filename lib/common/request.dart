import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/ip_info_lookup.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';

class Request {
  late final Dio _dio;
  late final Dio _clashDio;
  final _ipInfoLookup = IpInfoLookup();
  String? userAgent;

  Request() {
    _dio = Dio();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          options.headers["User-Agent"] = globalState.ua;
        } catch (_) {
          options.headers["User-Agent"] = appNameEn;
        }
        handler.next(options);
      },
    ));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (Uri uri) {
        // 对 UA 进行 ASCII 安全化，防止中文等非 ASCII 字符导致
        // dart:io 抛出 FormatException: Invalid HTTP header field value
        client.userAgent = _sanitizeHeaderValue(globalState.ua);
        return FastcatHttpOverrides.handleFindProxy(uri);
      };
      return client;
    });
  }

  Future<Response> getFileResponseForUrl(String url) async {
    final response = await _clashDio.get(
      url,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    return response;
  }

  Future<Response> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
      ),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await _dio.get<Uint8List>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) =>
      _ipInfoLookup.check(cancelToken: cancelToken);

  Future<bool> pingHelper() async {
    try {
      final response = await _dio
          .get(
            "http://$localhost:$helperPort/ping",
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 800,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      return (response.data as String) == globalState.coreSHA256;
    } catch (_) {
      return false;
    }
  }

  Future<WindowsHelperRuntimeStatus?> getHelperRuntimeStatus() async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            "http://$localhost:$helperPort/status",
          )
          .timeout(
            const Duration(
              milliseconds: 800,
            ),
          );
      final data = response.data;
      if (response.statusCode != HttpStatus.ok || data == null) {
        return null;
      }
      return WindowsHelperRuntimeStatus.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/start",
            data: json.encode({
              "path": appPath.corePath,
              "arg": arg,
            }),
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 4000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/stop",
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 1500,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }
}

class WindowsHelperRuntimeStatus {
  const WindowsHelperRuntimeStatus({
    required this.version,
    required this.token,
    required this.helperPath,
    required this.servicePathMatches,
    required this.coreRunning,
    required this.corePid,
    required this.recentLogs,
    this.callerAuth,
  });

  final String version;
  final String token;
  final String? helperPath;
  final bool? servicePathMatches;
  final bool coreRunning;
  final int? corePid;
  final List<String> recentLogs;
  final String? callerAuth;

  bool get verifiesCaller => callerAuth == 'process-sha256-v1';

  bool get tokenMatches => token == globalState.coreSHA256;

  factory WindowsHelperRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return WindowsHelperRuntimeStatus(
      version: json['version']?.toString() ?? '',
      callerAuth: json['caller_auth']?.toString(),
      token: json['token']?.toString() ?? '',
      helperPath: json['helper_path']?.toString(),
      servicePathMatches: json['service_path_matches'] is bool
          ? json['service_path_matches'] as bool
          : null,
      coreRunning: json['core_running'] == true,
      corePid: json['core_pid'] is int ? json['core_pid'] as int : null,
      recentLogs: (json['recent_logs'] as List? ?? [])
          .map((item) => SensitiveMasker.maskText(item.toString()))
          .toList(),
    );
  }
}

/// 将字符串中的非 ASCII 字符替换为 '?'，确保可安全用于 HTTP header。
/// HTTP header 值只允许 ASCII 可打印字符 (0x20-0x7E)。
String _sanitizeHeaderValue(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    if (codeUnit >= 0x20 && codeUnit <= 0x7E) {
      buffer.writeCharCode(codeUnit);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

final request = Request();
