import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/ai_service.dart';

class AiState {
  final AiProviderType provider;
  final String localUrl;
  final String openAiKey;
  final String geminiKey;
  final String geminiModelName;

  AiState({
    this.provider = AiProviderType.local,
    this.localUrl = 'http://10.0.2.2:1234',
    this.openAiKey = '',
    this.geminiKey = '',
    this.geminiModelName = 'gemini-pro',
  });

  AiState copyWith({
    AiProviderType? provider,
    String? localUrl,
    String? openAiKey,
    String? geminiKey,
    String? geminiModelName,
  }) {
    return AiState(
      provider: provider ?? this.provider,
      localUrl: localUrl ?? this.localUrl,
      openAiKey: openAiKey ?? this.openAiKey,
      geminiKey: geminiKey ?? this.geminiKey,
      geminiModelName: geminiModelName ?? this.geminiModelName,
    );
  }
}

class AiNotifier extends StateNotifier<AiState> {
  final _storage = const FlutterSecureStorage();
  
  AiNotifier() : super(AiState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex = prefs.getInt('ai_provider_index') ?? 0;
    final localUrl = prefs.getString('ai_local_url') ?? 'http://10.0.2.2:1234';
    
    // 從安全儲存區讀取 Key
    final openAiKey = await _storage.read(key: 'openai_key') ?? '';
    final geminiKey = await _storage.read(key: 'gemini_key') ?? '';
    final geminiModelName = prefs.getString('gemini_model_name') ?? 'gemini-pro';

    state = AiState(
      provider: AiProviderType.values[providerIndex],
      localUrl: localUrl,
      openAiKey: openAiKey,
      geminiKey: geminiKey,
      geminiModelName: geminiModelName,
    );
  }

  Future<void> setProvider(AiProviderType provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_provider_index', provider.index);
    state = state.copyWith(provider: provider);
  }

  Future<void> setLocalUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_local_url', url);
    state = state.copyWith(localUrl: url);
  }

  Future<void> setOpenAiKey(String key) async {
    await _storage.write(key: 'openai_key', value: key);
    state = state.copyWith(openAiKey: key);
  }

  Future<void> setGeminiKey(String key) async {
    await _storage.write(key: 'gemini_key', value: key);
    state = state.copyWith(geminiKey: key);
  }

  Future<void> setGeminiModelName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_model_name', name);
    state = state.copyWith(geminiModelName: name);
  }
}

final aiProvider = StateNotifierProvider<AiNotifier, AiState>((ref) => AiNotifier());

/// 根據設定自動產生對應的 Service 實體
final aiServiceProvider = Provider<AiService>((ref) {
  final state = ref.watch(aiProvider);
  switch (state.provider) {
    case AiProviderType.local: return LocalAiService(state.localUrl);
    case AiProviderType.openai: return OpenAiService(state.openAiKey);
    case AiProviderType.gemini: return GeminiAiService(state.geminiKey, state.geminiModelName);
  }
});