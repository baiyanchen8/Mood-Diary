import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/diary_entry.dart';
import '../../data/services/local_db_service.dart';
import 'editor_screen.dart';
import 'dart:io';

class DetailScreen extends ConsumerWidget {
  final DiaryEntry entry;

  const DetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat.MMMEd('zh_TW').format(entry.date);
    final moodColor = entry.mood.color; // 使用心情顏色

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        backgroundColor: moodColor.withValues(alpha: 0.2), // 標題欄淡淡的心情色
        actions: [
          // 編輯按鈕
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // 跳轉去編輯頁，並把目前這篇 entry 傳過去
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditorScreen(date: entry.date, existingEntry: entry),
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
      body: Column(
        children: [
          // 1. 心情看板 (Header)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            width: double.infinity,
            color: moodColor.withValues(alpha: .1),
            child: Row(
              children: [
                Text(entry.specificEmoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.mood.label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: moodColor,
                      ),
                    ),
                    const Text("的心情", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          // 2. 日記內容 (Markdown 渲染區域)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: entry.content,
                    sizedImageBuilder: (config) {
                      final uri = config.uri; // 從 config 中取得 uri

                      if (uri.scheme != 'http' && uri.scheme != 'https') {
                        // 處理本地圖片
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(uri.toFilePath())),
                          ),
                        );
                      }
                      // 處理網路圖片 (選用，目前回傳空)
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

                  // 3. 顯示當時獲得的雞湯 (如果有的話)
                  if (entry.cachedQuoteContent != null) ...[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "✨ 來自系統的小語",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.cachedQuoteContent!,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.brown.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
              // 執行刪除
              ref.read(localDbServiceProvider).deleteEntry(entry.id);
              Navigator.pop(ctx); // 關閉 Dialog
              Navigator.pop(context); // 關閉 DetailScreen 回到首頁
            },
            child: const Text("刪除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
