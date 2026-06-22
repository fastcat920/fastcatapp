import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/fade_box.dart';
import 'package:flutter/material.dart' hide RoundedSuperellipseBorder;

class MessageManager extends StatefulWidget {
  final Widget child;

  const MessageManager({
    super.key,
    required this.child,
  });

  @override
  State<MessageManager> createState() => MessageManagerState();
}

class MessageManagerState extends State<MessageManager> {
  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final _bottomMessagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final List<CommonMessage> _bufferMessages = [];
  final List<CommonMessage> _bottomBufferMessages = [];
  bool _pushing = false;
  bool _pushingBottom = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messagesNotifier.dispose();
    _bottomMessagesNotifier.dispose();
    super.dispose();
  }

  Future<void> message(String text, {VoidCallback? onTap}) async {
    await _message(
      text,
      buffer: _bufferMessages,
      onTap: onTap,
      showMessage: _showMessage,
    );
  }

  Future<void> bottomMessage(String text, {VoidCallback? onTap}) async {
    await _message(
      text,
      buffer: _bottomBufferMessages,
      onTap: onTap,
      showMessage: _showBottomMessage,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _message(
    String text, {
    required List<CommonMessage> buffer,
    required Future<void> Function() showMessage,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 3),
  }) async {
    final commonMessage = CommonMessage(
      id: utils.uuidV4,
      text: text,
      onTap: onTap,
      duration: duration,
    );
    commonPrint.log(text);
    buffer.add(commonMessage);
    await showMessage();
  }

  Future<void> _showMessage() async {
    if (_pushing == true) {
      return;
    }
    _pushing = true;
    while (_bufferMessages.isNotEmpty) {
      final commonMessage = _bufferMessages.removeAt(0);
      _messagesNotifier.value = List.from(_messagesNotifier.value)
        ..add(
          commonMessage,
        );
      await Future.delayed(const Duration(seconds: 1));
      Future.delayed(commonMessage.duration, () {
        _handleRemove(commonMessage, _messagesNotifier);
      });
      if (_bufferMessages.isEmpty) {
        _pushing = false;
      }
    }
  }

  Future<void> _showBottomMessage() async {
    if (_pushingBottom == true) {
      return;
    }
    _pushingBottom = true;
    while (_bottomBufferMessages.isNotEmpty) {
      final commonMessage = _bottomBufferMessages.removeAt(0);
      _bottomMessagesNotifier.value = List.from(_bottomMessagesNotifier.value)
        ..add(commonMessage);
      await Future.delayed(const Duration(seconds: 1));
      Future.delayed(commonMessage.duration, () {
        _handleRemove(commonMessage, _bottomMessagesNotifier);
      });
      if (_bottomBufferMessages.isEmpty) {
        _pushingBottom = false;
      }
    }
  }

  Future<void> _handleRemove(
    CommonMessage commonMessage,
    ValueNotifier<List<CommonMessage>> notifier,
  ) async {
    notifier.value = List<CommonMessage>.from(notifier.value)
      ..remove(commonMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        _MessageLayer(
          messagesNotifier: _messagesNotifier,
          onRemove: (message) => _handleRemove(message, _messagesNotifier),
        ),
        _MessageLayer(
          messagesNotifier: _bottomMessagesNotifier,
          alignment: Alignment.bottomCenter,
          marginBuilder: (mediaQuery) {
            final viewBottom = max(
              mediaQuery.viewPadding.bottom,
              mediaQuery.viewInsets.bottom,
            );
            final isNarrow = mediaQuery.size.width < 600;
            // 窄屏越过底部导航栏(68dp)
            final bottomOffset = isNarrow ? 68.0 : 40.0;
            // 桌面端侧边导航栏 96dp，左边距补 96dp 使卡片在内容区居中
            final leftOffset = isNarrow ? 12.0 : 108.0;
            return EdgeInsets.only(
              bottom: viewBottom + bottomOffset,
              left: leftOffset,
              right: 12,
            );
          },
          onRemove: (message) =>
              _handleRemove(message, _bottomMessagesNotifier),
        ),
      ],
    );
  }
}

class _MessageLayer extends StatelessWidget {
  const _MessageLayer({
    required this.messagesNotifier,
    required this.onRemove,
    this.alignment = Alignment.topRight,
    this.marginBuilder,
  });

  final ValueNotifier<List<CommonMessage>> messagesNotifier;
  final Alignment alignment;
  final EdgeInsets Function(MediaQueryData mediaQuery)? marginBuilder;
  final Future<void> Function(CommonMessage message) onRemove;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: messagesNotifier,
      builder: (_, messages, __) {
        final mediaQuery = MediaQuery.of(context);
        return FadeThroughBox(
          margin: marginBuilder?.call(mediaQuery) ??
              const EdgeInsets.only(
                top: kToolbarHeight + 8,
                left: 12,
                right: 12,
              ),
          alignment: alignment,
          child: messages.isEmpty
              ? const SizedBox()
              : LayoutBuilder(
                  key: Key(messages.last.id),
                  builder: (_, constraints) {
                    final message = messages.last;

                    final cardContent = Container(
                      width: min(
                        constraints.maxWidth,
                        500,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Text(
                        message.text,
                      ),
                    );

                    if (message.onTap != null) {
                      return GestureDetector(
                        onTap: () {
                          message.onTap?.call();
                          onRemove(message);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: _MessageCard(child: cardContent),
                      );
                    }

                    return _MessageCard(child: cardContent);
                  },
                ),
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(12.0),
        ),
      ),
      elevation: 10,
      color: context.colorScheme.surfaceContainerHigh,
      child: child,
    );
  }
}
