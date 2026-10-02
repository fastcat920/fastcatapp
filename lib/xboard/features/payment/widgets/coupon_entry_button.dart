import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:go_router/go_router.dart';

final couponWalletProvider = FutureProvider<List<CatboardCoupon>>((ref) async {
  final auth = ref.watch(xboardUserAuthProvider);
  if (!auth.isAuthenticated) return const [];
  final sdk = await ref.watch(xboardSdkProvider.future);
  return sdk.catboard.getCouponWallet();
});

class CouponEntryButton extends ConsumerStatefulWidget {
  final bool showOnlyWhenAvailable;
  final double endSpacing;

  const CouponEntryButton({
    super.key,
    this.showOnlyWhenAvailable = false,
    this.endSpacing = 0,
  });

  @override
  ConsumerState<CouponEntryButton> createState() => _CouponEntryButtonState();
}

class _CouponEntryButtonState extends ConsumerState<CouponEntryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAngle;
  bool _shakeEnabled = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _shakeAngle = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.12), weight: 7),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.10), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 0.10, end: -0.08), weight: 7),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 7),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0), weight: 7),
      TweenSequenceItem(tween: ConstantTween(0), weight: 13),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _syncShake(bool enabled) {
    if (_shakeEnabled == enabled) return;
    _shakeEnabled = enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shakeEnabled != enabled) return;
      if (enabled) {
        _shakeController.repeat();
      } else {
        _shakeController
          ..stop()
          ..value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final coupons = ref.watch(couponWalletProvider).valueOrNull ?? const [];
    final availableCount =
        coupons.where((coupon) => coupon.status == 'available').length;
    final hasAvailable = availableCount > 0;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    _syncShake(hasAvailable && !disableAnimations);

    if (widget.showOnlyWhenAvailable && !hasAvailable) {
      return const SizedBox.shrink();
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final tooltip = languageCode == 'zh'
        ? (hasAvailable ? '优惠券（$availableCount 张可用）' : '优惠券')
        : (hasAvailable ? 'Coupons ($availableCount available)' : 'Coupons');

    final button = Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () async {
          await context.push('/plans/coupons');
          ref.invalidate(couponWalletProvider);
        },
        icon: AnimatedBuilder(
          animation: _shakeAngle,
          builder: (context, child) => Transform.rotate(
            angle: hasAvailable && !disableAnimations ? _shakeAngle.value : 0,
            child: child,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (hasAvailable)
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF6B6B),
                      Color(0xFFFFB020),
                      Color(0xFF6C63FF),
                    ],
                  ).createShader(bounds),
                  child: const Icon(Icons.confirmation_number_rounded),
                )
              else
                Icon(
                  Icons.confirmation_number_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              if (hasAvailable)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      availableCount > 9 ? '9+' : '$availableCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (widget.endSpacing <= 0) return button;
    return Padding(
      padding: EdgeInsets.only(right: widget.endSpacing),
      child: button,
    );
  }
}
