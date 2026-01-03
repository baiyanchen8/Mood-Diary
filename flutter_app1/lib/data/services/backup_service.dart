import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../models/diary_entry.dart';
import 'local_db_service.dart';

class BackupService {
  final LocalDbService _dbService;

  BackupService(this._dbService);

  /// 匯出備份 (ZIP)
  Future<void> createBackup() async {
    final entries = _dbService.getAllEntries();
    final archive = Archive();

    // 1. 準備 JSON 資料
    final List<Map<String, dynamic>> jsonList = [];

    for (final entry in entries) {
      final entryJson = entry.toJson();
      
      // 處理圖片：將實體檔案讀入 ZIP，並將 JSON 中的路徑改為相對路徑 (僅檔名)
      if (entry.images != null && entry.images!.isNotEmpty) {
        final List<String> relativeImages = [];
        for (final imagePath in entry.images!) {
          final file = File(imagePath);
          if (await file.exists()) {
            final filename = p.basename(imagePath);
            // 將圖片檔案加入 ZIP 的 images/ 資料夾下
            final archiveFile = ArchiveFile('images/$filename', await file.length(), await file.readAsBytes());
            archive.addFile(archiveFile);
            // JSON 只紀錄檔名
            relativeImages.add('images/$filename');
          }
        }
        entryJson['images'] = relativeImages;
      }
      
      jsonList.add(entryJson);
    }

    // 2. 加入 JSON 檔案到 ZIP
    final jsonString = jsonEncode(jsonList);
    final jsonFile = ArchiveFile('diary_data.json', jsonString.length, utf8.encode(jsonString));
    archive.addFile(jsonFile);

    // 3. 壓縮並儲存到暫存區
    final zipEncoder = ZipEncoder();
    final encodedArchive = zipEncoder.encode(archive);
    
    if (encodedArchive == null) return;

    final tempDir = await getTemporaryDirectory();
    final backupFile = File('${tempDir.path}/mood_diary_backup.zip');
    await backupFile.writeAsBytes(encodedArchive);

    // 4. 呼叫系統分享，讓使用者選擇儲存位置或傳送
    await Share.shareXFiles([XFile(backupFile.path)], text: '我的心情日記備份 (含圖片)');
  }

  /// 匯入備份 (ZIP)
  Future<void> restoreBackup() async {
    // 1. 讓使用者選擇 ZIP 檔案
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final appDocDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDocDir.path}/images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    List<DiaryEntry> entries = [];

    // 2. 解壓縮檔案
    for (final archiveFile in archive) {
      if (archiveFile.isFile) {
        final filename = archiveFile.name;
        
        if (filename == 'diary_data.json') {
          // 讀取日記資料
          final jsonString = utf8.decode(archiveFile.content as List<int>);
          final jsonList = jsonDecode(jsonString) as List;
          // 暫時轉為物件，圖片路徑稍後修正
           entries = jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
        } else if (filename.startsWith('images/')) {
          // 還原圖片到本機 App 目錄
          final imageFilename = p.basename(filename);
          final outFile = File('${imagesDir.path}/$imageFilename');
          await outFile.writeAsBytes(archiveFile.content as List<int>);
        }
      }
    }

    // 3. 修正圖片路徑並寫入資料庫
    for (final entry in entries) {
      if (entry.images != null) {
        final newPaths = entry.images!.map((relativePath) {
          // ZIP 裡的 JSON 存的是 "images/abc.jpg"，我們要轉成手機上的絕對路徑
          final filename = p.basename(relativePath);
          return '${imagesDir.path}/$filename';
        }).toList();
        entry.images = newPaths;
      }
      entry.id = 0; // 重置 ID，視為新資料匯入 (避免 ID 衝突)
    }

    _dbService.restoreEntries(entries);
  }
}