import 'package:objectbox/objectbox.dart';
import 'mood.dart';

// ObjectBox 不需要 part '...g.dart'
// 但它會生成一個 objectbox-model.json (不用管它)

@Entity()
class DiaryEntry {
  @Id()
  int id = 0; // ObjectBox 的 ID 必須是 int 且預設為 0 (0 代表新增)

  // ObjectBox 需要一個預設建構子 (或所有欄位可選的建構子)
  DiaryEntry();

  // 應用程式端使用的建構子，負責初始化與正規化
  DiaryEntry.create({
    required DateTime date,
    required Mood mood,
    required this.content,
    required this.specificEmoji,
    this.title,
    this.images,
    this.cachedQuoteContent,
  }) {
    // 強制將日期正規化為當天的 00:00:00，避免因時間不同造成查詢錯誤
    this.date = DateTime(date.year, date.month, date.day);
    this.mood = mood; // 使用 setter 設定 moodLabel
    this.createdAt = DateTime.now();
    this.updatedAt = DateTime.now();
  }

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

  // --- JSON 序列化 (用於備份) ---
  Map<String, dynamic> toJson() => {
        'date': date.millisecondsSinceEpoch,
        'moodLabel': moodLabel,
        'content': content,
        'specificEmoji': specificEmoji,
        'title': title,
        'images': images, // 這裡先存原始路徑，BackupService 會負責處理成相對路徑
        'cachedQuoteContent': cachedQuoteContent,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final entry = DiaryEntry()
      ..date = DateTime.fromMillisecondsSinceEpoch(json['date'])
      ..moodLabel = json['moodLabel']
      ..content = json['content']
      ..specificEmoji = json['specificEmoji']
      ..title = json['title']
      ..images = (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList()
      ..cachedQuoteContent = json['cachedQuoteContent']
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt']);
    return entry;
  }
}
