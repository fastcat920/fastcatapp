import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';

/// 优惠券输入区域
class CouponInputSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isValidating;
  final bool? isValid;
  final String? errorMessage;
  final double? discountAmount;
  final VoidCallback onValidate;
  final VoidCallback onChanged;

  const CouponInputSection({
    super.key,
    required this.controller,
    required this.isValidating,
    required this.onValidate,
    required this.onChanged,
    this.isValid,
    this.errorMessage,
    this.discountAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.local_offer, color: colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).xboardCouponOptional,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (isValid == true && discountAmount != null) ...[
                const SizedBox(width: 8),
                _DiscountBadge(discountAmount: discountAmount!),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _CouponTextField(
                controller: controller,
                isValid: isValid,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            _ValidateButton(
              isValidating: isValidating,
              onPressed: onValidate,
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          _ErrorMessage(message: errorMessage!),
        ],
      ],
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  final double discountAmount;

  const _DiscountBadge({required this.discountAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '-¥${discountAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool? isValid;
  final VoidCallback onChanged;

  const _CouponTextField({
    required this.controller,
    required this.onChanged,
    this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color:
            isDark ? colorScheme.surfaceContainerLow : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(colorScheme, isDark),
          width: 1.5,
        ),
      ),
      child: TVDeferredInput(
        borderRadius: BorderRadius.circular(12),
        builder: (context, focusNode, readOnly, showCursor, beginEditing) =>
            TextField(
          focusNode: focusNode,
          readOnly: readOnly,
          showCursor: showCursor,
          onTap: beginEditing,
          controller: controller,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: AppLocalizations.of(context).xboardEnterCouponCode,
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(
              Icons.confirmation_number_outlined,
              color: _getIconColor(colorScheme),
              size: 20,
            ),
            suffixIcon: isValid != null
                ? Icon(
                    isValid! ? Icons.check_circle : Icons.cancel,
                    color:
                        isValid! ? Colors.green.shade600 : Colors.red.shade600,
                    size: 20,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
      ),
    );
  }

  Color _getBorderColor(ColorScheme colorScheme, bool isDark) {
    if (isValid == false) return Colors.red.shade300;
    if (isValid == true) return Colors.green.shade400;
    return isDark
        ? colorScheme.outline.withValues(alpha: 0.28)
        : const Color(0xFFEEF0F4);
  }

  Color _getIconColor(ColorScheme colorScheme) {
    if (isValid == false) return Colors.red.shade400;
    if (isValid == true) return Colors.green.shade400;
    return colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
  }
}

class _ValidateButton extends StatelessWidget {
  final bool isValidating;
  final VoidCallback onPressed;

  const _ValidateButton({
    required this.isValidating,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: isValidating
            ? null
            : () {
                // 收起键盘
                FocusScope.of(context).unfocus();
                // 执行验证
                onPressed();
              },
        style: XbUiButton.filledPrimary(context).copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20),
          ),
        ),
        child: isValidating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                AppLocalizations.of(context).xboardVerify,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
