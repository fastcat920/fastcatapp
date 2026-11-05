import 'package:fl_clash/xboard/features/notice/providers/notice_provider.dart';
import 'package:fl_clash/xboard/core/content_locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an acknowledged popup can be cleared without losing other state', () {
    const state = NoticeState(popupNoticeId: 7);
    expect(state.copyWith(isLoading: true).popupNoticeId, 7);
    expect(state.copyWith(popupNoticeId: null).popupNoticeId, isNull);
  });
  test('panel locale uses the same fallback as the application', () {
    expect(xboardContentLocale('zh-Hant'), 'zh-CN');
    expect(xboardContentLocale('en_GB'), 'en-US');
    expect(xboardContentLocale('ja_JP'), 'en-US');
  });
}
