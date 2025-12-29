import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart'; // 存圖用
import 'package:screenshot/screenshot.dart'; // 截圖用
import 'package:share_plus/share_plus.dart'; // 分享用
import '../../providers/stats_provider.dart';
import '../widgets/mood_pie_chart.dart';
import '../widgets/mood_jar_game.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  // 1. Tab 控制器 (用來判斷現在是哪一頁)
  late TabController _tabController;

  // 2. 截圖控制器 (兩個分開，避免衝突)
  final ScreenshotController _chartController = ScreenshotController();
  final ScreenshotController _jarController = ScreenshotController();

  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // 初始化 TabController，長度為 2 (圖表、罐子)
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- 分享邏輯 ---
  Future<void> _shareCurrentView() async {
    setState(() => _isSharing = true);

    try {
      // A. 判斷現在是哪一頁，決定用哪個控制器
      final isChartTab = _tabController.index == 0;
      final controller = isChartTab ? _chartController : _jarController;
      final fileName = isChartTab ? 'mood_chart.png' : 'mood_jar.png';

      // B. 截取當前畫面 (capture)
      // 使用 capture() 而非 captureFromWidget()，是為了確保截到的是
      // 罐子裡 Emoji "堆疊好" 的樣子，而不是重新生成的初始狀態。
      final imageBytes = await controller.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );

      if (imageBytes == null) {
        throw Exception("截圖失敗");
      }

      // C. 存檔並分享
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/$fileName').create();
      await imagePath.writeAsBytes(imageBytes);
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: isChartTab ? '我的心情分佈 📊' : '我的情緒罐子 🫙',sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(moodStatsProvider);
    final timeRange = ref.watch(timeRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('心情統計'),
        actions: [
          // 分享按鈕 (新增)
          if (!statsAsync.isLoading && !statsAsync.hasError) // 只有資料載入完成才顯示
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              onPressed: _isSharing ? null : _shareCurrentView,
              tooltip: "分享統計圖",
            ),

          // 切換時間範圍
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<TimeRange>(
              value: timeRange,
              underline: const SizedBox(),
              icon: const Icon(Icons.calendar_today),
              items: const [
                DropdownMenuItem(value: TimeRange.week, child: Text("最近 7 天")),
                DropdownMenuItem(
                  value: TimeRange.month,
                  child: Text("最近 30 天"),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(timeRangeProvider.notifier).state = value;
                }
              },
            ),
          ),
        ],
        // 將 TabBar 移到 AppBar 底部，這是標準 Material Design 寫法
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: "情緒佔比"),
            Tab(icon: Icon(Icons.local_drink), text: "情緒罐"),
          ],
          labelColor: Colors.orange,
          indicatorColor: Colors.orange,
        ),
      ),

      // 使用 TabBarView 配合 Controller
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("還沒有足夠的資料來統計喔！", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // 禁止左右滑動切換，避免誤觸且方便截圖
            children: [
              // Tab 1: 圓餅圖
              Screenshot(
                controller: _chartController,
                child: Container(
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor, // 截圖需要背景色，不然是黑的
                  padding: const EdgeInsets.all(24.0),
                  alignment: Alignment.center,
                  child: MoodPieChart(entries: entries),
                ),
              ),

              // Tab 2: 物理罐
              Screenshot(
                controller: _jarController,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor, // 截圖背景色
                  alignment: Alignment.center,
                  child: Container(
                    width: 300,
                    height: 500,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 4),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(32),
                      ),
                      color: Colors.white.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                      child: MoodJarWidget(entries: entries),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
