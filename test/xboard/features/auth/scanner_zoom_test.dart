import 'dart:async';

import 'package:fl_clash/xboard/features/auth/services/scanner_zoom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'two fingers zoom smoothly, single finger and paused camera do not',
      (tester) async {
    final values = <double>[];
    final zoom = ScannerZoom(
        readZoom: () => 0.2,
        applyZoom: (value) async {
          values.add(value);
        });
    addTearDown(zoom.dispose);
    zoom.update(1, 2);
    zoom.update(2, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values, isEmpty);
    zoom.setActive(true);
    zoom.update(1, 1);
    zoom.update(2, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values, isEmpty);
    zoom.update(1, 2);
    zoom.update(2, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.single, greaterThan(0.2));
    final enlarged = values.last;
    zoom.endGesture();
    zoom.update(1, 2);
    zoom.update(0.5, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.last, closeTo(0.2, 0.0001));
    expect(values.last, lessThan(enlarged));
  });

  testWidgets('limits zoom and resets the baseline when pointer count changes',
      (tester) async {
    final values = <double>[];
    final zoom = ScannerZoom(
        readZoom: () => 0.4,
        applyZoom: (value) async {
          values.add(value);
        });
    addTearDown(zoom.dispose);
    zoom.setActive(true);
    zoom.update(1, 2);
    zoom.update(100, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.last, 1);
    zoom.update(0.1, 1);
    zoom.update(0.1, 2); // New baseline, no jump.
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.length, 1);
    zoom.update(0.00001, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.last, 0);
    zoom.update(double.nan, 2);
    zoom.update(double.infinity, 2);
    zoom.update(0, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.length, 2);
  });

  testWidgets('coalesces updates and never overlaps native calls',
      (tester) async {
    final values = <double>[];
    final pending = Completer<void>();
    final zoom = ScannerZoom(
        readZoom: () => 0,
        applyZoom: (value) {
          values.add(value);
          return values.length == 1 ? pending.future : Future.value();
        });
    addTearDown(zoom.dispose);
    zoom.setActive(true);
    zoom.update(1, 2);
    zoom.update(1.2, 2);
    zoom.update(1.5, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.length, 1);
    zoom.update(2, 2);
    zoom.update(3, 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(values.length, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.length, 2);
    expect(values.last, greaterThan(values.first));
  });

  testWidgets('pause cancels pending writes and restart restores page zoom',
      (tester) async {
    final values = <double>[];
    final zoom = ScannerZoom(
        readZoom: () => 0,
        applyZoom: (value) async {
          values.add(value);
        });
    addTearDown(zoom.dispose);
    zoom.setActive(true);
    zoom.update(1, 2);
    zoom.update(2, 2);
    await zoom.pause();
    await tester.pump(const Duration(milliseconds: 100));
    expect(values, isEmpty);
    zoom.setActive(true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(values.single, greaterThan(0));
    zoom.dispose();
    zoom.setActive(true);
    zoom.update(1, 2);
    zoom.update(4, 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(values.length, 1);
  });

  testWidgets(
      'unsupported zoom is harmless and a lost reply cannot block pause',
      (tester) async {
    final blocked = Completer<void>();
    var calls = 0;
    final zoom = ScannerZoom(
        readZoom: () => 0,
        applyZoom: (_) {
          calls++;
          if (calls == 1) throw StateError('unsupported');
          return blocked.future;
        });
    addTearDown(zoom.dispose);
    zoom.setActive(true);
    zoom.update(1, 2);
    zoom.update(2, 2);
    await tester.pump(const Duration(milliseconds: 50));
    zoom.update(3, 2);
    await tester.pump(const Duration(milliseconds: 50));
    var paused = false;
    unawaited(zoom.pause().then((_) => paused = true));
    await tester.pump(const Duration(seconds: 2));
    expect(paused, isTrue);
    blocked.complete();
    await tester.pump();
    expect(calls, 2);
  });
}
