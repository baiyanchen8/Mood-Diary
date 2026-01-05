import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mood.dart';
import 'remote_ai_service.dart'; // 引用既有的服務

enum AiProviderType { local, openai, gemini }

/// AI 服務介面 (Strategy Interface)
abstract class AiService {
  Future<String?> getQuote(String content, Mood mood);
}

/// 1. 本地 LM Studio 實作
class LocalAiService implements AiService {
  final String serverUrl;
  LocalAiService(this.serverUrl);

  @override
  Future<String?> getQuote(String content, Mood mood) {
    // 直接呼叫既有的 RemoteAiService 邏輯
    return RemoteAiService.getAiQuote(serverUrl, content, mood);
  }
}

/// 2. OpenAI 實作
class OpenAiService implements AiService {
  final String apiKey;
  OpenAiService(this.apiKey);

  @override
  Future<String?> getQuote(String content, Mood mood) async {
    if (apiKey.isEmpty) return null;
    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // 或 gpt-4o-mini
          'messages': [
            {'role': 'system', 'content': '你是一個富有同理心的心理諮商師。請根據使用者的日記內容與心情，給予一句簡短、溫暖且具有力量的雞湯語錄（繁體中文，不超過50字）。'},
            {'role': 'user', 'content': '心情：${mood.label}\n日記：$content'}
          ],
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('OpenAI Error: $e');
    }
    return null;
  }
}

/// 3. Google Gemini 實作
class GeminiAiService implements AiService {
  final String apiKey;
  final String modelName;
  GeminiAiService(this.apiKey, this.modelName);

  @override
  Future<String?> getQuote(String content, Mood mood) async {
    if (apiKey.isEmpty) return null;
    try {
      // 使用使用者設定的模型名稱
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      final prompt = '你是一個富有同理心的心理諮商師。請根據使用者的日記內容與心情，給予一句簡短、溫暖且具有力量的雞湯語錄（繁體中文，不超過50字）。\n心情：${mood.label}\n日記：$content';
      
      // 加入 30 秒超時設定，避免因網路延遲導致無回應
      final response = await model.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 30));
          
      return response.text;
    } on TimeoutException catch (_) {
      print('Gemini Error: 連線逾時 (Timeout)，請檢查網路狀況。');
    } catch (e) {
      print('Gemini Error: $e');
      if (e.toString().contains('403')) {
        print('⚠️ 權限錯誤: 請檢查 API Key 是否設定了 "Android 應用程式限制"。請先改為 "無限制 (None)" 進行測試。');
      }
    }
    return null; 
  }
}