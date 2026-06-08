import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../exceptions/xboard_exceptions.dart';
import '../auth/token_manager.dart';
import '../auth/auth_interceptor.dart';
import '../logging/sdk_logger.dart';
import 'http_config.dart';

class HttpEndpointConfig {
  final String baseUrl;
  final String apiPrefix;

  const HttpEndpointConfig({
    required this.baseUrl,
    required this.apiPrefix,
  });
}

enum RequestFailoverKind {
  bootstrap,
  auth,
  subscription,
  device,
  user,
  general,
}

class HttpService {
  String _baseUrl;
  final HttpConfig httpConfig;
  final bool useBearerPrefix;

  /// API 路径前缀，默认 '/api/v1'，可自定义（如 PPanel 使用 '/v1'）
  String _apiPrefix;

  /// 故障转移回调：当连接失败时调用，返回下一个可用的面板URL（null 表示无更多候选）
  final Future<String?> Function()? nextUrlProvider;

  /// 故障转移回调：当连接失败时调用，返回下一个可用的完整端点配置
  final Future<HttpEndpointConfig?> Function()? nextEndpointProvider;

  /// 故障转移成功回调：切换到新 URL 并请求成功后调用，传入新 URL
  final void Function(String url)? onFailoverSuccess;
  final void Function(HttpEndpointConfig endpoint)? onEndpointFailoverSuccess;
  final void Function(HttpEndpointConfig endpoint, Object error)?
      onEndpointFailure;
  late final Dio _dio;
  TokenManager? _tokenManager;
  AuthInterceptor? _authInterceptor;
  String? _expectedCertificatePem;
  bool _certificateLoadFailed = false;

  HttpService._internal(
    this._baseUrl,
    this.httpConfig,
    this._tokenManager, {
    this.useBearerPrefix = true,
    String apiPrefix = '/api/v1',
    this.nextUrlProvider,
    this.nextEndpointProvider,
    this.onFailoverSuccess,
    this.onEndpointFailoverSuccess,
    this.onEndpointFailure,
  }) : _apiPrefix = apiPrefix;

  /// 创建 HttpService 实例（异步工厂方法）
  static Future<HttpService> create(
    String baseUrl, {
    TokenManager? tokenManager,
    HttpConfig? httpConfig,
    bool useBearerPrefix = true,
    String apiPrefix = '/api/v1',
    Future<String?> Function()? nextUrlProvider,
    Future<HttpEndpointConfig?> Function()? nextEndpointProvider,
    void Function(String url)? onFailoverSuccess,
    void Function(HttpEndpointConfig endpoint)? onEndpointFailoverSuccess,
    void Function(HttpEndpointConfig endpoint, Object error)? onEndpointFailure,
  }) async {
    final config = httpConfig ?? HttpConfig.defaultConfig();
    final service = HttpService._internal(
      baseUrl,
      config,
      tokenManager,
      useBearerPrefix: useBearerPrefix,
      apiPrefix: apiPrefix,
      nextUrlProvider: nextUrlProvider,
      nextEndpointProvider: nextEndpointProvider,
      onFailoverSuccess: onFailoverSuccess,
      onEndpointFailoverSuccess: onEndpointFailoverSuccess,
      onEndpointFailure: onEndpointFailure,
    );

    // 如果启用证书固定，先加载证书
    if (config.enableCertificatePinning == true) {
      await service._loadClientCertificate();
    }

    // 初始化 Dio
    service._initializeDio();

    return service;
  }

