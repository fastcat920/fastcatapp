import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 远程配置中的节点延迟显示折扣。
///
/// 配置刷新后会自动发出新值；配置模块尚未初始化时安全回退到 0。
final delayDiscountPercentProvider = StreamProvider<int>((ref) async* {
  while (!XBoardConfig.isInitialized) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  yield XBoardConfig.delayDiscountPercent;
  await for (final _ in XBoardConfig.configChangeStream) {
    yield XBoardConfig.delayDiscountPercent;
  }
});

/// 只换算正数延迟；null、加载中(0)和超时(-1)保持原值。
int? applyDelayDisplayDiscount(int? delay, int discountPercent) {
  if (delay == null || delay <= 0) return delay;
  final discount = discountPercent.clamp(0, 90).toInt();
  if (discount == 0) return delay;
  final discounted = delay * (100 - discount) ~/ 100;
  return discounted < 1 ? 1 : discounted;
}
