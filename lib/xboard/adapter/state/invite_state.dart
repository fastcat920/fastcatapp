import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/session_epoch_provider.dart';

part 'generated/invite_state.g.dart';

/// 邀请状态管理

/// 获取邀请信息
@riverpod
Future<InviteInfoModel> getInviteInfo(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  const empty = InviteInfoModel(codes: [], stat: []);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return empty;
  final info = await sdk.invite.getInviteInfo();
  if (!active || ref.read(sessionEpochProvider) != epoch) return empty;
  return info;
}

/// 获取邀请码列表
@riverpod
Future<List<InviteCodeModel>> getInviteCodes(Ref ref) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  final codes = await sdk.invite.getInviteCodes();
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  return codes;
}

/// 获取佣金详情
@riverpod
Future<List<CommissionDetailModel>> getCommissionDetails(Ref ref,
    {int page = 1}) async {
  final epoch = ref.watch(sessionEpochProvider);
  var active = true;
  ref.onDispose(() => active = false);
  final sdk = await ref.watch(xboardSdkProvider.future);
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  final history = await sdk.invite.getCommissionDetails(page: page);
  if (!active || ref.read(sessionEpochProvider) != epoch) return [];
  return history;
}
