import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';
import '../models/diary_entry.dart';
import '../models/quote.dart';
import '../../objectbox.g.dart'; // 這是自動生成的，等下會有

final localDbServiceProvider = Provider<LocalDbService>((ref) {
  throw UnimplementedError();
});

class LocalDbService {
  late final Store store;
  late final Box<DiaryEntry> box;
  late final Box<Quote> quoteBox;

  LocalDbService._create(this.store) {
    box = store.box<DiaryEntry>();
    quoteBox = store.box<Quote>();
  }

  static Future<LocalDbService> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    // ObjectBox 資料庫存放在 documents/objectbox 資料夾中
    final store = await openStore(directory: p.join(docsDir.path, "objectbox"));
    return LocalDbService._create(store);
  }

  // --- CRUD ---

  Future<void> saveEntry(DiaryEntry entry) async {
    entry.date = cleanDate(entry.date);
    // put: id 為 0 時新增，非 0 時更新
    box.put(entry);
  }

  DiaryEntry? getEntryByDate(DateTime date) {
    final targetDate = cleanDate(date);

    // ObjectBox 查詢語法
    // 使用 query builder
    final query = box
        .query(DiaryEntry_.date.equals(targetDate.millisecondsSinceEpoch))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  // 取得特定時間範圍內的日記
  List<DiaryEntry> getEntriesInRange(DateTime start, DateTime end) {
    // ObjectBox 查詢
    final query = box
        .query(
          DiaryEntry_.date.between(
            start.millisecondsSinceEpoch,
            end.millisecondsSinceEpoch,
          ),
        )
        .build();

    final results = query.find();
    query.close();
    return results;
  }

  List<DiaryEntry> getEntriesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final query = box
        .query(
          DiaryEntry_.date.between(
            start.millisecondsSinceEpoch,
            end.millisecondsSinceEpoch,
          ),
        )
        .build();

    final results = query.find();
    query.close();
    return results;
  }

  // ObjectBox 的 Watch 功能 (Stream)
  Stream<List<DiaryEntry>> watchEntriesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final qBuilder = box.query(
      DiaryEntry_.date.between(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
    );

    return qBuilder
        .watch(triggerImmediately: true)
        .map((query) => query.find());
  }

  void deleteEntry(int id) {
    box.remove(id);
  }

  DateTime cleanDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  // --- Backup & Restore ---
  List<DiaryEntry> getAllEntries() {
    return box.getAll();
  }

  void restoreEntries(List<DiaryEntry> entries) {
    box.putMany(entries);
  }

  // --- Quotes ---
  void addQuotes(List<Quote> quotes) {
    quoteBox.putMany(quotes);
  }
}
