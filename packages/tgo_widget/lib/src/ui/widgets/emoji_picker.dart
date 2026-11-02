import 'package:flutter/material.dart';
import '../theme/tgo_theme.dart';

/// Compact emoji popover matching the web widget categories and grid.
class EmojiPicker extends StatefulWidget {
  final void Function(String emoji) onEmojiSelected;
  final VoidCallback onDelete;
  final VoidCallback? onSend;
  final VoidCallback onClose;

  const EmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onDelete,
    this.onSend,
    required this.onClose,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  int _selectedTab = 0;

  static const List<String> _smileys = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '☺️',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🫠',
    '🤗',
    '🥲',
    '🫡',
    '🤔'
  ];

  static const List<String> _hearts = [
    '❤️',
    '🩵',
    '💛',
    '💚',
    '💙',
    '💜',
    '🧡',
    '🖤',
    '🤍',
    '🤎',
    '💘',
    '💖',
    '💗',
    '💓',
    '💕',
    '💞'
  ];

  static const List<String> _party = [
    '🎉',
    '🎊',
    '✨',
    '⭐️',
    '🌟',
    '💫',
    '🔥',
    '⚡️',
    '🎈',
    '🎁',
    '🥳',
    '👏',
    '👍',
    '🙌',
    '🤝'
  ];

  List<String> get _currentEmojis {
    switch (_selectedTab) {
      case 0:
        return _smileys;
      case 1:
        return _hearts;
      case 2:
        return _party;
      default:
        return _smileys;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = TgoThemeProvider.of(context);
    return Material(
      color: theme.bgPrimary,
      borderRadius: BorderRadius.circular(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.borderPrimary))),
            child: Row(
                children: List.generate(
                    3,
                    (index) => Padding(
                          padding: const EdgeInsets.all(4),
                          child: IconButton(
                              onPressed: () =>
                                  setState(() => _selectedTab = index),
                              style: IconButton.styleFrom(
                                  backgroundColor: _selectedTab == index
                                      ? theme.bgTertiary
                                      : Colors.transparent),
                              icon: Text(['😀', '❤️', '🎉'][index],
                                  style: const TextStyle(fontSize: 20))),
                        )))),
        Flexible(
            child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: _currentEmojis.length,
                itemBuilder: (context, index) => InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () =>
                          widget.onEmojiSelected(_currentEmojis[index]),
                      child: Center(
                          child: Text(_currentEmojis[index],
                              style: const TextStyle(fontSize: 22))),
                    ))),
      ]),
    );
  }
}
