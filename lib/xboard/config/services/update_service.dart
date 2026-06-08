import '../models/update_info.dart';

/// 更新配置服务（简化版）
///
/// 直接持有 UpdateRichConfig，供 XBoardConfigAccessor 使用。
class UpdateConfigService {
  final UpdateRichConfig? config;

  UpdateConfigService(this.config);

  /// 是否有更新配置
  bool get hasConfig => config != null && config!.isNotEmpty;
}
