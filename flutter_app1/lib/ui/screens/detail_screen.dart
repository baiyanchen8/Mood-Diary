import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // 暫存檔案用
import 'package:screenshot/screenshot.dart'; // 截圖用
import 'package:share_plus/share_plus.dart'; // 分享用

import '../../data/models/diary_entry.dart';
import '../../data/services/local_db_service.dart';
import 'editor_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final DiaryEntry entry;

  const DetailScreen({super.key, required this.entry});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  // 截圖控制器
  final ScreenshotController _screenshotController = ScreenshotController();
  // 分享狀態 (控制讀取轉圈圈)
  bool _isSharing = false;

  // --- 分享功能實作 ---
  Future<void> _shareDiary() async {
    setState(() => _isSharing = true);

    try {
      // 1. 取得裝置像素比，讓截圖更清晰
      final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

      // 1. 預先取得當前的 MediaQuery 和 Theme 資料
      // 因為 captureFromWidget 在背景執行，無法直接讀取 context
      final mediaQueryData = MediaQuery.of(context);
      final themeData = Theme.of(context);

      final imageBytes = await _screenshotController.captureFromWidget(
        // 2. 手動包裹 MediaQuery 和 Theme，解決 "View.of() ... not found" 錯誤
        MediaQuery(
          data: mediaQueryData,
          child: Theme(
            data: themeData,
            child: Material(
              color: Colors.white,
              child: _buildDiaryContent(context, widget.entry),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: pixelRatio,
      );

      // 3. 將圖片存入暫存檔
      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/diary_share.png',
      ).create();
      await imagePath.writeAsBytes(imageBytes);

      // 4. 呼叫系統分享
      final dateStr = DateFormat.yMMMd('zh_TW').format(widget.entry.date);
      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'Mood Diary 心情日記 - $dateStr');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // --- UI 建構邏輯 (抽取出來供 顯示 & 截圖 共用) ---
  Widget _buildDiaryContent(BuildContext context, DiaryEntry entry) {
    final dateStr = DateFormat.MMMEd('zh_TW').format(entry.date);
    final moodColor = entry.mood.color;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 心情看板 (Header)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            color: moodColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Text(entry.specificEmoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.mood.label,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: moodColor,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. 日記內容區域
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: entry.content,
                  // 圖片處理邏輯
                  sizedImageBuilder: (config) {
                    final uri = config.uri;
                    if (uri.scheme != 'http' && uri.scheme != 'https') {
                      // 處理本地圖片
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(uri.toFilePath())),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: const TextStyle(fontSize: 16, height: 1.6),
                        h1: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),

                const SizedBox(height: 40),

                // 3. 雞湯語錄 (如果有)
                if (entry.cachedQuoteContent != null) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Mood Diary 語錄",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1), // 淺黃色背景
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Text(
                      entry.cachedQuoteContent!,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.brown.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // 底部留白 (讓浮水印有空間，可選)
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.MMMEd('zh_TW').format(widget.entry.date);
    final moodColor = widget.entry.mood.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        backgroundColor: moodColor.withValues(alpha: 0.2),
        actions: [
          // 分享按鈕 (新增)
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareDiary,
            tooltip: "分享日記",
          ),
          // 編輯按鈕
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EditorScreen(
                    date: widget.entry.date,
                    existingEntry: widget.entry,
                  ),
                ),
              );
            },
          ),
          // 刪除按鈕
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      // 直接呼叫抽取出來的 UI 建構函式
      body: _buildDiaryContent(context, widget.entry),
    );
  }

  // 刪除確認對話框
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除日記"),
        content: const Text("確定要刪除這篇日記嗎？刪除後無法復原喔。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              ref.read(localDbServiceProvider).deleteEntry(widget.entry.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("刪除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
