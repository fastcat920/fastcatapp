import '../domain/core_models.dart';

abstract interface class CoreGateway {
  bool get isRunning;

  MihomoRuntimeStatus get runtimeStatus;

  List<MihomoGroup> getGroups();

  String? getCurrentGroupName();

  Future<bool> setRunning(bool value);

  Future<void> selectNode({
    required String groupName,
    required String nodeName,
  });

  Future<void> refreshGroups();

  Future<void> applyCurrentProfile();

  int? getNodeDelay(String nodeName, {String? testUrl});
}
