import '../../api/interfaces/invite_api.dart';
import '../../api/models/invite_model.dart';
import '../../panels/v2board/apis/v2board_invite_api.dart';
import '../../panels/v2board/models/invite_info.dart' as v2b;
import '../../panels/xboard/models/xboard_invite_models.dart' show CommissionDetail;

class V2BoardInviteAdapter implements InviteApi {
  final V2BoardInviteApi _api;

  V2BoardInviteAdapter(this._api);

  @override
  Future<InviteInfoModel> getInviteInfo() async {
    final response = await _api.getInviteInfo();
    if (response.data == null) throw Exception('Invite info is null');
    return _mapInviteInfo(response.data!);
  }

  @override
  Future<List<InviteCodeModel>> getInviteCodes() async {
    final response = await _api.getInviteInfo();
    if (response.data == null) return [];
    return (response.data!.codes ?? []).map(_mapInviteCode).toList();
  }

  @override
  Future<String> generateInviteCode() async {
    final response = await _api.generateInviteCode();
    if (response.data == null) throw Exception('Generated invite code is null');
    return response.data!.code ?? '';
  }

  @override
  Future<List<CommissionDetailModel>> getCommissionDetails({int page = 1, int pageSize = 10}) async {
    final response = await _api.fetchCommissionDetails(current: page, pageSize: pageSize);
    if (response.data == null) return [];
    return response.data!.map(_mapCommissionDetail).toList();
  }

  @override
  Future<bool> withdrawCommission({required double amount, required String method, required Map<String, dynamic> params}) async {
    throw UnimplementedError('V2Board does not support commission withdrawal');
  }

  @override
  Future<bool> transferCommissionToBalance(double amount) async {
    throw UnimplementedError('V2Board does not support commission transfer');
  }

  InviteInfoModel _mapInviteInfo(v2b.InviteInfo info) {
    final stat = info.stat;
    // V2Board stat 是对象，映射到 InviteInfoModel 期望的 List<int>：
    // [totalInvites, totalCommission, pendingCommission, commissionRate, availableCommission]
    final statList = stat == null
        ? <int>[]
        : [
            stat.registerCount ?? 0,           // stat[0] totalInvites
            stat.commissionBalance ?? 0,        // stat[1] totalCommission
            stat.commissionPendingBalance ?? 0, // stat[2] pendingCommission
            stat.commissionRate ?? 0,           // stat[3] commissionRate
            stat.commissionBalance ?? 0,        // stat[4] availableCommission
          ];
    return InviteInfoModel(
      codes: (info.codes ?? []).map(_mapInviteCode).toList(),
      stat: statList,
    );
  }

  InviteCodeModel _mapInviteCode(v2b.InviteCode code) {
    return InviteCodeModel(
      userId: code.userId ?? 0,
      code: code.code ?? '',
      pv: 0, // V2Board 无 pv 字段
      status: (code.status ?? 0) != 0, // int → bool：0=未使用(false)，1=已使用(true)
      createdAt: DateTime.fromMillisecondsSinceEpoch((code.createdAt ?? 0) * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((code.updatedAt ?? 0) * 1000),
    );
  }

  CommissionDetailModel _mapCommissionDetail(CommissionDetail detail) {
    return CommissionDetailModel(
      id: detail.id,
      orderAmount: detail.orderAmount,
      tradeNo: detail.tradeNo,
      getAmount: detail.getAmount,
      commissionStatus: detail.commissionStatus,
      createdAt: detail.createdAt,
    );
  }
}
