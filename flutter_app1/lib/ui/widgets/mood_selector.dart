import 'package:flutter/material.dart';
import '../../data/models/mood.dart';

class MoodSelector extends StatefulWidget {
  final Function(Mood mood, String emoji) onSelected;

  const MoodSelector({super.key, required this.onSelected});

  @override
  State<MoodSelector> createState() => _MoodSelectorState();
}

class _MoodSelectorState extends State<MoodSelector> {
  Mood? _selectedMood;
  String? _selectedEmoji;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今天心情如何？',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // 第一層：選擇心情分類 (Happy, Sad...)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: Mood.values.map((mood) {
              final isSelected = _selectedMood == mood;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(mood.label),
                  selected: isSelected,
                  selectedColor: mood.color.withOpacity(0.3),
                  avatar: Text(mood.representativeEmoji), // 顯示代表性 Emoji
                  onSelected: (selected) {
                    setState(() {
                      _selectedMood = mood;
                      // 預設選第一個 emoji，避免 null
                      _selectedEmoji = mood.emojis.first;
                    });
                    // 通知父元件
                    widget.onSelected(mood, _selectedEmoji!);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // 第二層：選擇具體 Emoji (根據上面選的分類)
        if (_selectedMood != null) ...[
          const Text(
            '具體來說是...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: _selectedMood!.emojis.map((emoji) {
              final isEmojiSelected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmoji = emoji;
                  });
                  widget.onSelected(_selectedMood!, emoji);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEmojiSelected
                        ? _selectedMood!.color.withOpacity(0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isEmojiSelected
                        ? Border.all(color: _selectedMood!.color, width: 2)
                        : null,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
