import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'client.dart';
import 'models.dart';

class FastCatChatScreen extends StatefulWidget {
  const FastCatChatScreen({
    super.key,
    required this.client,
    this.title = 'FastCat Chat',
    this.accentColor = const Color(0xff2878ef),
    this.disposeClient = false,
    this.initialProfile = const FastCatProfile(),
  });
  final FastCatSupport client;
  final String title;
  final Color accentColor;
  final bool disposeClient;
  final FastCatProfile initialProfile;
  @override
  State<FastCatChatScreen> createState() => _FastCatChatScreenState();
}

class _FastCatChatScreenState extends State<FastCatChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.client.addListener(changed);
    (widget.client.registered
            ? Future<void>.value().then((_) => widget.client.connect())
            : widget.client.load(profile: widget.initialProfile))
        .catchError((Object e) {
      if (mounted) setState(() => error = '$e');
    });
  }

  void changed() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients)
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
    });
  }

  Future<void> send() async {
    final value = input.text.trim();
    if (value.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    input.clear();
    try {
      await widget.client.send(value);
    } catch (e) {
      input.text = value;
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final file = result?.files.single;
      if (file?.bytes == null) return;
      setState(() {
        sending = true;
        error = null;
      });
      await widget.client.sendFile(file!.bytes!, file.name);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> handoff() async {
    try {
      await widget.client.handoff();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    widget.client.removeListener(changed);
    if (widget.disposeClient) widget.client.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.accentColor,
        foregroundColor: Colors.white,
        actions: [
          if (client.mode != 'human')
            TextButton.icon(
              onPressed: handoff,
              icon: const Icon(Icons.support_agent, color: Colors.white),
              label: const Text('转人工', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!client.connected)
            MaterialBanner(
              content: Text(client.connecting ? '正在连接客服…' : '连接中断，正在自动重连…'),
              leading: const Icon(Icons.wifi_off),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              itemCount: client.messages.length,
              itemBuilder: (_, index) => messageBubble(client.messages[index]),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: sending ? null : pickFile,
                    icon: const Icon(Icons.attach_file),
                    tooltip: '上传文件',
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: !sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: '输入消息',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    style: IconButton.styleFrom(
                      backgroundColor: widget.accentColor,
                    ),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget messageBubble(FastCatMessage message) {
    final visitor = message.role == 'visitor';
    final color = visitor ? widget.accentColor : const Color(0xfff1f4f8);
    final foreground = visitor ? Colors.white : const Color(0xff182436);
    final file = RegExp(
      r'^\[(图片|视频|音频|附件)\] (.+?) \| (https?://\S+)$',
    ).firstMatch(message.content);
    Widget body;
    if (file != null && file.group(1) == '图片') {
      body = Image.network(
        file.group(3)!,
        width: 220,
        errorBuilder: (_, __, ___) =>
            Text(file.group(2)!, style: TextStyle(color: foreground)),
      );
    } else if (file != null) {
      body = Text(
        '${file.group(1)}：${file.group(2)}',
        style: TextStyle(color: foreground),
      );
    } else {
      body = Text(
        message.content.isEmpty && message.streaming
            ? '正在输入…'
            : message.content,
        style: TextStyle(color: foreground),
      );
    }
    return Align(
      alignment: visitor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
            if (message.streaming)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
