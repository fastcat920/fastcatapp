import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/auth/models/auth_state.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/notice/providers/notice_provider.dart';
import 'package:fl_clash/xboard/adapter/state/notice_state.dart';
import 'package:fl_clash/xboard/features/connectivity/connectivity.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';

class _Auth extends XBoardUserAuthNotifier {
  @override
  UserAuthState build() => const UserAuthState(isAuthenticated: true);
  void restore(String email) => state = state.copyWith(email: email);
  void signOut() => state = const UserAuthState();
}

class _Connectivity extends StateNotifier<ServiceConnectivityState>
    implements ServiceConnectivityNotifier {
  _Connectivity() : super(const ServiceConnectivityState());
  @override
  void reportRequestSuccess({bool authoritative = true}) {}
  @override
  void reportRequestFailure(Object error) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _notice = NoticeModel(
    id: 1,
    title: 'Notice',
    content: 'Content',
    show: true,
    createdAt: 1,
    updatedAt: 1);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    globalState.config = Config(themeProps: defaultThemeProps);
  });
  Future<void> drain() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('late restored identity automatically starts notices on cold launch',
      () async {
    var calls = 0;
    final c = ProviderContainer(overrides: [
      xboardUserProvider.overrideWith(_Auth.new),
      serviceConnectivityProvider.overrideWith((ref) => _Connectivity()),
      getNoticesProvider.overrideWith((ref) async {
        calls++;
        return [_notice];
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(noticeProvider, (_, __) {});
    await c.read(noticeProvider.notifier).fetchNotices();
    expect(calls, 0);
    expect(c.read(noticeProvider).isWaiting, true);
    (c.read(xboardUserProvider.notifier) as _Auth).restore('user@example.test');
    await drain();
    expect(calls, 1);
    expect(c.read(noticeProvider).visibleNotices.single.id, 1);
    expect(c.read(noticeProvider).hasSnapshot, true);
    await c.read(noticeProvider.notifier).fetchNotices();
    expect(calls, 1);
  });
  test('logout clears content and late replies cannot repopulate it', () async {
    final reply = Completer<List<NoticeModel>>();
    final c = ProviderContainer(overrides: [
      xboardUserProvider.overrideWith(_Auth.new),
      serviceConnectivityProvider.overrideWith((ref) => _Connectivity()),
      getNoticesProvider.overrideWith((ref) => reply.future),
    ]);
    addTearDown(c.dispose);
    c.listen(noticeProvider, (_, __) {});
    final auth = c.read(xboardUserProvider.notifier) as _Auth;
    auth.restore('user@example.test');
    await drain();
    auth.signOut();
    reply.complete([_notice]);
    await drain();
    expect(c.read(noticeProvider).notices, isEmpty);
    expect(c.read(noticeProvider).hasSnapshot, false);
  });
  test(
      'failed refresh preserves cached content, real empty response replaces it',
      () async {
    var fail = false;
    var empty = false;
    final c = ProviderContainer(overrides: [
      xboardUserProvider.overrideWith(_Auth.new),
      serviceConnectivityProvider.overrideWith((ref) => _Connectivity()),
      getNoticesProvider.overrideWith((ref) async {
        if (fail) throw StateError('offline');
        return empty ? <NoticeModel>[] : [_notice];
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(noticeProvider, (_, __) {});
    (c.read(xboardUserProvider.notifier) as _Auth).restore('user@example.test');
    await drain();
    expect(c.read(noticeProvider).notices.single.id, 1);
    fail = true;
    await c.read(noticeProvider.notifier).fetchNotices(forceRefresh: true);
    expect(c.read(noticeProvider).notices.single.id, 1);
    expect(c.read(noticeProvider).isLoading, false);
    expect(c.read(noticeProvider).error, isNotNull);
    fail = false;
    empty = true;
    await c.read(noticeProvider.notifier).fetchNotices(forceRefresh: true);
    expect(c.read(noticeProvider).notices, isEmpty);
    expect(c.read(noticeProvider).hasSnapshot, true);
    expect(c.read(noticeProvider).isWaiting, false);
    expect(c.read(noticeProvider).error, isNull);
  });
  test('waiting, failed and confirmed empty results remain distinct', () {
    expect(const NoticeState().isWaiting, true);
    expect(const NoticeState(error: 'offline').isWaiting, false);
    expect(const NoticeState(hasSnapshot: true).isWaiting, false);
  });
}
