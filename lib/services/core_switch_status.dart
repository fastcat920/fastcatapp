enum CoreSwitchStage {
  idle,
  checkingHelper,
  startingService,
  helperReady,
  coreConnecting,
  tunApplying,
  connected,
  stopping,
  failed,
}

class CoreSwitchStatus {
  const CoreSwitchStatus({
    required this.stage,
    this.message,
  });

  final CoreSwitchStage stage;
  final String? message;

  bool get isBusy =>
      stage != CoreSwitchStage.idle &&
      stage != CoreSwitchStage.connected &&
      stage != CoreSwitchStage.failed;

  String get label {
    if (message?.trim().isNotEmpty == true) {
      return message!.trim();
    }
    return switch (stage) {
      CoreSwitchStage.idle => '',
      CoreSwitchStage.checkingHelper => '检查 helper',
      CoreSwitchStage.startingService => '启动服务',
      CoreSwitchStage.helperReady => 'helper 已复用',
      CoreSwitchStage.coreConnecting => '核心回连',
      CoreSwitchStage.tunApplying => '应用 TUN',
      CoreSwitchStage.connected => '已连接',
      CoreSwitchStage.stopping => '正在断开',
      CoreSwitchStage.failed => '连接失败',
    };
  }

  static const idle = CoreSwitchStatus(stage: CoreSwitchStage.idle);
}
