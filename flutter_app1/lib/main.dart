import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // 用於日曆中文化
import 'data/services/local_db_service.dart';
import 'providers/theme_provider.dart';
import 'ui/screens/home_screen.dart'; // 等一下會建立

void main() async {
  // 1. 確保 Flutter 綁定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 初始化日期格式設定 (為了日曆顯示中文)
  await initializeDateFormatting();

  // 3. 初始化資料庫
  final dbService = await LocalDbService.init();

  runApp(
    // 4. 使用 ProviderScope 注入 dbService
    ProviderScope(
      overrides: [localDbServiceProvider.overrideWithValue(dbService)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Mood Diary',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange), // 溫暖色調
        useMaterial3: true,
        fontFamily: 'Roboto', // 或你喜歡的字體
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(), // 我們馬上要建立這個
    );
  }
}
