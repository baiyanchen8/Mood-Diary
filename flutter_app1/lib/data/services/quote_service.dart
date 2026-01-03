import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood.dart';
import '../models/quote.dart';
import 'local_db_service.dart';
import '../../objectbox.g.dart';

final quoteServiceProvider = Provider<QuoteService>((ref) {
  final dbService = ref.watch(localDbServiceProvider);
  return QuoteService(dbService);
});

class QuoteService {
  final LocalDbService _dbService;
  List<dynamic>? _builtinQuotes;

  QuoteService(this._dbService);

  Future<void> _loadBuiltinQuotes() async {
    if (_builtinQuotes != null) return;
    final jsonString = await rootBundle.loadString('assets/data/quotes.json');
    _builtinQuotes = jsonDecode(jsonString);
  }

  Future<String> getQuoteForMood(Mood mood) async {
    await _loadBuiltinQuotes();

    final moodKey = mood.name; // happy, sad...

    // 1. 撈取內建雞湯 (Assets)
    final builtinMatches = _builtinQuotes?.where((q) => q['category'] == moodKey).toList() ?? [];

    // 2. 撈取自定義雞湯 (DB)
    // 使用 ObjectBox Query
    final query = _dbService.quoteBox
        .query(Quote_.category.equals(moodKey))
        .build();
    final customMatches = query.find();
    query.close();

    // 3. 合併清單
    final allMatches = [...builtinMatches, ...customMatches];

    if (allMatches.isEmpty) {
      return "今天也要加油喔！"; // Fallback
    }

    // 4. 隨機抽選
    final random = Random();
    final selected = allMatches[random.nextInt(allMatches.length)];

    // 判斷是 Map (內建) 還是 Quote 物件 (自定義)
    if (selected is Map) {
      return selected['content'] as String;
    } else if (selected is Quote) {
      return selected.content;
    }

    return "保持微笑！";
  }
}