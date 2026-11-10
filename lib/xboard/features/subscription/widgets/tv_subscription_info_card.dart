import 'package:fl_clash/models/models.dart' as models;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subscription_usage_card.dart';

/// The same read-only plan summary on the TV home and account screens.
class TVSubscriptionInfoCard extends ConsumerWidget {
  const TVSubscriptionInfoCard({super.key, this.isSyncing = false});
  final bool isSyncing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionInfoProvider);
    var profile = ref.watch(currentProfileProvider)?.subscriptionInfo;
    if (profile == null && subscription != null && subscription.planId > 0) {
      profile = models.SubscriptionInfo(
          upload: subscription.uploadedBytes,
          download: subscription.downloadedBytes,
          total: subscription.transferLimit,
          expire: subscription.expiredAt == null
              ? 0
              : subscription.expiredAt!.millisecondsSinceEpoch ~/ 1000);
    }
    return SubscriptionUsageCard(
        subscriptionInfo: subscription,
        userInfo: ref.watch(userInfoProvider),
        profileSubscriptionInfo: profile,
        showActions: false,
        usePlainBackground: true,
        prefixUsedTraffic: true,
        fixedHeight: 148,
        isSyncing: isSyncing);
  }
}
