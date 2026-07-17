import 'package:fl_clash/xboard/features/streaming_check/models/streaming_test_result.dart';
import 'package:fl_clash/xboard/features/streaming_check/services/streaming_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamingCheckService', () {
    test('parses Cloudflare exit region', () {
      expect(
        StreamingCheckService.parseRegion('ip=1.1.1.1\nloc=us\ntls=TLSv1.3'),
        'US',
      );
      expect(StreamingCheckService.parseRegion('loc=USA'), isNull);
    });

    test('classifies HTTP status codes', () {
      expect(
        StreamingCheckService.classifyStatusCode(200),
        StreamingTestStatus.accessible,
      );
      expect(
        StreamingCheckService.classifyStatusCode(302),
        StreamingTestStatus.accessible,
      );
      expect(
        StreamingCheckService.classifyStatusCode(451),
        StreamingTestStatus.restricted,
      );
      expect(
        StreamingCheckService.classifyStatusCode(403),
        StreamingTestStatus.uncertain,
      );
      expect(
        StreamingCheckService.classifyStatusCode(503),
        StreamingTestStatus.unavailable,
      );
    });

    test('contains unique HTTPS targets including common AI services', () {
      final targets = StreamingCheckService.targets;
      expect(targets.map((target) => target.id).toSet(),
          hasLength(targets.length));
      expect(
        targets.every((target) => Uri.parse(target.url).scheme == 'https'),
        isTrue,
      );
      expect(
        targets.map((target) => target.id),
        containsAll(<String>[
          'chatgpt',
          'claude',
          'gemini',
          'copilot',
          'dazn',
          'crunchyroll',
          'tiktok',
          'grok',
          'google_ai_studio',
        ]),
      );
      final ids = targets.map((target) => target.id);
      for (final removedId in <String>[
        'spotify',
        'hulu',
        'peacock',
        'paramount_plus',
        'meta_ai',
        'perplexity',
      ]) {
        expect(ids, isNot(contains(removedId)));
      }
    });

    test('recognizes Cloudflare browser verification separately from region',
        () {
      expect(
        StreamingCheckService.isCloudflareChallenge({
          'status-code': 403,
          'headers': {'Server': 'cloudflare', 'Cf-Mitigated': 'challenge'},
          'body': '<title>Just a moment...</title>',
        }),
        isTrue,
      );
      expect(
        StreamingCheckService.isCloudflareChallenge({
          'status-code': 403,
          'headers': {'Server': 'CloudFront'},
          'body': 'The request could not be satisfied',
        }),
        isFalse,
      );
    });
  });
}
