import 'dart:async';

import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final initialTime = DateTime.utc(2026, 1, 1);
  const authorized =
      QrLoginResult(token: 'test-only-token', email: 'test@invalid');
  const delivered = QrLoginResult(
    token: 'test-only-token',
    email: 'test@invalid',
    deliveryId: 'test-only-delivery',
  );

  QrLoginChallenge challenge(String id,
          {DateTime? expiresAt, bool deliveryAck = false}) =>
      QrLoginChallenge(
        id: id,
        pollToken: 'test-only-poll-token',
        qrData: 'fastcat://login/qr?challenge=$id',
        expiresAt: expiresAt ?? initialTime.add(const Duration(minutes: 2)),
        deliveryAck: deliveryAck,
      );

  test('poll is single-flight and credentials are delivered only once',
      () async {
    final response = Completer<QrLoginResult?>();
    var polls = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first'),
      poll: (_) {
        polls++;
        return response.future;
      },
    );
    addTearDown(flow.dispose);
    await flow.create();
    final first = flow.poll();
    expect(await flow.poll(), isNull);
    expect(polls, 1);
    response.complete(authorized);
    expect(await first, authorized);
    expect(await flow.poll(), isNull);
    expect(polls, 1);
  });

  test(
      'refresh invalidates a previous approved poll before cancellation finishes',
      () async {
    final oldReply = Completer<QrLoginResult?>();
    final cancellation = Completer<void>();
    var created = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('qr${++created}'),
      cancel: (_) => cancellation.future,
      poll: (value) =>
          value.id == 'qr1' ? oldReply.future : Future.value(authorized),
    );
    addTearDown(flow.dispose);
    await flow.create();
    final pending = flow.poll();
    final refresh = flow.create(invalidateCurrent: true);
    expect(flow.challenge, isNull);
    oldReply.complete(authorized);
    expect(await pending, isNull);
    cancellation.complete();
    expect((await refresh)!.id, 'qr2');
    expect(await flow.poll(), authorized);
  });

  test('late old expired error cannot expire the refreshed challenge',
      () async {
    final oldReply = Completer<QrLoginResult?>();
    var created = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('qr${++created}'),
      cancel: (_) async {},
      poll: (value) =>
          value.id == 'qr1' ? oldReply.future : Future.value(authorized),
    );
    addTearDown(flow.dispose);
    await flow.create();
    final first = flow.poll();
    await flow.create(invalidateCurrent: true);
    oldReply.completeError(const QrLoginExpiredException());
    expect(await first, isNull);
    expect(flow.challenge!.id, 'qr2');
    expect(await flow.poll(), authorized);
  });

  test('expired QR refresh skips cancellation and rejects its late approval',
      () async {
    var now = initialTime;
    var created = 0;
    var cancellations = 0;
    final oldReply = Completer<QrLoginResult?>();
    final flow = QrLoginAttemptController(
      now: () => now,
      create: () async => challenge('qr${++created}',
          expiresAt: now.add(const Duration(seconds: 1))),
      cancel: (_) async => cancellations++,
      poll: (_) => oldReply.future,
    );
    addTearDown(flow.dispose);
    await flow.create();
    final first = flow.poll();
    now = now.add(const Duration(seconds: 2));
    final next = await flow.create(invalidateCurrent: true);
    oldReply.complete(authorized);
    expect(await first, isNull);
    expect(next!.id, 'qr2');
    expect(cancellations, 0);
  });

  test('approval arriving after its expiration cannot authorize login',
      () async {
    var now = initialTime;
    final response = Completer<QrLoginResult?>();
    final flow = QrLoginAttemptController(
      now: () => now,
      create: () async => challenge('first'),
      poll: (_) => response.future,
    );
    addTearDown(flow.dispose);
    await flow.create();
    final first = flow.poll();
    now = now.add(const Duration(minutes: 3));
    response.complete(authorized);
    await expectLater(first, throwsA(isA<QrLoginExpiredException>()));
  });

  test('hiding or disposing QR login makes pending approvals inert', () async {
    for (final dispose in [false, true]) {
      final response = Completer<QrLoginResult?>();
      final flow = QrLoginAttemptController(
        now: () => initialTime,
        create: () async => challenge('first'),
        poll: (_) => response.future,
      );
      await flow.create();
      final first = flow.poll();
      if (dispose) {
        flow.dispose();
      } else {
        flow.setEnabled(false);
        flow.setEnabled(true);
      }
      response.complete(authorized);
      expect(await first, isNull);
      expect(flow.challenge, isNull);
      flow.dispose();
    }
  });

  test('old create finishing after a new visible attempt cannot replace it',
      () async {
    final oldCreate = Completer<QrLoginChallenge>();
    var created = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () =>
          ++created == 1 ? oldCreate.future : Future.value(challenge('second')),
    );
    addTearDown(flow.dispose);
    final first = flow.create();
    flow.setEnabled(false);
    flow.setEnabled(true);
    expect((await flow.create())!.id, 'second');
    oldCreate.complete(challenge('first'));
    expect(await first, isNull);
    expect(flow.challenge!.id, 'second');
  });

  test('create coalesces while pending and retries after synchronous failure',
      () async {
    final response = Completer<QrLoginChallenge>();
    var count = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () {
        count++;
        if (count == 1) throw StateError('temporary failure');
        return response.future;
      },
    );
    addTearDown(flow.dispose);
    await expectLater(flow.create(), throwsStateError);
    final first = flow.create();
    final second = flow.create();
    expect(identical(first, second), isTrue);
    response.complete(challenge('replacement'));
    expect((await first)!.id, 'replacement');
    expect(count, 2);
  });

  test('failed or hung cancellation cannot block a fresh QR indefinitely',
      () async {
    for (final hangs in [false, true]) {
      final pending = Completer<void>();
      var count = 0;
      final flow = QrLoginAttemptController(
        now: () => initialTime,
        create: () async => challenge('qr${++count}'),
        cancel: (_) {
          if (hangs) return pending.future;
          throw StateError('old QR already consumed');
        },
        cancelTimeout: const Duration(milliseconds: 10),
      );
      await flow.create();
      expect((await flow.create(invalidateCurrent: true))!.id, 'qr2');
      pending.complete();
      flow.dispose();
    }
  });

  test('network poll failures release single-flight for the next retry',
      () async {
    var polls = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first'),
      poll: (_) async {
        if (++polls == 1) throw StateError('offline');
        return authorized;
      },
    );
    addTearDown(flow.dispose);
    await flow.create();
    await expectLater(flow.poll(), throwsStateError);
    expect(await flow.poll(), authorized);
  });

  test('poll deadline is bounded and the late response is not accepted',
      () async {
    final pending = Completer<QrLoginResult?>();
    var polls = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first'),
      poll: (_) => ++polls == 1 ? pending.future : Future.value(authorized),
      requestTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(flow.dispose);
    await flow.create();
    await expectLater(flow.poll(), throwsA(isA<TimeoutException>()));
    expect(await flow.poll(), authorized);
    pending.complete(authorized);
    expect(await flow.poll(), isNull);
  });

  test('malformed challenge cannot invent an expiry or show a different QR',
      () {
    final data = {
      'id': 'qrl_test',
      'poll_token': 'qpt_test',
      'qr_data': 'fastcat://login/qr?challenge=qrl_test',
      'expires_at': '2026-01-01T00:02:00Z',
    };
    expect(QrLoginService.decodeChallenge({'data': data}).id, 'qrl_test');
    for (final patch in [
      {'expires_at': 'bad'},
      {'poll_token': ''},
      {'id': '../../invalid'},
      {'qr_data': 'https://test.invalid/'},
      {'qr_data': 'fastcat://login/qr?challenge=different'},
    ]) {
      expect(
          () => QrLoginService.decodeChallenge({
                'data': {...data, ...patch}
              }),
          throwsFormatException);
    }
  });

  test('all terminal poll states offer refresh instead of polling forever', () {
    for (final status in ['expired', 'consumed', 'cancelled', 'failed']) {
      expect(
          () => QrLoginService.decodePoll({
                'data': {'status': status}
              }),
          throwsA(isA<QrLoginExpiredException>()));
    }
    for (final status in ['pending', 'authorizing']) {
      expect(
          QrLoginService.decodePoll({
            'data': {'status': status}
          }),
          isNull);
    }
    expect(
      QrLoginService.decodePoll({
        'data': {
          'status': 'approved',
          'login': {'auth_data': 'test-token', 'email': 'test@invalid'},
        }
      })!
          .token,
      'test-token',
    );
  });

  test('delivery acknowledgement requires an explicit gateway opt-in', () {
    final data = {
      'id': 'qrl_test',
      'poll_token': 'qpt_test',
      'qr_data': 'fastcat://login/qr?challenge=qrl_test',
      'expires_at': '2026-01-01T00:02:00Z',
    };
    for (final value in [null, false, 'true', 1]) {
      expect(
        QrLoginService.decodeChallenge({
          'data': {...data, if (value != null) 'delivery_ack': value}
        }).deliveryAck,
        isFalse,
      );
    }
    expect(
      QrLoginService.decodeChallenge({
        'data': {...data, 'delivery_ack': true}
      }).deliveryAck,
      isTrue,
    );
  });

  test('new approved deliveries require an ID; old gateways remain compatible',
      () {
    final data = {
      'status': 'approved',
      'login': {'auth_data': 'test-token', 'email': 'test@invalid'},
    };
    expect(QrLoginService.decodePoll({'data': data})!.deliveryId, isNull);
    for (final value in [null, '', ' ', 1]) {
      expect(
        () => QrLoginService.decodePoll({
          'data': {...data, if (value != null) 'delivery_id': value}
        }, deliveryAck: true),
        throwsFormatException,
      );
    }
    expect(
      QrLoginService.decodePoll({
        'data': {...data, 'delivery_id': 'test-only-delivery'}
      }, deliveryAck: true)!
          .deliveryId,
      'test-only-delivery',
    );
  });

  test('acknowledges only after successful authorization, exactly once',
      () async {
    final login = Completer<bool>();
    final ack = Completer<void>();
    var authorizations = 0;
    var acknowledgements = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first', deliveryAck: true),
      poll: (_) async => delivered,
      acknowledge: (qr, result) async {
        acknowledgements++;
        expect(qr.id, 'first');
        expect(result.deliveryId, 'test-only-delivery');
        ack.complete();
      },
    );
    addTearDown(flow.dispose);
    await flow.create();
    final result = (await flow.poll())!;
    expect(acknowledgements, 0);
    Future<bool> authorize(QrLoginResult _) {
      authorizations++;
      return login.future;
    }

    final pending = flow.authorize(result, authorize);
    expect(acknowledgements, 0);
    expect(await flow.authorize(result, authorize), isFalse);
    expect(authorizations, 1);
    login.complete(true);
    expect(await pending, isTrue);
    await ack.future;
    expect(acknowledgements, 1);
    expect(await flow.poll(), isNull);
  });

  test('failed authorization never acknowledges delivery', () async {
    for (final throws in [false, true]) {
      var acknowledgements = 0;
      final flow = QrLoginAttemptController(
        now: () => initialTime,
        create: () async => challenge('first', deliveryAck: true),
        poll: (_) async => delivered,
        acknowledge: (_, __) async => acknowledgements++,
      );
      await flow.create();
      final result = (await flow.poll())!;
      final login = flow.authorize(result, (_) async {
        if (throws) throw StateError('test authorization failed');
        return false;
      });
      if (throws) {
        await expectLater(login, throwsStateError);
      } else {
        expect(await login, isFalse);
      }
      expect(acknowledgements, 0);
      flow.dispose();
    }
  });

  test('successful login to a legacy gateway never sends ACK', () async {
    var acknowledgements = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('legacy'),
      poll: (_) async => authorized,
      acknowledge: (_, __) async => acknowledgements++,
    );
    addTearDown(flow.dispose);
    await flow.create();
    final result = (await flow.poll())!;
    expect(await flow.authorize(result, (_) async => true), isTrue);
    expect(acknowledgements, 0);
  });

  test('successful login still ACKs its receipt after navigation disposes view',
      () async {
    final login = Completer<bool>();
    final ack = Completer<QrLoginChallenge>();
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first', deliveryAck: true),
      poll: (_) async => delivered,
      acknowledge: (qr, _) async => ack.complete(qr),
    );
    final original = await flow.create();
    final result = (await flow.poll())!;
    final pending = flow.authorize(result, (_) => login.future);
    flow.setEnabled(false);
    flow.dispose();
    login.complete(true);
    expect(await pending, isTrue);
    expect(await ack.future, same(original));
  });

  test('completion of old authorization can never acknowledge replacement QR',
      () async {
    final login = Completer<bool>();
    final ack = Completer<QrLoginChallenge>();
    var created = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('qr${++created}', deliveryAck: true),
      poll: (_) async => delivered,
      acknowledge: (qr, _) async => ack.complete(qr),
    );
    addTearDown(flow.dispose);
    final original = await flow.create();
    final result = (await flow.poll())!;
    final pending = flow.authorize(result, (_) => login.future);
    await flow.create();
    expect(flow.challenge!.id, 'qr2');
    login.complete(true);
    expect(await pending, isTrue);
    expect(await ack.future, same(original));
    expect(flow.challenge!.id, 'qr2');
  });

  test('a stale result cannot start authorization after refresh or hide',
      () async {
    for (final refresh in [false, true]) {
      var calls = 0;
      final flow = QrLoginAttemptController(
        now: () => initialTime,
        create: () async => challenge('first', deliveryAck: true),
        poll: (_) async => delivered,
        acknowledge: (_, __) async => calls++,
      );
      await flow.create();
      final result = (await flow.poll())!;
      if (refresh) {
        await flow.create();
      } else {
        flow.setEnabled(false);
      }
      expect(
        await flow.authorize(result, (_) async {
          calls++;
          return true;
        }),
        isFalse,
      );
      expect(calls, 0);
      flow.dispose();
    }
  });

  test('a failed ACK is retried once with the same immutable receipt',
      () async {
    final retried = Completer<void>();
    var acknowledgements = 0;
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first', deliveryAck: true),
      poll: (_) async => delivered,
      acknowledge: (qr, result) async {
        expect(qr.id, 'first');
        expect(result, same(delivered));
        if (++acknowledgements == 1) throw StateError('response lost');
        retried.complete();
      },
    );
    addTearDown(flow.dispose);
    await flow.create();
    final result = (await flow.poll())!;
    expect(await flow.authorize(result, (_) async => true), isTrue);
    await retried.future;
    expect(acknowledgements, 2);
  });

  test('lost ACKs cannot block login and retry work has a bounded deadline',
      () async {
    final unfinished = <Completer<void>>[];
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first', deliveryAck: true),
      poll: (_) async => delivered,
      acknowledgementTimeout: const Duration(milliseconds: 30),
      acknowledge: (_, __) {
        final request = Completer<void>();
        unfinished.add(request);
        return request.future;
      },
    );
    addTearDown(flow.dispose);
    await flow.create();
    final result = (await flow.poll())!;
    expect(await flow.authorize(result, (_) async => true), isTrue);
    expect(unfinished, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(unfinished, hasLength(2));
    // Late errors from the underlying transport remain handled after timeout.
    for (final request in unfinished) {
      request.completeError(StateError('late network failure'));
    }
    await Future<void>.delayed(Duration.zero);
    expect(await flow.poll(), isNull);
  });

  test('a lost approved poll can recover and authorize its delivery once',
      () async {
    var polls = 0;
    var authorizations = 0;
    var acknowledgements = 0;
    final ack = Completer<void>();
    final flow = QrLoginAttemptController(
      now: () => initialTime,
      create: () async => challenge('first', deliveryAck: true),
      poll: (_) async {
        if (++polls == 1) throw TimeoutException('response lost');
        return delivered;
      },
      acknowledge: (_, __) async {
        acknowledgements++;
        ack.complete();
      },
    );
    addTearDown(flow.dispose);
    await flow.create();
    await expectLater(flow.poll(), throwsA(isA<TimeoutException>()));
    final result = (await flow.poll())!;
    expect(
      await flow.authorize(result, (_) async {
        authorizations++;
        return true;
      }),
      isTrue,
    );
    await ack.future;
    expect(await flow.poll(), isNull);
    expect(authorizations, 1);
    expect(acknowledgements, 1);
  });
}
