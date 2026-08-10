import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/providers/providers.dart';

import '../application/core_gateway.dart';
import '../domain/core_models.dart';
import '../infrastructure/legacy_core_gateway.dart';

final coreGatewayProvider = Provider<CoreGateway>(
  (ref) => const LegacyCoreGateway(),
);

final mihomoGroupsProvider = Provider<List<MihomoGroup>>((ref) {
  ref.watch(groupsProvider);
  ref.watch(delayDataSourceProvider);
  ref.watch(selectedMapProvider);
  return ref.watch(coreGatewayProvider).getGroups();
});
