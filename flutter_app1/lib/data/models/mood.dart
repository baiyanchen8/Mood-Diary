import 'package:flutter/material.dart';

// Isar 儲存 Enum 時需要這個宣告
enum Mood {
  happy,
  sad,
  angry,
  love,
  neutral;

  // 取得中文標籤
  String get label {
    switch (this) {
      case Mood.happy:
        return '快樂';
      case Mood.sad:
        return '悲傷';
      case Mood.angry:
        return '生氣';
      case Mood.love:
        return '愛情';
      case Mood.neutral:
        return '平靜';
    }
  }

  // 取得代表色
  Color get color {
    switch (this) {
      case Mood.happy:
        return Colors.orange;
      case Mood.sad:
        return Colors.blueGrey;
      case Mood.angry:
        return Colors.redAccent;
      case Mood.love:
        return Colors.pinkAccent;
      case Mood.neutral:
        return Colors.grey;
    }
  }

  // 取得該分類下的 Emoji 選項
  List<String> get emojis {
    switch (this) {
      case Mood.happy:
        return ['😊', '😄', '😁', '😆', '🤩'];
      case Mood.sad:
        return ['😢', '😞', '😔', '😭', '🥀'];
      case Mood.angry:
        return ['😠', '😡', '🤬', '😤', '👎'];
      case Mood.love:
        return ['❤️', '😘', '😍', '🥰', '💕'];
      case Mood.neutral:
        return ['😒', '😑', '😐', '😶', '☕'];
    }
  }

  // 預設顯示在日曆上的 Emoji
  String get representativeEmoji => emojis[0];
}
