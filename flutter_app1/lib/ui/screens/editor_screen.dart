import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/mood.dart';
import '../../data/services/local_db_service.dart';
import '../widgets/mood_selector.dart';

import 'dart:io'; // 處理檔案
import 'package:image_picker/image_picker.dart'; // 選圖
import 'package:path_provider/path_provider.dart'; // 找路徑
import 'package:path/path.dart' as p; // 處理路徑字串

class EditorScreen extends ConsumerStatefulWidget {
  final DateTime date; // 從首頁傳入的日期
  final DiaryEntry? existingEntry; // 新增這行：傳入舊日記 (可選)
  const EditorScreen({
    super.key,
    required this.date,
    this.existingEntry, // 新增這行
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _contentController = TextEditingController();

  Mood? _mood;
  String? _emoji;
  bool _isSaving = false;

  // 在 _EditorScreenState 類別裡

  @override
  void initState() {
    super.initState();
    // 如果是修改模式，把舊資料填回去
    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _contentController.text = entry.content;
      _mood = entry.mood; // 記得確認你的 DiaryEntry 有 getter 取回 Enum
      _emoji = entry.specificEmoji;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // 輔助函式：在游標處插入文字
  void _insertTextAtCursor(String text) {
    final textSelection = _contentController.selection;
    final newText = text;

    if (textSelection.start < 0) {
      // 如果沒有焦點，直接加在最後面
      _contentController.text += '\n$newText\n';
    } else {
      // 插在游標中間
      final currentText = _contentController.text;
      final newValue = currentText.replaceRange(
        textSelection.start,
        textSelection.end,
        '\n$newText\n', // 前後換行比較安全
      );
      _contentController.text = newValue;
    }
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
    // 在 _saveDiary 方法內
    final entry = DiaryEntry()
      ..id =
          widget.existingEntry?.id ??
          0 // 核心：如果有舊 ID 就沿用，沒有就用 0
      ..date = widget.date
      ..createdAt = widget.existingEntry?.createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now()
      ..mood = _mood!
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
  } //future _saveDiary

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
  } //_showChickenSoupDialog

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // 1. 開啟相簿選圖
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // 2. 取得 App 專屬的文件目錄
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(image.path); // 取得檔名 (ex: photo.jpg)
    // 建立一個 images 子資料夾保持整潔
    final savedImageDir = Directory('${appDir.path}/images');
    if (!savedImageDir.existsSync()) {
      savedImageDir.createSync(recursive: true);
    }

    final savedImagePath = '${savedImageDir.path}/$fileName';

    // 3. 將圖片複製到 App 目錄
    await File(image.path).copy(savedImagePath);

    // 4. 在游標位置插入 Markdown 語法
    _insertTextAtCursor('![圖片]($savedImagePath)');
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
            icon: const Icon(Icons.image),
            onPressed: _pickImage,
          ), //IconButton
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
