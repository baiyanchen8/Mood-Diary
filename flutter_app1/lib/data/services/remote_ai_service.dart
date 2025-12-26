import 'dart:async'; // 1. 引入 async 用來處理 TimeoutException
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mood.dart';

class RemoteAiService {
  static Future<String?> getAiQuote(
    String serverUrl,
    String content,
    Mood mood,
  ) async {
    try {
      // 改為串接 LM Studio 的 OpenAI 相容介面
      final uri = Uri.parse('$serverUrl/v1/chat/completions');

      // 設定 System Prompt 來控制 AI 的回應風格
      const systemPrompt = "你是一個情緒分析助手。請根據使用者的日記內容與心情進行回應。"
          "如果心情是正向的，請回傳一句幽默、諷刺的話讓他更開心。"
          "如果心情是負面的，請回傳一句溫暖的「心靈雞湯」安慰他。"
          "請直接回傳該句子，不要包含其他解釋。";

      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "messages": [
                {"role": "system", "content": systemPrompt},
                {"role": "user", "content": "心情: ${mood.name}\n日記內容: $content"}
              ],
              "temperature": 0.7,
            }),
          )
          .timeout(const Duration(seconds: 30)); // 2. 本地 LLM 運算較慢，建議延長至 30 秒

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // 解析 OpenAI 格式的回傳
        return data['choices'][0]['message']['content'] as String;
      } else {
        return null;
      }
    } on TimeoutException catch (_) {
      // 3. 捕捉超時錯誤
      print("AI 連線逾時 (超過 30 秒)，切換回本地模式");
      return null; // 回傳 null，讓 EditorScreen 自動切回本地
    } catch (e) {
      print("連線失敗: $e");
      return null;
    }
  }
}
