import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/mine/services/imgbb_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class TicketDetailPage extends ConsumerStatefulWidget {
  final int ticketId;
  const TicketDetailPage({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends ConsumerState<TicketDetailPage> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isReplying = false;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final message = _replyCtrl.text.trim();
    if (message.isEmpty) return;

    setState(() => _isReplying = true);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final ok = await sdk.ticket.replyTicket(widget.ticketId, message);
      if (mounted) {
        if (ok) {
          _replyCtrl.clear();
          ref.invalidate(getTicketProvider(widget.ticketId));
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('回复失败，请稍后重试')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回复失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  Future<void> _closeTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: XbUiDialog.shape(),
        backgroundColor: XbUiDialog.background(ctx),
        title: Text('关闭工单', style: XbUiText.sectionTitle(ctx)),
        content: const Text('确定要关闭此工单吗？关闭后将无法继续回复。'),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: XbUiButton.outlinedNeutral(ctx),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: XbUiButton.filledPrimary(ctx),
              child: const Text('确认关闭')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final ok = await sdk.ticket.closeTicket(widget.ticketId);
      if (mounted && ok) {
        setState(() => _isClosed = true);
        ref.invalidate(getTicketProvider(widget.ticketId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('工单已关闭')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(getTicketProvider(widget.ticketId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: const Text('工单详情'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: XbUiStatusColor.error(context)),
              const SizedBox(height: 12),
              Text('加载失败: $e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(getTicketProvider(widget.ticketId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (detail) {
          final isClosed = _isClosed || detail.status == 2;
          // 滚到底部
          _scrollToBottom();
          return Column(
            children: [
              // 工单标题信息
              _TicketHeader(detail: detail),
              // 消息列表
              Expanded(
                child: detail.messages.isEmpty
                    ? Center(
                        child: Text('暂无消息',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: detail.messages.length,
                        itemBuilder: (context, i) =>
                            _MessageBubble(msg: detail.messages[i]),
                      ),
              ),
              // 回复栏 / 已关闭提示
              if (isClosed)
                _ClosedBar()
              else
                _ReplyBar(
                  controller: _replyCtrl,
                  isReplying: _isReplying,
                  onSend: _sendReply,
                  onClose: _closeTicket,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── 工单头部信息 ─────────────────────────────────────────────────────────────

class _TicketHeader extends StatelessWidget {
  final TicketDetailModel detail;
  const _TicketHeader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context, detail.status);
    final statusLabel = _statusLabel(detail.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.subject,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(
                '#${detail.id}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                _formatDate(detail.createdAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, int status) {
    switch (status) {
      case 0:
        return XbUiStatusColor.pending(context);
      case 1:
        return XbUiStatusColor.success(context);
      case 2:
        return XbUiStatusColor.muted(context);
      default:
        return XbUiStatusColor.muted(context);
    }
  }

  String _statusLabel(int status) {
    switch (status) {
      case 0:
        return '待处理';
      case 1:
        return '已回复';
      case 2:
        return '已关闭';
      default:
        return '未知';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ─── 消息气泡 ─────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final TicketMessageModel msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = msg.isMe;
    final textColor =
        isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final hasImage = msg.message.contains('![');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.support_agent,
                  size: 18, color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: hasImage
                      ? MarkdownBody(
                          data: msg.message,
                          styleSheet: MarkdownStyleSheet(
                            p: theme.textTheme.bodyMedium
                                ?.copyWith(color: textColor),
                            a: theme.textTheme.bodyMedium?.copyWith(
                              color: isMe
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(Uri.parse(href),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          sizedImageBuilder: (details) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: details.uri.toString(),
                                fit: BoxFit.cover,
                                progressIndicatorBuilder:
                                    (context, url, progress) => SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: textColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 60,
                                  color: Colors.black12,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          msg.message,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: textColor),
                        ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(msg.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.person,
                  size: 18, color: theme.colorScheme.onPrimaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ─── 回复输入栏 ───────────────────────────────────────────────────────────────

class _ReplyBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isReplying;
  final VoidCallback onSend;
  final VoidCallback onClose;

  const _ReplyBar({
    required this.controller,
    required this.isReplying,
    required this.onSend,
    required this.onClose,
  });

  @override
  State<_ReplyBar> createState() => _ReplyBarState();
}

class _ReplyBarState extends State<_ReplyBar> {
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    final apiKey = XBoardConfig.imgbbApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片上传未配置，请联系管理员')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await ImgBBService(apiKey).uploadImage(File(picked.path));
      // 在当前光标位置（或末尾）插入 Markdown 图片语法
      final text = widget.controller.text;
      final insertText = text.isEmpty ? '![image]($url)' : '\n![image]($url)';
      widget.controller.text = text + insertText;
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImgbb = XBoardConfig.imgbbApiKey.isNotEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            // 关闭工单按钮
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: '关闭工单',
              onPressed: widget.onClose,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // 图片上传按钮（仅 imgbbApiKey 已配置时显示）
            if (hasImgbb)
              _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.image_outlined),
                      tooltip: '上传图片',
                      onPressed: _pickAndUploadImage,
                      style: IconButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            // 输入框
            Expanded(
              child: TVDeferredInput(
                borderRadius: BorderRadius.circular(20),
                builder:
                    (context, focusNode, readOnly, showCursor, beginEditing) =>
                        TextField(
                  focusNode: focusNode,
                  readOnly: readOnly,
                  showCursor: showCursor,
                  onTap: beginEditing,
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '输入回复内容...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 发送按钮
            IconButton.filled(
              onPressed: widget.isReplying ? null : widget.onSend,
              icon: widget.isReplying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 已关闭提示栏 ─────────────────────────────────────────────────────────────

class _ClosedBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          border: Border(
            top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15)),
          ),
        ),
        child: Text(
          '工单已关闭',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
