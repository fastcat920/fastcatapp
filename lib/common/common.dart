// Backward-compatible barrel: re-exports from focused sub-barrels.
// New code should prefer importing the specific sub-barrel (common_platform,
// common_network, common_ui, common_core) for better compile performance.
export 'common_core.dart';
export 'common_network.dart';
export 'common_platform.dart';
export 'common_ui.dart';
