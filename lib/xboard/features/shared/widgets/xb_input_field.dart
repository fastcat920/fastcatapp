import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/auth/widgets/auth_tv_layout.dart';
import 'package:flutter/material.dart';
import 'tv_deferred_input.dart';

class XBInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final void Function(String)? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  const XBInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.focusNode,
    this.onKeyEvent,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTv = system.isTV;
    final radius = BorderRadius.circular(
      isTv ? AuthTvLayout.controlRadius : 14,
    );
    return TVDeferredInput(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      builder: (context, focusNode, readOnly, showCursor, beginEditing) {
        return TextFormField(
          focusNode: focusNode,
          readOnly: readOnly,
          showCursor: showCursor,
          onTap: beginEditing,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          autovalidateMode: autovalidateMode,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          style: (isTv
                  ? Theme.of(context).textTheme.bodyMedium
                  : Theme.of(context).textTheme.bodyLarge)
              ?.copyWith(
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: isTv,
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: isTv ? 20 : null,
                    color: colorScheme.onSurfaceVariant,
                  )
                : null,
            prefixIconConstraints:
                isTv ? const BoxConstraints(minWidth: 40, minHeight: 40) : null,
            suffixIconConstraints:
                isTv ? const BoxConstraints(minWidth: 40, minHeight: 40) : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: isDark ? colorScheme.outline : const Color(0xFFEEF0F4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: isDark ? colorScheme.outline : const Color(0xFFEEF0F4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: colorScheme.error,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: colorScheme.error,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerLow
                : const Color(0xFFF5F7FA),
            labelStyle: (isTv
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodyLarge)
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            hintStyle: (isTv
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodyLarge)
                ?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            contentPadding: isTv
                ? AuthTvLayout.fieldContentPadding
                : const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        );
      },
    );
  }
}