  /// 初始化Dio配置
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: httpConfig.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: httpConfig.receiveTimeoutSeconds),
      sendTimeout: Duration(seconds: httpConfig.sendTimeoutSeconds),
      responseType: ResponseType.plain,
      headers: {
        'Accept': 'application/json',
        // 使用配置的 User-Agent，如果未设置则使用默认值
        'User-Agent': httpConfig.userAgent ?? 'fastcat-SDK',
      },
    ));

    // 配置客户端证书和SSL验证
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      SdkLogger.d('[XBoardSDK] 🔨 创建 HttpClient...');
      final client = HttpClient()
        ..idleTimeout =
            const Duration(seconds: 25) // 主动在服务端关闭前回收空闲连接（服务端通常 60~90s）
        // 绕过全局 FastcatHttpOverrides：Clash 代理端口不可用时不影响 XBoard API 调用
        ..findProxy = (_) => 'DIRECT';

      // 配置代理
      if (httpConfig.proxyUrl != null && httpConfig.proxyUrl!.isNotEmpty) {
        SdkLogger.d('[XBoardSDK] 🔌 配置代理: ${httpConfig.proxyUrl}');

        final proxyConfig = _parseProxyConfig(httpConfig.proxyUrl!);
        SdkLogger.d(
            '[XBoardSDK] 🔄 解析: host=${proxyConfig['host']}, port=${proxyConfig['port']}, auth=${proxyConfig['username'] != null}');

        // 使用 socks5_proxy 配置代理
        final proxySettings = ProxySettings(
          InternetAddress(proxyConfig['host']!),
          int.parse(proxyConfig['port']!),
          username: proxyConfig['username'],
          password: proxyConfig['password'],
        );

        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
        SdkLogger.i('[XBoardSDK] ✅ SOCKS5 代理配置完成');
      }

      // 配置SSL证书验证
      if (httpConfig.enableCertificatePinning ||
          httpConfig.ignoreCertificateHostname) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // 如果启用了证书固定，进行严格验证
          if (httpConfig.enableCertificatePinning) {
            return _verifyCertificate(cert, host, port);
          }
          // 如果允许忽略主机名验证（仅开发环境）
          if (httpConfig.ignoreCertificateHostname) {
            return true;
          }
          // 默认使用标准验证
          return false;
        };
      }

      return client;
    };

    // 添加拦截器（生产环境移除日志拦截器）

    // 添加请求日志和响应格式化拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 打印请求信息和代理状态
        final fullUrl = options.uri.toString();
        final proxyStatus =
            httpConfig.proxyUrl != null && httpConfig.proxyUrl!.isNotEmpty;
        final proxyInfo = proxyStatus ? httpConfig.proxyUrl : 'DIRECT';
        final hitGateway = _maskGatewayAddress(_baseUrl);
        final failoverKind = _classifyRequest(options.path).name;
        SdkLogger.d(
            '[XBoardSDK] 📡 ${options.method} $fullUrl | proxy: $proxyStatus ($proxyInfo)');
        SdkLogger.i(
            '[HttpService] 🎯 本次请求命中网关: $hitGateway$_apiPrefix | type=$failoverKind');

        handler.next(options);
      },
      onResponse: (response, handler) {
        response.data = _normalizeResponse(_parseResponseData(response));
        handler.next(response);
      },
      onError: (error, handler) {
        final normalizedError = _handleDioError(error);
        handler.next(normalizedError);
      },
    ));

    // 添加认证拦截器
    if (_tokenManager != null) {
      _authInterceptor = AuthInterceptor(
          tokenManager: _tokenManager!, useBearerPrefix: useBearerPrefix);
      _dio.interceptors.add(_authInterceptor!);
    }

    // 添加故障转移拦截器（最后添加，错误处理时最先被调用）
    if (nextUrlProvider != null || nextEndpointProvider != null) {
      _dio.interceptors.add(InterceptorsWrapper(
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode ?? 0;
          final requestKind = _classifyRequest(error.requestOptions.path);
          if (!_shouldTriggerFailover(error, requestKind)) {
            handler.next(error);
            return;
          }
          SdkLogger.w(
              '[HttpService] 触发故障转移: type=${requestKind.name}, status=$statusCode, path=${error.requestOptions.path}');

          onEndpointFailure?.call(
            HttpEndpointConfig(baseUrl: _baseUrl, apiPrefix: _apiPrefix),
            error,
          );

          // 循环尝试所有候选 URL，直到成功或全部耗尽
          var retryCount =
              error.requestOptions.extra['_failover_count'] as int? ?? 0;

          while (retryCount < 8) {
            final nextEndpoint = nextEndpointProvider != null
                ? await nextEndpointProvider!()
                : await nextUrlProvider!().then((nextUrl) {
                    if (nextUrl == null) return null;
                    return HttpEndpointConfig(
                      baseUrl: nextUrl,
                      apiPrefix: _apiPrefix,
                    );
                  });
            if (nextEndpoint == null) break;

            final cleanUrl = nextEndpoint.baseUrl.endsWith('/')
                ? nextEndpoint.baseUrl.substring(
                    0,
                    nextEndpoint.baseUrl.length - 1,
                  )
                : nextEndpoint.baseUrl;

            SdkLogger.w(
                '[HttpService] 🔄 故障转移到候选 #${retryCount + 1}: ${_maskGatewayAddress(cleanUrl)}${nextEndpoint.apiPrefix}');

            updateEndpoint(
              cleanUrl,
              apiPrefix: nextEndpoint.apiPrefix,
            );
            error.requestOptions.baseUrl = cleanUrl;
            retryCount++;
            error.requestOptions.extra['_failover_count'] = retryCount;

            try {
              final response = await _dio.fetch(error.requestOptions);

              // 检查业务层：success: false 说明备选网关的业务后端拒绝请求
              // （如用户凭据在该实例无效），应继续尝试下一个 URL
              final respData = response.data;
              if (respData is Map && respData['success'] == false) {
                SdkLogger.w(
                    '[HttpService] 候选 URL 返回业务失败，继续尝试下一个');
                onEndpointFailure?.call(
                  HttpEndpointConfig(
                    baseUrl: cleanUrl,
                    apiPrefix: nextEndpoint.apiPrefix,
                  ),
                  'business_failure',
                );
                continue;
              }

              onFailoverSuccess?.call(cleanUrl);
              onEndpointFailoverSuccess?.call(
                HttpEndpointConfig(
                  baseUrl: cleanUrl,
                  apiPrefix: _apiPrefix,
                ),
              );
              handler.resolve(response);
              return;
            } catch (_) {
              // 连接错误，继续尝试下一个 URL
              onEndpointFailure?.call(
                HttpEndpointConfig(
                  baseUrl: cleanUrl,
                  apiPrefix: nextEndpoint.apiPrefix,
                ),
                error,
              );
              continue;
            }
          }

          SdkLogger.w(
              '[HttpService] ⛔ 故障转移耗尽（$retryCount 次），放弃重试');
          handler.next(error);
        },
      ));
    }
  }

  /// 设置TokenManager
  void setTokenManager(TokenManager tokenManager) {
    _tokenManager = tokenManager;

    // 移除旧的认证拦截器
    if (_authInterceptor != null) {
      _dio.interceptors.remove(_authInterceptor!);
    }

    // 添加新的认证拦截器
    _authInterceptor = AuthInterceptor(
        tokenManager: tokenManager, useBearerPrefix: useBearerPrefix);
    _dio.interceptors.add(_authInterceptor!);
  }

  /// 发送GET请求
  /// 拼接 API 前缀和路径
  String _buildPath(String path) => '$_apiPrefix$path';

  String get baseUrl => _baseUrl;

  String get apiPrefix => _apiPrefix;

  void updateEndpoint(String baseUrl, {String? apiPrefix}) {
    final cleanUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    _baseUrl = cleanUrl;
    _dio.options.baseUrl = cleanUrl;
    if (apiPrefix != null && apiPrefix.isNotEmpty) {
      _apiPrefix = apiPrefix.startsWith('/') ? apiPrefix : '/$apiPrefix';
    }
  }

  /// 检查业务层返回的 success 字段，失败时抛出 ApiException 并携带后端消息
  Map<String, dynamic> _checkBusinessError(Map<String, dynamic> result) {
    if (result['success'] == false) {
      final message = result['message']?.toString() ?? '请求失败';
      throw ApiException(message);
    }
    return result;
  }

  Future<Map<String, dynamic>> getRequest(String path,
      {Map<String, String>? headers}) async {
    try {
      final response = await _dio.get(
        _buildPath(path),
        options: Options(headers: headers),
      );

      return _checkBusinessError(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw _convertDioError(e);
    }
  }

  /// 发送POST请求
  Future<Map<String, dynamic>> postRequest(
      String path, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    try {
      final response = await _dio.post(
        _buildPath(path),
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...?headers,
          },
        ),
      );

      return _checkBusinessError(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw _convertDioError(e);
    }
  }

  /// 发送PUT请求
  Future<Map<String, dynamic>> putRequest(
      String path, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    try {
      final response = await _dio.put(
        _buildPath(path),
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            ...?headers,
          },
        ),
      );

      return _checkBusinessError(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw _convertDioError(e);
    }
  }

  /// 发送DELETE请求
  Future<Map<String, dynamic>> deleteRequest(String path,
      {Map<String, String>? headers}) async {
    try {
      final response = await _dio.delete(
        _buildPath(path),
        options: Options(headers: headers),
      );

      return _checkBusinessError(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw _convertDioError(e);
    }
  }

  /// 解析响应数据为 JSON 或原始文本
  dynamic _parseResponseData(Response response) {
    try {
      final responseText = response.data as String;
      final trimmed = responseText.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return jsonDecode(trimmed);
      }
      return responseText;
    } catch (_) {
      return response.data;
    }
  }

  /// 验证客户端证书（Certificate Pinning）
  ///
  /// ⚠️ 安全改进：证书加载失败时拒绝连接
  /// [cert] 服务器证书
  /// [host] 主机名
  /// [port] 端口
  bool _verifyCertificate(X509Certificate cert, String host, int port) {
    try {
      SdkLogger.i('[HttpService] 🔐 开始验证证书: $host:$port');

      // 安全检查：如果证书加载失败，拒绝连接
      if (_certificateLoadFailed) {
        SdkLogger.e('[HttpService] ❌ 证书加载失败，拒绝连接');
        throw CertificateException(
            'Certificate pinning is enabled but certificate failed to load. '
            'Refusing connection for security reasons.');
      }

      // 安全检查：如果启用了证书固定但没有期望的证书，拒绝连接
      if (httpConfig.enableCertificatePinning &&
          _expectedCertificatePem == null) {
        SdkLogger.e('[HttpService] ❌ 证书固定已启用但未加载期望证书');
        throw CertificateException(
            'Certificate pinning is enabled but no expected certificate is available. '
            'Refusing connection for security reasons.');
      }

      // 打印服务器证书信息
      SdkLogger.i('[HttpService] 📜 服务器证书信息:');
      SdkLogger.i('[HttpService]   - 主体: ${cert.subject}');
      SdkLogger.i('[HttpService]   - 签发者: ${cert.issuer}');
      SdkLogger.i(
          '[HttpService]   - 有效期: ${cert.startValidity} ~ ${cert.endValidity}');

      // 获取当前证书的PEM格式
      final currentCertPem = cert.pem;

      SdkLogger.i('[HttpService] 🔍 比较证书指纹...');
      SdkLogger.i(
          '[HttpService]   - 期望证书长度: ${_expectedCertificatePem!.length} 字符');
      SdkLogger.i('[HttpService]   - 服务器证书长度: ${currentCertPem.length} 字符');

      // 比较证书内容（忽略空白字符差异）
      final expectedNormalized =
          _expectedCertificatePem!.replaceAll(RegExp(r'\s+'), '');
      final currentNormalized = currentCertPem.replaceAll(RegExp(r'\s+'), '');

      SdkLogger.i('[HttpService]   - 标准化后期望证书长度: ${expectedNormalized.length}');
      SdkLogger.i('[HttpService]   - 标准化后服务器证书长度: ${currentNormalized.length}');

      final isValid = expectedNormalized == currentNormalized;

      if (!isValid) {
        SdkLogger.e('[HttpService] ❌ 证书不匹配！');
        SdkLogger.e(
            '[HttpService]   - 期望证书前100字符: ${expectedNormalized.substring(0, 100.clamp(0, expectedNormalized.length))}');
        SdkLogger.e(
            '[HttpService]   - 服务器证书前100字符: ${currentNormalized.substring(0, 100.clamp(0, currentNormalized.length))}');
        throw CertificateException(
            'Certificate verification failed for $host:$port. '
            'The certificate does not match the expected certificate.');
      }

      SdkLogger.i('[HttpService] ✅ 证书验证成功！');
      return isValid;
    } catch (e) {
      // 证书验证出错，为安全起见拒绝连接
      SdkLogger.e('[HttpService] ⛔ 证书验证异常: $e');
      return false;
    }
  }

  /// 加载客户端证书
  ///
  /// 从配置文件指定的路径加载证书（xboard.config.yaml -> security.certificate.path）
  /// 证书加载失败时会拒绝所有 HTTPS 连接以保证安全
  Future<void> _loadClientCertificate() async {
    SdkLogger.i('[HttpService] 📋 开始加载证书...');
    SdkLogger.i(
        '[HttpService]   - 证书固定: ${httpConfig.enableCertificatePinning}');
    SdkLogger.i('[HttpService]   - 证书路径: ${httpConfig.certificatePath}');

    if (httpConfig.certificatePath == null ||
        httpConfig.certificatePath!.isEmpty) {
      _certificateLoadFailed = true;
      _expectedCertificatePem = null;
      SdkLogger.w('[HttpService] ⚠️ 证书路径未配置');
      return;
    }

    final certPath = httpConfig.certificatePath!;

    try {
      SdkLogger.i('[HttpService] 🔄 正在从 assets 加载证书: $certPath');

      // 同步等待证书加载
      final certContent = await rootBundle.loadString(certPath);

      _expectedCertificatePem = certContent;
      _certificateLoadFailed = false;

      SdkLogger.i('[HttpService] ✅ 证书加载成功！');
      SdkLogger.i('[HttpService]   - 证书内容长度: ${certContent.length} 字符');
      SdkLogger.i(
          '[HttpService]   - 证书前100字符: ${certContent.substring(0, 100.clamp(0, certContent.length))}');
    } catch (error) {
      _certificateLoadFailed = true;
      _expectedCertificatePem = null;
      SdkLogger.e('[HttpService] ❌ 证书加载失败！');
      SdkLogger.e('[HttpService]   - 错误: $error');
      SdkLogger.e('[HttpService]   - 所有 HTTPS 连接将被拒绝');
    }
  }

  /// 标准化响应格式
  Map<String, dynamic> _normalizeResponse(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      return {
        'success': true,
        'data': responseData,
      };
    }

    final jsonResponse = responseData;

    // 兼容两种响应格式：
    // 1. XBoard格式: {status: "success", data: {...}}
    // 2. 通用格式: {success: true, data: {...}}

    if (jsonResponse.containsKey('status')) {
      // XBoard格式 -> 转换为通用格式
      return {
        'success': jsonResponse['status'] == 'success',
        'status': jsonResponse['status'],
        'message': jsonResponse['message'],
        'data': jsonResponse['data'],
        'total': jsonResponse['total'],
      };
    } else if (jsonResponse.containsKey('success')) {
      // 已经是通用格式，直接返回
      return jsonResponse;
    } else if (jsonResponse.containsKey('data')) {
      // V2Board格式: {"data": {...}} — 展开原始响应保留所有顶层字段
      // （例如 checkout 返回 {"type":1,"data":"https://..."} 的 type 字段不能丢）
      return {
        ...jsonResponse,
        'success': true,
      };
    } else if (jsonResponse.containsKey('message') &&
        !jsonResponse.containsKey('data')) {
      // V2Board 错误格式: {"message": "邮箱或密码错误"} — 只有 message 没有 data，视为失败
      return {
        'success': false,
        'message': jsonResponse['message'],
      };
    } else {
      // 其他格式，包装为通用格式
      return {
        'success': true,
        'data': jsonResponse,
      };
    }
  }

  /// 处理Dio错误
  DioException _handleDioError(DioException error) {
    if (error.response != null) {
      final statusCode = error.response!.statusCode!;

      dynamic responseData = _parseResponseData(error.response!);

      String errorMessage = '请求失败 (状态码: $statusCode)';

      // 打印响应数据以便调试
      SdkLogger.w(
          '[HttpService] Error Response (status: $statusCode): $responseData');

      // 尝试从响应中提取错误信息
      String errorCode = '';
      if (responseData is Map<String, dynamic>) {
        // 提取网关 error code（如 BACKEND_UNREACHABLE）
        if (responseData.containsKey('code') &&
            responseData['code'] != null &&
            responseData['code'].toString().isNotEmpty) {
          errorCode = responseData['code'].toString();
        }
        // 优先级：message > error > data
        if (responseData.containsKey('message') &&
            responseData['message'] != null &&
            responseData['message'].toString().isNotEmpty) {
          errorMessage = responseData['message'].toString();
        } else if (responseData.containsKey('error') &&
            responseData['error'] != null &&
            responseData['error'].toString().isNotEmpty) {
          // error 可能是字符串或对象
          final errorField = responseData['error'];
          if (errorField is String) {
            errorMessage = errorField;
          } else if (errorField is Map) {
            errorMessage = errorField.toString();
          }
        } else if (responseData.containsKey('data') &&
            responseData['data'] is String) {
          errorMessage = responseData['data'].toString();
        }
      } else if (responseData is String && responseData.isNotEmpty) {
        // 如果响应是纯文本，尝试提取有用信息
        errorMessage = responseData;
      }

      // 组合 code + message，让上层能按 code 精确分流
      if (errorCode.isNotEmpty) {
        errorMessage = '[$errorCode] $errorMessage';
      }
      SdkLogger.w('[HttpService] Extracted error message: $errorMessage');

      // 创建新的DioException，保持原有的错误信息但添加我们的错误消息
      return DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: errorMessage,
        message: errorMessage,
      );
    }

    return error;
  }

  /// 转换Dio错误为XBoard异常
  XBoardException _convertDioError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final statusCode = error.response!.statusCode!;
        // 直接使用已经提取的错误消息（在 _handleDioError 中处理）
        final errorMessage = error.message ?? error.error?.toString() ?? '请求失败';

        if (statusCode == 401) {
          return AuthException(errorMessage);
        } else if (statusCode >= 400 && statusCode < 500) {
          return ApiException(errorMessage, statusCode);
        } else {
          return NetworkException(errorMessage);
        }
      } else {
        // 网络错误 - 直接使用 Dio 的原始错误信息
        String errorMsg =
            error.error?.toString() ?? error.message ?? error.type.toString();
        return NetworkException(errorMsg);
      }
    } else if (error is XBoardException) {
      return error;
    } else {
      return ApiException(error.toString());
    }
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }

  /// 获取Dio实例（用于高级用法）
  Dio get dio => _dio;

  /// 获取TokenManager
  TokenManager? get tokenManager => _tokenManager;

  /// 解析代理配置
  ///
  /// 输入格式:
  /// - `socks5://user:pass@host:port`
  /// - `socks5://host:port`
  /// - `http://user:pass@host:port`
  ///
  /// 返回: { host, port, username?, password? }
  static Map<String, String?> _parseProxyConfig(String proxyUrl) {
    String url = proxyUrl.trim();

    // 去除协议前缀
    if (url.toLowerCase().startsWith('socks5://')) {
      url = url.substring(9);
    } else if (url.toLowerCase().startsWith('http://')) {
      url = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      url = url.substring(8);
    }

    String? username;
    String? password;
    String hostPort = url;

    // 解析认证信息 user:pass@host:port
    if (url.contains('@')) {
      final atIndex = url.lastIndexOf('@');
      final authPart = url.substring(0, atIndex);
      hostPort = url.substring(atIndex + 1);

      if (authPart.contains(':')) {
        final colonIndex = authPart.indexOf(':');
        username = authPart.substring(0, colonIndex);
        password = authPart.substring(colonIndex + 1);
      }
    }

    // 解析 host:port
    final parts = hostPort.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? parts[1] : '1080';

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }

  RequestFailoverKind _classifyRequest(String path) {
    if (path.contains('/guest/comm/config')) {
      return RequestFailoverKind.bootstrap;
    }
    if (path.contains('/passport/auth/')) {
      return RequestFailoverKind.auth;
    }
    if (path.contains('/user/getSubscribe') || path.contains('/client/subscribe')) {
      return RequestFailoverKind.subscription;
    }
    if (path.contains('/user/devices')) {
      return RequestFailoverKind.device;
    }
    if (path.contains('/user/')) {
      return RequestFailoverKind.user;
    }
    return RequestFailoverKind.general;
  }

  bool _shouldTriggerFailover(
    DioException error,
    RequestFailoverKind kind,
  ) {
    final type = error.type;
    final isConnErr = type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout;
    if (isConnErr) return true;

    final statusCode = error.response?.statusCode;
    if (statusCode == null) return false;
    if (statusCode >= 500) return true;

    switch (kind) {
      case RequestFailoverKind.bootstrap:
      case RequestFailoverKind.auth:
      case RequestFailoverKind.subscription:
      case RequestFailoverKind.device:
        return statusCode == 404;
      case RequestFailoverKind.user:
      case RequestFailoverKind.general:
        return statusCode == 404 || statusCode == 408 || statusCode == 429;
    }
  }

  String _maskGatewayAddress(String raw) {
    final clean = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    final uri = Uri.tryParse(clean);
    if (uri == null || uri.host.isEmpty) {
      return clean;
    }
    final host = uri.host;
    final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    if (isIpv4) {
      final parts = host.split('.');
      if (parts.length == 4) {
        return '${uri.scheme}://${parts.first}.***.***.${parts.last}';
      }
    }
    final hostParts = host.split('.');
    if (hostParts.length >= 2) {
      final root = hostParts.last;
      final second = hostParts[hostParts.length - 2];
      final maskedSecond = second.length <= 2
          ? '${second[0]}*'
          : '${second.substring(0, 1)}***${second.substring(second.length - 1)}';
      final prefix = hostParts.length > 2
          ? '${hostParts.first.substring(0, 1)}***.'
          : '';
      return '${uri.scheme}://$prefix$maskedSecond.$root';
    }
    return '${uri.scheme}://${host.substring(0, 1)}***';
  }
}
