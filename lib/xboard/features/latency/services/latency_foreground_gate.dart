/// Guards asynchronous readiness checks across background/resume cycles.
class LatencyForegroundGate {
  LatencyForegroundGate({required bool foreground})
      : _foreground = foreground,
        _ready = foreground;
  bool _foreground;
  bool _ready;
  int _generation = 0;
  bool get allowsTesting => _foreground && _ready;

  void pause() {
    _generation++;
    _foreground = false;
    _ready = false;
  }

  Future<bool> resume(Future<bool> Function() checkReady) async {
    final generation = ++_generation;
    _foreground = true;
    _ready = false;
    bool ready;
    try {
      ready = await checkReady();
    } catch (_) {
      ready = false;
    }
    if (generation != _generation || !_foreground) return false;
    _ready = ready;
    return ready;
  }
}
