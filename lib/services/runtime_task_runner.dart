import 'dart:async';

/// A stopped generation cannot schedule work into a later connection.
class RuntimeTaskRunner {
  RuntimeTaskRunner(
      {this.interval = const Duration(seconds: 1), required this.onError});
  final Duration interval;
  final void Function(Object) onError;
  Timer? _timer;
  int _generation = 0;
  bool _running = false;

  void start(List<FutureOr<void> Function()> tasks) {
    if (_running) return;
    _running = true;
    unawaited(_tick(++_generation, List.of(tasks)));
  }

  void stop() {
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick(
      int generation, List<FutureOr<void> Function()> tasks) async {
    try {
      for (final task in tasks) {
        if (!_running || generation != _generation) return;
        await task();
      }
    } catch (error) {
      onError(error);
    }
    if (_running && generation == _generation) {
      _timer = Timer(interval, () => unawaited(_tick(generation, tasks)));
    }
  }
}
