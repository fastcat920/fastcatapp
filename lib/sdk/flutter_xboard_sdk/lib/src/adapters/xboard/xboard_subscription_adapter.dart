import '../../api/interfaces/subscription_api.dart';
import '../../api/models/subscription_model.dart';
import '../../panels/xboard/apis/xboard_subscription_api.dart';
import '../../panels/xboard/models/xboard_subscription_models.dart';

class XBoardSubscriptionAdapter implements SubscriptionApi {
  final XBoardSubscriptionApi _api;

  XBoardSubscriptionAdapter(this._api);

  @override
  Future<SubscriptionModel> getSubscription() async {
    final info = await _api.getSubscriptionInfo();
    return _mapSubscription(info);
  }

  @override
  Future<String> getSubscribeUrl() async {
    final info = await _api.getSubscriptionInfo();
    return info.subscribeUrl ?? '';
  }

  SubscriptionModel _mapSubscription(SubscriptionInfo info) {
    return SubscriptionModel(
      subscribeUrl: info.subscribeUrl,
      plan: info.plan != null ? _mapPlan(info.plan!) : null,
      token: info.token,
      expiredAt: info.expiredAt,
      u: info.u,
      d: info.d,
      transferEnable: info.transferEnable,
      planId: info.planId,
      email: info.email,
      uuid: info.uuid,
      deviceLimit: info.deviceLimit,
      speedLimit: info.speedLimit,
      nextResetAt: info.nextResetAt,
      resetDay: info.resetDay,
    );
  }

  SubscriptionPlanModel _mapPlan(PlanDetails plan) {
    return SubscriptionPlanModel(
      name: plan.name,
      id: plan.id,
      groupId: plan.groupId,
      price: plan.price,
      description: plan.description,
      content: plan.content,
      tags: plan.tags,
      transferEnable: plan.transferEnable,
      speedLimit: plan.speedLimit,
      deviceLimit: plan.deviceLimit,
      show: plan.show,
      sell: plan.sell,
      renew: plan.renew,
      sort: plan.sort,
      onetimePrice: plan.onetimePrice,
      monthPrice: plan.monthPrice,
      quarterPrice: plan.quarterPrice,
      halfYearPrice: plan.halfYearPrice,
      yearPrice: plan.yearPrice,
      twoYearPrice: plan.twoYearPrice,
      threeYearPrice: plan.threeYearPrice,
      resetPrice: plan.resetPrice,
      resetTrafficMethod: plan.resetTrafficMethod,
    );
  }
}
