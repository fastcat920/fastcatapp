import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/features/latency/services/latency_foreground_gate.dart';

void main() {
  test('background stays blocked until readiness is acknowledged', () async {
    final gate = LatencyForegroundGate(foreground: true);
    gate.pause();
    expect(gate.allowsTesting, false);
    final ready = Completer<bool>();
    final resumed = gate.resume(() => ready.future);
    expect(gate.allowsTesting, false);
    ready.complete(true);
    expect(await resumed, true);
    expect(gate.allowsTesting, true);
  });
  test('backgrounding invalidates an in-flight readiness response', () async {
    final gate = LatencyForegroundGate(foreground: false);
    final ready = Completer<bool>();
    final resumed = gate.resume(() => ready.future);
    gate.pause();
    ready.complete(true);
    expect(await resumed, false);
    expect(gate.allowsTesting, false);
  });
  test('an old resume cannot overwrite a newer failed check', () async {
    final gate = LatencyForegroundGate(foreground: false);
    final stale = Completer<bool>();
    final old = gate.resume(() => stale.future);
    gate.pause();
    expect(await gate.resume(() async => false), false);
    stale.complete(true);
    expect(await old, false);
    expect(gate.allowsTesting, false);
    expect(await gate.resume(() async => true), true);
  });
  test('readiness exceptions never enable testing', () async {
    final gate = LatencyForegroundGate(foreground: false);
    expect(await gate.resume(() async => throw StateError('IPC unavailable')),
        false);
    expect(gate.allowsTesting, false);
  });
}
