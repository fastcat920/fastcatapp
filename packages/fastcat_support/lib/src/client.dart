import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';

class FastCatException implements Exception {
  FastCatException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Visitor-side SDK. For non-default projects, pass the public widget API key.
class FastCatSupport extends ChangeNotifier {
  FastCatSupport({
    required String baseUrl,
    required this.visitorId,
    this.projectId = 'default',
    this.projectKey,
    http.Client? httpClient,
    this.maxReconnectDelay = const Duration(seconds: 30),
  })  : baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = httpClient ?? http.Client();

  final Uri baseUri;
  final String visitorId;
  final String projectId;
  final String? projectKey;
  final Duration maxReconnectDelay;
  final http.Client _http;
  final List<FastCatMessage> _messages = [];
  final StreamController<Map<String, dynamic>> _events =
      StreamController.broadcast();
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  bool _disposed = false,
      _connected = false,
      _connecting = false,
      _registered = false;
  int _attempt = 0;
  Timer? _cacheWrite;
  String? _pendingMessageId;
  String? _pendingMessageContent;
  String _mode = 'ai';
  String? _lastError;

  String get _cacheKey =>
      'fastcat.messages.${baseUri.host}.${Uri.encodeComponent(projectId)}.${Uri.encodeComponent(visitorId)}';

  List<FastCatMessage> get messages => List.unmodifiable(_messages);
  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _connected;
  bool get connecting => _connecting;
  bool get registered => _registered;
  String get mode => _mode;
  String? get lastError => _lastError;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (projectKey?.isNotEmpty == true)
          'X-FastCat-Project-Key': projectKey!,
      };
  Uri _uri(String path, [Map<String, String>? query]) =>
      baseUri.resolve(path).replace(queryParameters: query);

