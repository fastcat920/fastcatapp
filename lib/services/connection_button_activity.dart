import 'core_switch_status.dart';

/// Configuration application holds the operation lock, but is not itself a
/// connect/disconnect operation. Real tunnel recovery remains visible.
bool showConnectionProgress({
  required bool ready,
  required bool checkingSubscription,
  required bool userSwitching,
  required bool coreSwitching,
  required bool configurationSwitching,
  required CoreSwitchStatus status,
}) =>
    !ready ||
    checkingSubscription ||
    userSwitching ||
    status.isBusy ||
    (coreSwitching && !configurationSwitching);
