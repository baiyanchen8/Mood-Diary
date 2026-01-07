這份規格書是根據您上傳的原始碼（Repo: `baiyanchen8/mood-diary`）以及 `README.md` 和 `pubspec.yaml` 的實際內容進行重寫的。

目前的專案狀態已經超越了原本的 MVP（最小可行性產品）規劃，包含了更完整的 AI 整合、資料備份機制以及遊戲化元素。

以下是更新後的專案規格書：

---

# 專案規格書 (Project Specification) - Rev. 2.0

**專案名稱:** Mood Diary (心情日記)
**平台:** Cross-Platform (Android / iOS / Windows / Linux)
**版本:** v0.1.0
**核心價值:** 本地優先 (Local-First)、隱私安全 (Privacy)、AI 情感陪伴 (AI Companionship)。

---

## 1. 使用者流程 (User Flow)

```mermaid
graph TD
    Start[開啟 App] --> HomeScreen[首頁: 月曆視圖]

    subgraph View_Flow [瀏覽與管理]
        HomeScreen --> |點擊日期| DetailScreen[日記詳情頁]
        DetailScreen --> |編輯| EditorScreen
        HomeScreen --> |導覽列| StatsScreen[統計與回顧]
        StatsScreen --> |遊玩| MoodJarGame[情緒瓶小遊戲]
        HomeScreen --> |設定| SettingsScreen[設定頁]
    end

    subgraph Write_Flow [撰寫日記]
        HomeScreen --> |+號按鈕| EditorScreen[編輯頁]
        EditorScreen --> |1. 撰寫| InputText[Markdown / 圖片]
        EditorScreen --> |2. 選擇| MoodSelect[情緒選擇器]
        MoodSelect --> |3. 儲存| SaveAction[寫入 ObjectBox]
        SaveAction --> |觸發| AILogic[雞湯生成 (本地/雲端)]
        AILogic --> |回饋| FeedbackDialog[顯示 AI 安慰/語錄]
    end

    subgraph Settings_Flow [系統設定]
        SettingsScreen --> AI_Config[AI 供應商設定 (Gemini/OpenAI/Local)]
        SettingsScreen --> Data_Manage[備份與還原 (ZIP)]
        SettingsScreen --> Quote_Manage[語錄庫管理 (匯入 JSON)]
    end

```

---

## 2. 功能需求 (Functional Requirements)

### 2.1 首頁 (Home / Calendar)

* **月曆元件:** 使用 `table_calendar` 顯示。
* **狀態呈現:**
* **有日記:** 顯示該日記選定的 **「具體 Emoji」** (如 😊, 🤬)。
* **今日:** 特殊高亮標記。


* **導航:** 底部或頂部導航欄，連接「首頁」、「統計」、「設定」。

### 2.2 編輯頁 (Editor)

* **富文本編輯:**
* 支援 Markdown 語法 (粗體、標題等)。
* **圖片插入:** 支援從相簿選取圖片，將圖片檔案複製到 App `ApplicationDocumentsDirectory` 本地沙盒中，資料庫僅存相對路徑。


* **心情選擇器:** 選擇五大類情緒 (Happy, Sad, Angry, Love, Neutral) 及其對應的子 Emoji。
* **即時回饋:** 儲存後立即觸發 AI 或語錄回饋。

### 2.3 統計與遊戲 (Stats & Game)

* **情緒分佈:** 使用 `fl_chart` (Pie Chart) 顯示本月或整體的快樂、悲傷等情緒比例。
* **情緒瓶遊戲 (Mood Jar):**
* 基於 `flame` 與 `flame_forge2d` 物理引擎開發。
* 將使用者的情緒 Emoji 變成物理實體掉落瓶中，提供趣味性的視覺回饋。



### 2.4 AI 雞湯與回饋系統 (AI & Quotes)

* **雙模式運作:**
1. **本地模式 (Local):** 隨機讀取內建或匯入的 JSON 語錄庫。
2. **AI 模式 (Remote/Local LLM):** 根據日記內容進行語意分析，生成客製化安慰。


* **多供應商支援 (Multi-Provider):**
* **Google Gemini:** 透過 `google_generative_ai` 串接。
* **OpenAI:** 透過 HTTP 呼叫 GPT 模型。
* **Local LLM:** 支援串接 LM Studio (本地 Server)。



### 2.5 資料管理 (Data Management)