  Future<dynamic> _call(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Uint8List? bytes,
    String? filename,
  }) async {
    final uri = _uri(path, query);
    late http.Response response;
    if (bytes != null) {
      final request = http.MultipartRequest('POST', uri);
      if (projectKey?.isNotEmpty == true) {
        request.headers['X-FastCat-Project-Key'] = projectKey!;
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename ?? 'upload.bin',
        ),
      );
      response = await http.Response.fromStream(await _http.send(request));
    } else {
      final request = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await _http.send(request));
    }
    dynamic value;
    try {
      value = jsonDecode(response.body);
    } on FormatException {
      value = response.body;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = value is Map ? value['detail'] : null;
      throw FastCatException(
        detail == null ? '请求失败 (${response.statusCode})' : '$detail',
        statusCode: response.statusCode,
      );
    }
    return value;
  }

  Future<void> register({
    FastCatProfile profile = const FastCatProfile(),
  }) async {
    final value = await _call(
      'POST',
      'api/visitors',
      body: {
        'visitor_id': visitorId,
        'project_id': projectId,
        ...profile.toJson(),
        'system_info': {
          'platform': defaultTargetPlatform.name,
          'is_web': kIsWeb,
          ...profile.systemInfo,
        },
      },
    );
    if (value is Map && value['mode'] is String) {
      _mode = value['mode'] as String;
    }
    _registered = true;
    _lastError = null;
    notifyListeners();
  }

  Future<List<FastCatMessage>> history() async {
    final value = await _call(
      'GET',
      'api/widget/history/${Uri.encodeComponent(visitorId)}',
    );
    if (value is! List) throw FastCatException('消息历史格式错误');
    _messages
      ..clear()
      ..addAll(
        value.whereType<Map>().map(
              (row) => FastCatMessage.fromJson(Map<String, dynamic>.from(row)),
            ),
      );
    _scheduleCacheWrite();
    notifyListeners();
    return messages;
  }

  /// Registers an FCM installation ID so the visitor can receive replies
  /// while away. Obtain it from the host app's Firebase Messaging integration.
  Future<void> registerPushToken(
    String token, {
    String? platform,
    bool enabled = true,
  }) async {
    if (token.trim().length < 20) {
      throw FastCatException('Firebase 推送令牌无效');
    }
    await _call(
      'POST',
      'api/widget/push-token',
      body: {
        'visitor_id': visitorId,
        'token': token.trim(),
        'platform': platform ?? defaultTargetPlatform.name,
        'enabled': enabled,
      },
    );
  }

  Future<void> load({FastCatProfile profile = const FastCatProfile()}) async {
    await _restoreCache();
    if (!_registered) await register(profile: profile);
    await history();
    connect();
  }

  Future<void> _restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _messages
        ..clear()
        ..addAll(decoded.whereType<Map>().map((row) {
          final json = Map<String, dynamic>.from(row);
          json['streaming'] = false;
          return FastCatMessage.fromJson(json);
        }));
      notifyListeners();
    } catch (_) {
      // A corrupt or unavailable device cache must not prevent server history loading.
    }
  }

  void _scheduleCacheWrite() {
    _cacheWrite?.cancel();
    _cacheWrite = Timer(const Duration(milliseconds: 300), () {
      _cacheWrite = null;
      _writeCache();
    });
  }

  Future<void> _writeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = _messages.length > 200
          ? _messages.sublist(_messages.length - 200)
          : _messages;
      await prefs.setString(
        _cacheKey,
        jsonEncode(recent.map((message) => message.toJson()).toList()),
      );
    } catch (_) {
      // Persistence is best effort; live chat continues if local storage is full/unavailable.
    }
  }

  void connect() {
    if (_disposed || _connecting || _connected || !_registered) return;
    _connecting = true;
    notifyListeners();
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final socketUri = baseUri.replace(
      scheme: scheme,
      path: '${baseUri.path}ws/${Uri.encodeComponent(visitorId)}'.replaceAll(
        '//',
        '/',
      ),
      queryParameters: projectKey == null ? null : {'key': projectKey!},
    );
    try {
      final channel = WebSocketChannel.connect(socketUri);
      _socket = channel;
      channel.ready.then((_) {
        if (_disposed || _socket != channel) return;
        _connected = true;
        _connecting = false;
        _attempt = 0;
        _lastError = null;
        notifyListeners();
      }).catchError((Object error) {
        _socketError(error);
      });
      _subscription = channel.stream.listen(
        _onData,
        onError: _socketError,
        onDone: _socketClosed,
        cancelOnError: true,
      );
    } catch (error) {
      _socketError(error);
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final event = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final type = event['type'];
      if (type == 'stream.start') {
        _upsert(
          FastCatMessage(
            id: '${event['id']}',
            visitorId: visitorId,
            role: 'ai',
            content: '',
            createdAt: DateTime.now(),
            streaming: true,
          ),
        );
      } else if (type == 'stream.delta') {
        final i = _messages.indexWhere((m) => m.id == '${event['id']}');
        if (i >= 0) {
          _messages[i] = _messages[i].copyWith(
            content: '${_messages[i].content}${event['delta'] ?? ''}',
            streaming: true,
          );
        }
      } else if (type == 'stream.reset') {
        final i = _messages.indexWhere((m) => m.id == '${event['id']}');
        if (i >= 0) {
          _messages[i] = _messages[i].copyWith(content: '', streaming: true);
        }
      } else if (type == 'stream.close') {
        final message = event['message'];
        if (message is Map) {
          _upsert(FastCatMessage.fromJson(Map<String, dynamic>.from(message)));
        } else {
          final i = _messages.indexWhere((m) => m.id == '${event['id']}');
          if (i >= 0) _messages[i] = _messages[i].copyWith(streaming: false);
        }
      } else if (event['id'] != null && event['role'] != null) {
        _upsert(FastCatMessage.fromJson(event));
      } else if (type == 'conversation.mode') {
        _mode = '${event['mode'] ?? _mode}';
      }
      _events.add(event);
      notifyListeners();
    } catch (error) {
      _lastError = '无法解析实时消息：$error';
      notifyListeners();
    }
  }

  void _upsert(FastCatMessage message) {
    final i = _messages.indexWhere((m) => m.id == message.id);
    if (i < 0) {
      _messages.add(message);
    } else {
      _messages[i] = message;
    }
    _scheduleCacheWrite();
  }

  void _socketError(Object error) {
    if (_disposed) return;
    _lastError = '实时连接暂时中断';
    _socketClosed();
  }

  void _socketClosed() {
    if (_disposed) return;
    _connected = false;
    _connecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnect?.isActive == true || !_registered) return;
    final delay = (1 << _attempt.clamp(0, 5)).clamp(
      1,
      maxReconnectDelay.inSeconds,
    );
    _attempt++;
    _reconnect = Timer(Duration(seconds: delay), () async {
      _reconnect = null;
      try {
        await history();
      } catch (_) {
        _lastError = '重连时同步消息失败';
      }
      connect();
    });
  }

  Future<void> send(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    if (!_registered) await register();
    if (_pendingMessageId == null || _pendingMessageContent != text) {
      _pendingMessageId = '$visitorId-${DateTime.now().microsecondsSinceEpoch}';
      _pendingMessageContent = text;
    }
    final value = await _call(
      'POST',
      'api/messages',
      body: {
        'visitor_id': visitorId,
        'content': text,
        'source': 'flutter',
        'message_id': _pendingMessageId,
      },
    );
    _pendingMessageId = null;
    _pendingMessageContent = null;
    if (value is Map && value['visitor_message'] is Map) {
      _upsert(
        FastCatMessage.fromJson(
          Map<String, dynamic>.from(value['visitor_message'] as Map),
        ),
      );
    }
    if (value is Map && value['reply'] is Map) {
      _upsert(
        FastCatMessage.fromJson(
          Map<String, dynamic>.from(value['reply'] as Map),
        ),
      );
    }
    if (value is Map && value['mode'] is String) {
      _mode = value['mode'] as String;
    }
    notifyListeners();
  }

  Future<void> sendFile(Uint8List bytes, String filename) async {
    if (!_registered) await register();
    final value = await _call(
      'POST',
      'api/upload',
      query: {'visitor_id': visitorId},
      bytes: bytes,
      filename: filename,
    );
    if (value is! Map) throw FastCatException('附件上传响应格式错误');
    final url = baseUri.resolve('${value['url']}');
    final ext = filename.split('.').last.toLowerCase();
    final kind = const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(ext)
        ? '图片'
        : const {'mp4', 'mov'}.contains(ext)
            ? '视频'
            : const {'mp3', 'm4a', 'ogg', 'wav'}.contains(ext)
                ? '音频'
                : '附件';
    await send('[$kind] ${value['name']} | $url');
  }

  Future<void> handoff() async {
    final value = await _call(
      'POST',
      'api/conversations/${Uri.encodeComponent(visitorId)}/handoff',
    );
    if (value is Map) _mode = '${value['mode'] ?? 'human'}';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _cacheWrite?.cancel();
    _writeCache();
    _subscription?.cancel();
    _socket?.sink.close();
    _events.close();
    _http.close();
    super.dispose();
  }
}
