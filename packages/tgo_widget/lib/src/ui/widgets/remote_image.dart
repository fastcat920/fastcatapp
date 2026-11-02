import 'dart:convert';
import 'dart:collection';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Handles API image endpoints whose URLs have no file extension (including SVG).
class RemoteImage extends StatefulWidget {
  final String url;
  final double size;
  final Widget fallback;
  final Dio? client;
  const RemoteImage(
      {super.key,
      required this.url,
      required this.size,
      required this.fallback,
      this.client});
  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageData {
  final Uint8List bytes;
  final bool isSvg;
  const _RemoteImageData(this.bytes, this.isSvg);
}

class _RemoteImageState extends State<RemoteImage> {
  // Rows in a lazy list are routinely disposed while scrolling. Keep decoded
  // source bytes outside each row so rebuilding an avatar does not show the
  // placeholder and issue another HTTP request.
  static const _maxCachedImages = 80;
  static const _maxCachedBytes = 24 * 1024 * 1024;
  static final LinkedHashMap<String, _RemoteImageData> _cache =
      LinkedHashMap<String, _RemoteImageData>();
  static final Map<String, Future<_RemoteImageData?>> _pending = {};
  static final Dio _defaultClient = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Uint8List? _bytes;
  bool _svg = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _svg = false;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url.trim();
    if (url.isEmpty) return;

    final cached = _takeCached(url);
    if (cached != null) {
      _bytes = cached.bytes;
      _svg = cached.isSvg;
      return;
    }

    try {
      final future = _pending.putIfAbsent(
        url,
        () => _fetch(url, widget.client ?? _defaultClient),
      );
      final image = await future;
      if (image != null && mounted && widget.url.trim() == url) {
        setState(() {
          _bytes = image.bytes;
          _svg = image.isSvg;
          _failed = false;
        });
      } else if (mounted && widget.url.trim() == url) {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted && widget.url.trim() == url) {
        setState(() => _failed = true);
      }
    }
  }

  static _RemoteImageData? _takeCached(String url) {
    final image = _cache.remove(url);
    if (image != null) _cache[url] = image; // refresh its LRU position
    return image;
  }

  static Future<_RemoteImageData?> _fetch(String url, Dio dio) async {
    try {
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      if (bytes.isEmpty) return null;
      final prefix =
          utf8.decode(bytes.take(1024).toList(), allowMalformed: true);
      final image = _RemoteImageData(bytes, prefix.contains('<svg'));

      // Avoid retaining unusually large assets and cap the process-wide cache.
      if (bytes.length <= _maxCachedBytes) {
        _cache.remove(url);
        _cache[url] = image;
        var totalBytes = _cache.values
            .fold<int>(0, (total, cached) => total + cached.bytes.length);
        while (
            _cache.length > _maxCachedImages || totalBytes > _maxCachedBytes) {
          final oldest = _cache.keys.first;
          totalBytes -= _cache.remove(oldest)!.bytes.length;
        }
      }
      return image;
    } finally {
      _pending.remove(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      if (widget.url.trim().isEmpty || _failed) return widget.fallback;
      // During the first network load, reserve the avatar space without
      // presenting a generic support avatar that is immediately replaced by
      // the agent's portrait.
      return CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }
    if (_svg) {
      return ClipOval(
          child: SvgPicture.memory(_bytes!,
              width: widget.size, height: widget.size, fit: BoxFit.cover));
    }
    return ClipOval(
        child: Image.memory(_bytes!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => widget.fallback));
  }
}
