import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/models/quote.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);

    // 使用 TextEditingController 來管理輸入框
    final urlController = TextEditingController(text: settings.serverUrl);

    return Scaffold(
      appBar: AppBar(title: const Text("設定")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '外觀',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (value) {
              if (value != null) ref.read(themeModeProvider.notifier).setTheme(value);
            },
            child: Column(
              children: const [
                RadioListTile<ThemeMode>(
                  title: Text('跟隨系統'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('淺色模式'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('深色模式'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text("啟用 AI 遠端生成模式"),
            subtitle: const Text("將日記傳送到伺服器進行深度分析"),
            value: settings.isRemoteMode,
            onChanged: (value) {
              notifier.setRemoteMode(value);
            },
            secondary: Icon(
              settings.isRemoteMode ? Icons.cloud_done : Icons.cloud_off,
              color: settings.isRemoteMode ? Colors.blue : Colors.grey,
            ),
          ),

          if (settings.isRemoteMode) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: "伺服器位址 (Server IP)",
                  hintText: "http://192.168.1.100:8000",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                onSubmitted: (value) {
                  notifier.setServerUrl(value); // 按 Enter 儲存
                },
                onEditingComplete: () {
                  notifier.setServerUrl(urlController.text); // 離開焦點儲存
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "請輸入完整網址，包含 http:// 與埠號。",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '資料備份與還原',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('匯出備份 (ZIP)'),
            subtitle: const Text('包含日記文字、雞湯紀錄與所有圖片'),
            onTap: () async {
              try {
                final dbService = ref.read(localDbServiceProvider);
                final backupService = BackupService(dbService);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('正在打包資料，請稍候...')),
                );
                
                await backupService.createBackup();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('匯出失敗: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.unarchive),
            title: const Text('匯入備份 (ZIP)'),
            subtitle: const Text('從 ZIP 檔案還原資料'),
            onTap: () async {
              try {
                final dbService = ref.read(localDbServiceProvider);
                final backupService = BackupService(dbService);
                
                await backupService.restoreBackup();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('資料還原成功！')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('還原失敗: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '擴充功能',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.library_add),
            title: const Text('匯入自定義雞湯 (JSON)'),
            subtitle: const Text('格式: [{"content": "...", "category": "happy"}]'),
            onTap: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final jsonString = await file.readAsString();
                  final List<dynamic> jsonList = jsonDecode(jsonString);

                  final quotes = jsonList.map((q) => Quote(
                    content: q['content'],
                    category: q['category'],
                    author: q['author'],
                  )).toList();

                  ref.read(localDbServiceProvider).addQuotes(quotes);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('成功匯入 ${quotes.length} 句雞湯！')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯入失敗: $e')));
              }
            },
          ),
        ],
      ),
    );
  }
}
