import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/models/diary_entry.dart';
import '../../providers/diary_provider.dart';
import './editor_screen.dart';

// import 'editor_screen.dart'; // 下一步才會建，先註解掉

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // 用來控制日曆目前顯示的月份
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // 1. 讀取 "目前顯示月份" 的日記資料
    final diaryListAsync = ref.watch(monthlyDiaryProvider(_focusedDay));

    // 2. 讀取使用者 "選中" 的日期
    final selectedDay = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('心情日記'), centerTitle: true),
      // 3. 處理非同步資料 (Loading / Error / Data)
      body: diaryListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('發生錯誤: $err')),
        data: (diaryList) {
          // 4. 將 List 轉為 Map<DateTime, DiaryEntry> 方便查詢
          // 這裡我們假設一天只有一篇，若有多篇取最後一篇
          final diaryMap = {
            for (var entry in diaryList)
              DateTime(entry.date.year, entry.date.month, entry.date.day):
                  entry,
          };

          return Column(
            children: [
              _buildCalendar(diaryMap, selectedDay),
              const SizedBox(height: 20),
              _buildActionArea(
                selectedDay,
                diaryMap[DateTime(
                  selectedDay.year,
                  selectedDay.month,
                  selectedDay.day,
                )],
              ),
            ],
          );
        },
      ),

      // 懸浮按鈕：快速新增今日日記
      // 在 HomeScreen 的 build 方法裡
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 跳轉到編輯頁，並帶入目前選中的日期
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(date: selectedDay)),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  // --- UI 元件拆分 ---

  Widget _buildCalendar(
    Map<DateTime, DiaryEntry> diaryMap,
    DateTime selectedDay,
  ) {
    return TableCalendar(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      currentDay: DateTime.now(),

      // 設定選中日期的樣式
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),

      // 當使用者切換月份時，更新 _focusedDay 讓 Provider 抓新資料
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },

      // 當使用者點擊日期
      onDaySelected: (selected, focused) {
        ref.read(selectedDateProvider.notifier).state = selected;
        setState(() {
          _focusedDay = focused;
        });
      },

      // *** 核心：自定義日期格子 ***
      calendarBuilders: CalendarBuilders(
        // 在日期下方顯示 Emoji (如果有日記的話)
        markerBuilder: (context, date, events) {
          // 正規化日期 (去除時分秒)
          final cleanDate = DateTime(date.year, date.month, date.day);
          final entry = diaryMap[cleanDate];

          if (entry == null) return null;

          return Positioned(
            bottom: 4,
            child: Text(
              entry.specificEmoji, // 顯示心情 Emoji
              style: const TextStyle(fontSize: 14),
            ),
          );
        },
      ),

      // 樣式微調
      headerStyle: const HeaderStyle(
        formatButtonVisible: false, // 隱藏切換週/月按鈕
        titleCentered: true,
      ),
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.orangeAccent,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.deepOrange,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // 下方動作區：顯示選中日期的資訊
  Widget _buildActionArea(DateTime selectedDay, DiaryEntry? entry) {
    if (entry != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: ListTile(
          leading: Text(
            entry.specificEmoji,
            style: const TextStyle(fontSize: 32),
          ),
          title: Text(
            entry.mood.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ), // 這裡用到 Enum 的 label
          subtitle: Text(
            entry.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          // 在 _buildActionArea 的 Card onTap 裡
          onTap: () {
            // 如果要支援「修改」，也是跳轉到 EditorScreen，但需要傳入 entry
            // 目前 MVP 先跳去新增模式 (會覆蓋舊的)，或者你可以先只做新增
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditorScreen(date: selectedDay),
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Text(
              "這一天還是一片空白...",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditorScreen(date: selectedDay),
                  ),
                );
              },
              icon: const Icon(Icons.create),
              label: const Text("開始紀錄"),
            ),
          ],
        ),
      );
    }
  }
}
