import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/chat_provider.dart';
import '../../i18n/tgo_localizations.dart';
import '../theme/tgo_theme.dart';
import 'emoji_picker.dart';
import 'file_picker_widget.dart';
import 'chat_overlay_host.dart';

/// Input panel state
enum InputPanelState { none, keyboard, emoji }

/// Message input widget
class MessageInput extends StatefulWidget {
  final ChatProvider provider;
  final VoidCallback? onSend;
  final bool fullScreen;

  const MessageInput({
    super.key,
    required this.provider,
    this.onSend,
    this.fullScreen = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  // 核心状态管理
  InputPanelState _panelState = InputPanelState.none;
  double _cachedKeyboardHeight = 280; // 缓存键盘高度

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    widget.provider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // 获得焦点时，确保状态切换到 keyboard
      if (_panelState != InputPanelState.keyboard) {
        setState(() => _panelState = InputPanelState.keyboard);
      }
    }
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _toggleEmoji() async {
    final host = ChatOverlayHost.maybeOf(context);
    if (host == null) return;
    final hostBox = host.context.findRenderObject()! as RenderBox;
    final inputBox = context.findRenderObject() as RenderBox?;
    final inputOrigin = inputBox == null
        ? Offset(12, hostBox.size.height - 100)
        : hostBox.globalToLocal(inputBox.localToGlobal(Offset.zero));
    final theme = TgoThemeProvider.of(context);
    _focusNode.unfocus();
    setState(() => _panelState = InputPanelState.none);
    host.show((overlayContext) => LayoutBuilder(
          builder: (context, constraints) {
            final width = min(340.0, constraints.maxWidth - 24);
            final bottom = (constraints.maxHeight - inputOrigin.dy + 8)
                .clamp(12.0, max(12.0, constraints.maxHeight - 120));
            final height = min(320.0, constraints.maxHeight - bottom - 12);
            return Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: host.dismiss,
                ),
              ),
              Positioned(
                left: (inputOrigin.dx + 12)
                    .clamp(12.0, max(12.0, constraints.maxWidth - width - 12)),
                bottom: bottom.toDouble(),
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: TgoThemeProvider(
                    theme: theme,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.borderPrimary),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [theme.cardShadow],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: EmojiPicker(
                          onEmojiSelected: (emoji) {
                            _insertEmoji(emoji);
                            host.dismiss();
                          },
                          onDelete: _deleteLastChar,
                          onClose: host.dismiss,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ));
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();

    if (widget.provider.state.isStreaming) {
      await widget.provider.cancelStreaming(reason: 'auto_cancel_on_new_send');
    }

    _controller.clear();
    widget.onSend?.call();

    // 发送后保持面板状态
    if (_panelState == InputPanelState.keyboard) {
      _focusNode.requestFocus();
    }

    await widget.provider.sendMessage(text);
  }

  void _insertEmoji(String emoji) {
    if (!mounted) return;
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    HapticFeedback.lightImpact();
  }

  void _deleteLastChar() {
    final text = _controller.text;
    if (text.isEmpty) return;

    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    if (start == end) {
      if (start == 0) return;
      // 使用 characters 处理 UTF-16 代理对，确保一个 Emoji 只需删除一次
      final textBefore = text.substring(0, start).characters;
      final textAfter = text.substring(start);
      if (textBefore.isEmpty) return;

      final newTextBefore = textBefore.skipLast(1).toString();
      _controller.value = TextEditingValue(
        text: newTextBefore + textAfter,
        selection: TextSelection.collapsed(offset: newTextBefore.length),
      );
    } else {
      final newText = text.replaceRange(start, end, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    }
    HapticFeedback.lightImpact();
  }

  void _cancelStream() {
    HapticFeedback.selectionClick();
    widget.provider.cancelStreaming(reason: 'user_click');
  }

  @override
  Widget build(BuildContext context) {
    final theme = TgoThemeProvider.of(context);
    final strings =
        TgoLocalizations(locale: widget.provider.config.locale ?? 'en');
    final isStreaming = widget.provider.state.isStreaming;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 更新键盘高度缓存：只记录“有效键盘高度”，不要在键盘收起尾段把缓存写到接近 0。
    // iOS 键盘收起时 viewInsetsBottom 会逐帧减小到 0，如果持续写回，会导致后续 emoji 面板高度变成 ~bottomPadding，引发 overflow。
    const double kMinValidKeyboardHeight = 80; // 阈值：小于该值视为收起尾段噪声
    if (_panelState == InputPanelState.keyboard &&
        viewInsetsBottom >= kMinValidKeyboardHeight) {
      _cachedKeyboardHeight = max(_cachedKeyboardHeight, viewInsetsBottom);
    }

    // 当键盘已完全收起且输入框已失焦时，把状态从 keyboard 收敛到 none，避免后续逻辑误认为“仍在键盘模式”
    if (_panelState == InputPanelState.keyboard &&
        viewInsetsBottom == 0 &&
        !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_panelState == InputPanelState.keyboard &&
            !_focusNode.hasFocus &&
            MediaQuery.of(context).viewInsets.bottom == 0) {
          setState(() => _panelState = InputPanelState.none);
        }
      });
    }

    // 根据状态计算底部面板高度
    double panelHeight;
    switch (_panelState) {
      case InputPanelState.none:
        panelHeight = bottomPadding;
        break;
      case InputPanelState.keyboard:
        // 在键盘模式下，高度取 viewInsetsBottom 和 bottomPadding 的最大值
        panelHeight = max(viewInsetsBottom, bottomPadding);
        break;
      case InputPanelState.emoji:
        // 在表情模式下，高度固定为缓存的键盘高度 + 底部安全距离
        panelHeight = _cachedKeyboardHeight + bottomPadding;
        break;
    }

    final isEmojiMode = _panelState == InputPanelState.emoji;

    return TapRegion(
      onTapOutside: (_) {
        if (!mounted) return;
        if (_panelState != InputPanelState.none) {
          setState(() => _panelState = InputPanelState.none);
        }
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      child: Container(
        color: theme.bgPrimary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('tgo-composer'),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.bgInput,
                border: Border.all(color: theme.borderPrimary),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [theme.cardShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(
                        color: theme.textPrimary, fontSize: 14, height: 1.6),
                    decoration: InputDecoration(
                      hintText: strings.get('type_message'),
                      hintStyle: TextStyle(color: theme.textMuted),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 4),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: strings.get('attach'),
                        onPressed: () => FilePickerHelper.showPicker(
                            context, widget.provider),
                        icon: const Icon(Icons.attach_file, size: 20),
                        color: theme.textSecondary,
                      ),
                      IconButton(
                        tooltip: strings.get('emoji'),
                        onPressed: _toggleEmoji,
                        icon: Icon(
                            isEmojiMode
                                ? Icons.keyboard_alt_outlined
                                : Icons.sentiment_satisfied_alt,
                            size: 20),
                        color: theme.textSecondary,
                      ),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('tgo-send'),
                        tooltip:
                            strings.get(isStreaming ? 'interrupt' : 'send'),
                        onPressed: isStreaming
                            ? _cancelStream
                            : (_hasText ? _sendMessage : null),
                        style: IconButton.styleFrom(
                          backgroundColor: isStreaming
                              ? theme.errorColor
                              : theme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: theme.bgTertiary,
                          disabledForegroundColor: theme.textMuted,
                          minimumSize: const Size(36, 36),
                          padding: const EdgeInsets.all(8),
                          shape: const CircleBorder(),
                        ),
                        icon: Icon(
                            isStreaming
                                ? Icons.stop_rounded
                                : Icons.send_outlined,
                            size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 底部面板占位
            AnimatedContainer(
              // 键盘自身已经有系统级动画，这里如果再做 200ms 的缓动，会产生“尾段反向回弹/抖动”的观感。
              // 因此：keyboard 状态下禁用该容器动画，让高度严格跟随 viewInsetsBottom；emoji/none 才做平滑动画。
              duration: _panelState == InputPanelState.keyboard
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: panelHeight,
              child: isEmojiMode
                  ? ClipRect(
                      child: OverflowBox(
                        minHeight: 0,
                        maxHeight: _cachedKeyboardHeight + bottomPadding,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: _cachedKeyboardHeight + bottomPadding,
                          child: EmojiPicker(
                            onEmojiSelected: _insertEmoji,
                            onDelete: _deleteLastChar,
                            onSend: _hasText ? _sendMessage : null,
                            onClose: () => setState(
                                () => _panelState = InputPanelState.none),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
