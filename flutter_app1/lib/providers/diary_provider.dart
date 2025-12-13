import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/diary_entry.dart';
import '../data/services/local_db_service.dart';

// 1. 選中日期的狀態管理 (預設為今天)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

// 2. 監聽特定月份日記的 Provider
// 使用 .family 因為我們需要傳入 "哪一個月"
final monthlyDiaryProvider = StreamProvider.family<List<DiaryEntry>, DateTime>((
  ref,
  month,
) {
  // 取得資料庫實體
  final db = ref.watch(localDbServiceProvider);
  // 回傳該月份的資料流 (Stream)
  return db.watchEntriesForMonth(month);
});
