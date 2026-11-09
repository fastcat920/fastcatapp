import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/domain/models/notice.dart';
import 'package:fl_clash/xboard/features/notice/providers/notice_cache.dart';
import 'package:fl_clash/xboard/features/notice/providers/notice_popup_policy.dart';

void main() {
  final now = DateTime(2026, 11, 7);
  final notice =
      DomainNotice(id: 1, title: '公告', content: '内容', createdAt: now);
  test(
      'persisted content and freshness survive process restart, including empty results',
      () {
    for (final items in [
      <DomainNotice>[],
      [notice]
    ]) {
      final cached =
          NoticeCacheRecord.decode(NoticeCacheRecord(items, now).encode(), now);
      expect(cached.notices, items);
      expect(cached.savedAt, now);
    }
  });
  test('legacy lists restore content without assuming freshness', () {
    final cached = NoticeCacheRecord.decode(jsonEncode([notice.toJson()]), now);
    expect(cached.notices, [notice]);
    expect(cached.savedAt, isNull);
  });
  test(
      'future timestamps do not prevent refreshing; corrupt records fail closed',
      () {
    final future = NoticeCacheRecord.decode(
        NoticeCacheRecord([], now.add(const Duration(days: 1))).encode(), now);
    expect(future.savedAt, isNull);
    expect(() => NoticeCacheRecord.decode('{bad', now), throwsFormatException);
  });
  test(
      'cache identity is account/source/language based, opaque, and order independent',
      () {
    String scope(List<String> sources, String email, String locale) =>
        noticeCacheScope(sources: sources, email: email, locale: locale);
    final first = scope(['b', 'a'], 'User@example.com', 'zh-CN');
    expect(first, scope(['a', 'b'], 'user@example.com', 'zh-CN'));
    expect(first, isNot(contains('example.com')));
    expect(first, isNot(scope(['a', 'b'], 'other@example.com', 'zh-CN')));
    expect(first, isNot(scope(['c'], 'user@example.com', 'zh-CN')));
    expect(first, isNot(scope(['a', 'b'], 'user@example.com', 'en-US')));
  });
  test(
      'popup waits for a stable home and resets on navigation/background interruption',
      () {
    final policy = NoticePopupPolicy();
    expect(policy.canPresent(environmentReady: false, now: now), isFalse);
    expect(policy.canPresent(environmentReady: true, now: now), isFalse);
    expect(
        policy.canPresent(
            environmentReady: true,
            now: now.add(const Duration(milliseconds: 399))),
        isFalse);
    expect(
        policy.canPresent(
            environmentReady: false,
            now: now.add(const Duration(milliseconds: 400))),
        isFalse);
    expect(
        policy.canPresent(
            environmentReady: true, now: now.add(const Duration(seconds: 1))),
        isFalse);
    expect(
        policy.canPresent(
            environmentReady: true,
            now: now.add(const Duration(milliseconds: 1400))),
        isTrue);
  });
}
