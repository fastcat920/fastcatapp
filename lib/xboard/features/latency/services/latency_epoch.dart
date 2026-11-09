/// Results from a previous core/connection must never update the current RTT.
class LatencyEpoch {
  int _value = 0;
  int capture() => _value;
  void invalidate() => _value++;
  bool accepts(int value) => value == _value;
}