* **備份 (Export):** 將資料庫 (`data.mdb`) 與所有圖片資源打包成 `.zip` 檔。
* **還原 (Import):** 解壓縮 `.zip` 檔並覆蓋本地資料，支援跨裝置遷移。
* **語錄擴充:** 支援匯入外部 JSON 檔案以擴充本地語錄庫。

---

## 3. 資料結構 (Data Model)

### 3.1 資料庫技術

* **Engine:** **ObjectBox** (NoSQL, 高效能本地資料庫)。
* **Schema:** 定義於 `lib/objectbox-model.json`。

### 3.2 實體定義 (Entity)

**Mood (Enum):**
定義於 `lib/data/models/mood.dart`

* 包含：`happy`, `sad`, `angry`, `love`, `neutral`。
* 屬性：顏色值、顯示標籤、Emoji 集合。

**DiaryEntry (ObjectBox Entity):**
定義於 `lib/data/models/diary_entry.dart`

```dart
@Entity()
class DiaryEntry {
  @Id()
  int id = 0; // ObjectBox 預設 ID 格式

  @Index()
  DateTime date; // 日記日期

  DateTime createdAt;
  DateTime updatedAt;

  // 儲存 Mood Enum 的 index 或 String
  String moodLabel; 
  String specificEmoji; // 使用者選的具體 Emoji

  String? title;
  String content; // Markdown 內容

  List<String> images; // 圖片路徑列表 (JSON String 或 StringList)

  String? aiFeedback; // 獲得的 AI 回饋或語錄
}

```

**Quote (ObjectBox Entity):**
定義於 `lib/data/models/quote.dart`

* 用於儲存內建及外部匯入的語錄，方便統一管理與隨機抽取。

---

## 4. 技術堆疊 (Technical Stack)

* **Framework:** Flutter (Dart SDK ^3.0)
* **State Management:** `flutter_riverpod` ^2.5.1
* **Local Database:** `objectbox` ^2.4.0 (取代了 Isar)
* **AI Integration:**
* `google_generative_ai`: Gemini API 官方套件。
* `http`: 用於 OpenAI / LM Studio REST API。


* **UI/UX Components:**
* `table_calendar`: 日曆視圖。
* `flutter_markdown`: 內容渲染。
* `fl_chart`: 圓餅圖統計。
* `flame` & `flame_forge2d`: 物理遊戲引擎。


* **System/IO:**
* `image_picker`: 圖片選取。
* `path_provider`: 檔案路徑管理。
* `archive`: ZIP 壓縮與解壓縮 (備份用)。
* `file_picker`: 檔案選取 (匯入備份/語錄)。
* `flutter_secure_storage`: 安全儲存 AI API Keys。
* `share_plus`: 系統分享功能。



---

## 5. UI 設計風格 (Design Guidelines)

* **配色:** 溫暖療癒色系，根據 Mood Enum 動態調整部分 UI 顏色。
* **Icons:** Material Icons + 系統原生 Emoji。
* **平台適配:**
* Android/iOS: 手機版面佈局。
* Windows/Linux/macOS: 視窗化支援 (由 Flutter Desktop 提供)。



---

## 6. 當前開發進度 (Current Status)

根據程式碼庫分析，以下功能 **已完成 (Implemented)**：

1. ✅ **基礎架構**: Riverpod + ObjectBox 資料庫建置。
2. ✅ **日記核心**: 日曆瀏覽、Markdown 編輯、圖片插入、情緒選擇。
3. ✅ **進階 AI**:
* 整合 Google Gemini, OpenAI, Local LLM。
* 設定頁面可切換 Provider 並輸入 API Key。


4. ✅ **資料安全**:
* 完整的備份 (ZIP Export) 與還原機制。
* Secure Storage 儲存金鑰。


5. ✅ **統計與遊戲**:
* Stats Screen 圓餅圖。
* Mood Jar 物理掉落小遊戲。


6. ✅ **語錄管理**: 支援從 `assets` 讀取及外部 JSON 匯入。

---

## 7. 未來優化方向 (Future Roadmap)

1. **雲端同步 (Cloud Sync):**
* 目前僅支援本地 ZIP 備份，未來可考慮整合 Google Drive API 進行自動雲端備份。


2. **生物辨識鎖 (Biometric Lock):**
* 新增 App 鎖定功能 (FaceID / 指紋)，進一步保護隱私。


3. **多語言支援 (i18n):**
* 目前介面主要為繁體中文，可增加英文或其他語言支援。


4. **匯出 PDF/圖片:**
* 利用 `screenshot` 套件將單篇日記生成精美卡片圖片分享 (程式碼中已有依賴，可持續優化 UI)。
