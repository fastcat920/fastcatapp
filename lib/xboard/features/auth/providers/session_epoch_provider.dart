import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invalidates account-bound work even when the shared SDK instance is reused.
/// Incremented at login/logout boundaries; contains no account or credential data.
final sessionEpochProvider = StateProvider<int>((ref) => 0);
