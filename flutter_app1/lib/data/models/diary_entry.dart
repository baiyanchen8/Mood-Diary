import 'package:objectbox/objectbox.dart';
import 'mood.dart';

// ObjectBox 不需要 part '...g.dart'
// 但它會生成一個 objectbox-model.json (不用管它)

@Entity()
class DiaryEntry {
  @Id()
  int id = 0; // ObjectBox 的 ID 必須是 int 且預設為 0 (0 代表新增)

  @Index()
  late DateTime date;

  late DateTime createdAt;
  late DateTime updatedAt;

  // ObjectBox 預設不支援直接存 Enum，我們存 String 比較簡單
  // 或者可以用 int，但存 String 可讀性高
  late String moodLabel;

  // Helper: 讀取時轉回 Enum
  Mood get mood {
    return Mood.values.firstWhere(
      (e) => e.name == moodLabel,
      orElse: () => Mood.neutral,
    );
  }

  // Helper: 寫入時設定 String
  set mood(Mood value) {
    moodLabel = value.name;
  }

  late String specificEmoji;

  String? title;

  late String content;

  List<String>? images; // ObjectBox 支援 List<String>

  String? cachedQuoteContent;
}
