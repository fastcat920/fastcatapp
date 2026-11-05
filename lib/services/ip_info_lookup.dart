import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/models/models.dart';

/// Return the first valid public-IP response, or finish when every source has
/// failed. The overall deadline also bounds adapters that ignore Dio timeouts.
class IpInfoLookup {
  IpInfoLookup({
    Dio? client,
    this.timeout = const Duration(seconds: 8),
    Map<String, IpInfo Function(Map<String, dynamic>)>? sources,
  })  : _client = client,
        _sources = sources ??
            {
              'https://ipwho.is/': IpInfo.fromIpwhoIsJson,
              'https://api.ip.sb/geoip/': IpInfo.fromIpSbJson,
              'https://ipapi.co/json/': IpInfo.fromIpApiCoJson,
              'https://ipinfo.io/json/': IpInfo.fromIpInfoIoJson,
            };

  final Dio? _client;
  final Duration timeout;
  final Map<String, IpInfo Function(Map<String, dynamic>)> _sources;

  Future<Result<IpInfo?>> check({CancelToken? cancelToken}) async {
    if (cancelToken?.isCancelled == true) return Result.error('cancelled');
    if (_sources.isEmpty) return Result.success(null);

    // Do not carry pooled proxy connections across node/connection changes.
    // An injected client is owned by the caller; production clients are scoped
    // to this round and closed even when a source ignores cancellation.
    final client = _client ??
        Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout));
    final result = Completer<Result<IpInfo?>>();
    final requests = CancelToken();
    var remaining = _sources.length;
    void complete(Result<IpInfo?> value) {
      if (result.isCompleted) return;
      result.complete(value);
      requests.cancel('IP lookup completed');
    }

    final deadline = Timer(timeout, () => complete(Result.success(null)));
    cancelToken?.whenCancel.then((_) => complete(Result.error('cancelled')));

    Future<void> lookup(
        MapEntry<String, IpInfo Function(Map<String, dynamic>)> source) async {
      try {
        final response = await client.get<Map<String, dynamic>>(
          source.key,
          cancelToken: requests,
          options: Options(
            responseType: ResponseType.json,
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        );
        if (response.statusCode == HttpStatus.ok && response.data != null) {
          final info = source.value(response.data!);
          if (InternetAddress.tryParse(info.ip) != null) {
            complete(Result.success(info));
          }
        }
      } catch (_) {
        // A source can fail, return a non-JSON body, or be cancelled after
        // another source wins. All paths still contribute to completion.
      } finally {
        remaining--;
        if (remaining == 0) complete(Result.success(null));
      }
    }

    try {
      for (final source in _sources.entries) {
        unawaited(lookup(source));
      }
      return await result.future;
    } finally {
      deadline.cancel();
      if (!requests.isCancelled) requests.cancel('IP lookup finished');
      if (_client == null) client.close(force: true);
    }
  }
}
