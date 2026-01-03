import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/mood.dart';
import '../../data/services/local_db_service.dart';
import '../widgets/mood_selector.dart';

import '../../data/services/quote_service.dart';

import 'dart:io'; // 處理檔案
import 'package:image_picker/image_picker.dart'; // 選圖
import 'package:path_provider/path_provider.dart'; // 找路徑
import 'package:path/path.dart' as p; // 處理路徑字串

import '../../providers/settings_provider.dart'; // 設定
import '../../data/services/remote_ai_service.dart'; // 遠端服務

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

    try {
      // 1. 獲取雞湯 (如果是修改舊日記且已經有雞湯，就不重新抓，保留當時的回憶)
      String quoteContent;
      if (widget.existingEntry?.cachedQuoteContent != null) {
        quoteContent = widget.existingEntry!.cachedQuoteContent!;
      } else {
        // 如果是新日記，或者舊日記沒有雞湯，就抓一個新的
        // B. 產生新雞湯：判斷是用 AI 還是本地
        final settings = ref.read(settingsProvider);
        String? aiQuote;

        if (settings.isRemoteMode) {
          // 嘗試呼叫遠端 AI
          aiQuote = await RemoteAiService.getAiQuote(
            settings.serverUrl,
            _contentController.text,
            _mood!,
          );
        }

        if (aiQuote != null) {
          // 遠端成功
          quoteContent = aiQuote;
        } else {
          // 遠端失敗 (或沒開) -> Fallback 到本地 JSON
          if (settings.isRemoteMode) {
            // 如果開了遠端卻失敗，可以 Show 個 SnackBar 提示使用者 (可選)
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("連線失敗，已切換回本地模式")));
          }
          // 修改為使用 Provider
          quoteContent = await ref.read(quoteServiceProvider).getQuoteForMood(_mood!);
        }
      }

      // 2. 建立/更新資料物件
      final entry = DiaryEntry()
        ..id = widget.existingEntry?.id ?? 0
        ..date = widget.date
        ..createdAt = widget.existingEntry?.createdAt ?? DateTime.now()
        ..updatedAt = DateTime.now()
        ..mood = _mood!
        ..specificEmoji = _emoji!
        ..content = _contentController.text
        ..cachedQuoteContent = quoteContent; // 存入雞湯

      // 3. 寫入資料庫
      await ref.read(localDbServiceProvider).saveEntry(entry);

      // 4. 顯示雞湯彈窗回饋 (這一步很重要，給使用者的驚喜)
      if (mounted) {
        await _showChickenSoupDialog(_mood!, quoteContent);
        if (mounted) Navigator.pop(context); // 關閉頁面回首頁
      }
    } catch (e) {
      // 錯誤處理
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("儲存失敗: $e")));
        setState(() => _isSaving = false);
      }
    }
  }

  // 顯示雞湯彈窗 (接收 quote 參數)
  Future<void> _showChickenSoupDialog(Mood mood, String quote) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // 強制使用者點按鈕才能關閉，確保看到雞湯
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              mood.representativeEmoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            const Text('給此刻的你'),
          ],
        ),
        // 這裡顯示剛剛抓到的真實雞湯
        content: Text(quote, style: const TextStyle(fontSize: 18, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('收下這份力量'),
          ),
        ],
      ),
    );
  }

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
              decoration: InputDecoration(
                hintText: '支援 Markdown 格式...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800] // 深色模式：使用深灰背景，搭配白色文字
                    : const Color(0xFFFAFAFA), // 淺色模式：使用米白背景，搭配黑色文字
              ),
            ),
          ],
        ),
      ),
    );
  }
}
