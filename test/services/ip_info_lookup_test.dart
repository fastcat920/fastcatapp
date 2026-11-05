import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/ip_info_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options, cancelFuture);

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

void main() {
  IpInfoLookup createLookup(FakeAdapter adapter,
      {Duration timeout = const Duration(milliseconds: 100)}) {
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return IpInfoLookup(client: dio, timeout: timeout, sources: {
      'https://a.invalid/': IpInfo.fromIpInfoIoJson,
      'https://b.invalid/': IpInfo.fromIpInfoIoJson,
    });
  }

  test('all network failures complete without waiting for the deadline',
      () async {
    final lookup = createLookup(FakeAdapter((options, _) async {
      throw DioException(requestOptions: options, error: 'offline');
    }), timeout: const Duration(seconds: 30));
    final result = await lookup.check().timeout(const Duration(seconds: 1));
    expect(result.isSuccess, isTrue);
    expect(result.data, isNull);
  });

  test('non-200 and malformed JSON sources both settle', () async {
    final lookup = createLookup(FakeAdapter((options, _) async =>
        options.uri.host == 'a.invalid'
            ? jsonBody({}, status: 503)
            : jsonBody({'ip': 'not-an-ip', 'country': 'US'})));
    expect((await lookup.check()).data, isNull);
  });

  test(
      'invalid response shape and malformed JSON settle without uncaught errors',
      () async {
    final lookup = createLookup(
        FakeAdapter((options, _) async => options.uri.host == 'a.invalid'
            ? jsonBody(['unexpected', 'array'])
            : ResponseBody.fromString('{bad-json', 200, headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              })));
    expect((await lookup.check()).data, isNull);
  });

  test('a parser exception cannot suppress a later valid response', () async {
    final lookup = createLookup(FakeAdapter((options, _) async {
      if (options.uri.host == 'a.invalid') return jsonBody({});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return jsonBody({'ip': '203.0.113.8', 'country': 'US'});
    }));
    expect((await lookup.check()).data?.ip, '203.0.113.8');
  });

  test('first success cancels losers without cancelling caller token',
      () async {
    final cancelled = Completer<void>();
    final lookup = createLookup(FakeAdapter((options, cancelFuture) async {
      if (options.uri.host == 'a.invalid') {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonBody({'ip': '203.0.113.8', 'country': 'US'});
      }
      await cancelFuture;
      cancelled.complete();
      throw DioException.requestCancelled(
          requestOptions: options, reason: 'cancelled');
    }));
    final token = CancelToken();
    expect((await lookup.check(cancelToken: token)).data?.ip, '203.0.113.8');
    await cancelled.future;
    expect(token.isCancelled, isFalse);
  });

  test('already-cancelled and in-flight cancellation settle as cancellation',
      () async {
    final requested = Completer<void>();
    final lookup = createLookup(FakeAdapter((options, _) async {
      if (!requested.isCompleted) requested.complete();
      return Completer<ResponseBody>().future;
    }));
    final preCancelled = CancelToken()..cancel();
    expect((await lookup.check(cancelToken: preCancelled)).isError, isTrue);
    expect(requested.isCompleted, isFalse);
    final token = CancelToken();
    final future = lookup.check(cancelToken: token);
    await requested.future;
    token.cancel();
    final result = await future;
    expect(result.isError, isTrue);
    expect(result.message, 'cancelled');
  });

  test('overall timeout bounds a hanging adapter and permits a new check',
      () async {
    var succeed = false;
    final lookup = createLookup(FakeAdapter((options, _) async {
      if (succeed) return jsonBody({'ip': '203.0.113.9', 'country': 'GB'});
      return Completer<ResponseBody>().future;
    }), timeout: const Duration(milliseconds: 20));
    expect((await lookup.check()).data, isNull);
    succeed = true;
    expect((await lookup.check()).data?.ip, '203.0.113.9');
  });
}
