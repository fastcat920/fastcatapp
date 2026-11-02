import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgo_widget/src/ui/widgets/remote_image.dart';

class ImageAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.uri.toString());
    return ResponseBody.fromString(
        '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="red"/></svg>',
        200,
        headers: {
          Headers.contentTypeHeader: ['image/svg+xml']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
      'extensionless SVG endpoint renders and reloads when version changes',
      (tester) async {
    final adapter = ImageAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    Widget image(String url) => MaterialApp(
        home: RemoteImage(
            url: url,
            size: 20,
            client: dio,
            fallback: const Icon(Icons.person)));
    await tester.pumpWidget(image('https://example.invalid/logo?v=one.svg'));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(adapter.requests, hasLength(1));
    await tester.pumpWidget(image('https://example.invalid/logo?v=two.svg'));
    await tester.pumpAndSettle();
    expect(adapter.requests.last, endsWith('v=two.svg'));
    expect(adapter.requests, hasLength(2));
    await tester.pumpWidget(image(''));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(adapter.requests, hasLength(2));
    dio.close();
  });
  testWidgets('notification is packaged at the exact package asset key',
      (tester) async {
    final bytes = await rootBundle
        .load('packages/tgo_widget/assets/sounds/notification.wav');
    expect(ascii.decode(bytes.buffer.asUint8List(0, 4)), 'RIFF');
    expect(bytes.lengthInBytes, greaterThan(44));
  });
}
