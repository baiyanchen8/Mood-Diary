import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/mood.dart';
import '../../data/services/local_db_service.dart';
import '../widgets/mood_selector.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final DateTime date; // 從首頁傳入的日期

  const EditorScreen({super.key, required this.date});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _contentController = TextEditingController();

  Mood? _mood;
  String? _emoji;
  bool _isSaving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // 儲存邏輯
  Future<void> _saveDiary() async {
    if (_mood == null || _emoji == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先選擇一個心情喔！')));
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日記內容不能為空')));
      return;
    }

    setState(() => _isSaving = true);

    // 1. 建立資料物件
    final entry = DiaryEntry()
      ..date = widget.date
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..mood =
          _mood! // 使用 Setter 設定 Mood Enum
      ..specificEmoji = _emoji!
      ..content = _contentController.text;

    // 2. 寫入資料庫 (透過 Provider 取得 Service)
    await ref.read(localDbServiceProvider).saveEntry(entry);

    // 3. (模擬) 雞湯回饋展示
    // 之後這裡會改成讀取 JSON，現在先用簡單的 Switch 展示效果
    if (mounted) {
      await _showChickenSoupDialog(_mood!);
      if (mounted) Navigator.pop(context); // 關閉頁面回首頁
    }
  }

  // 顯示雞湯彈窗
  Future<void> _showChickenSoupDialog(Mood mood) async {
    String quote = "今天也要加油！";
    // 簡單的模擬資料
    if (mood == Mood.sad) quote = "逃避雖可恥但有用，先睡一覺吧。";
    if (mood == Mood.happy) quote = "保持這份快樂，你是最棒的！";
    if (mood == Mood.angry) quote = "別用別人的錯誤來懲罰自己。";
    if (mood == Mood.love) quote = "愛是生活最好的解藥。";

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${mood.representativeEmoji} 心靈小語'),
        content: Text(quote, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('收下'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 格式化日期顯示: "10月 15日 (週三)"
    final dateStr = DateFormat.MMMEd('zh_TW').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveDiary,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 心情選擇區
            MoodSelector(
              onSelected: (mood, emoji) {
                _mood = mood;
                _emoji = emoji;
              },
            ),

            const Divider(height: 40),

            // 2. 文字編輯區
            const Text(
              '發生了什麼事？',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 10, // 讓它看起來像筆記本
              decoration: const InputDecoration(
                hintText: '支援 Markdown 格式...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFFAFAFA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
