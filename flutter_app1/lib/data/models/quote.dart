import 'package:objectbox/objectbox.dart';

@Entity()
class Quote {
  @Id()
  int id = 0;

  @Index()
  String category; // 對應 Mood 的 name (happy, sad...)

  String content;
  String? author;

  Quote({
    required this.content,
    required this.category,
    this.author,
  });
}