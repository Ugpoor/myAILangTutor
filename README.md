# 我的AI语言学习助手

基于 Flutter 的智能语文学习助理应用（Android 端）。应用可接收来自其它 AI Agent 应用的转发内容，经 AI 分类器解析后，自动归档到对应学习栏目，形成结构化的个人知识库。

## 核心工作流

```
其它 AI Agent App
      │
      │  Android Share Intent / Process Text
      ▼
   收件箱 (Inbox)
      │
      │  LLM 两阶段分类（大类 → 子类）
      ▼
 ┌────┴────┬──────────┬──────────┐
 ▼         ▼          ▼          ▼
错题本   习题集    知识点     作品集
```

用户在外部 AI Agent 中完成资料搜集或对话后，通过 Android 分享功能将内容转发至本应用。内容进入收件箱后，由 LLM（豆包 / 火山引擎 Ark API）进行两阶段自动分类——先判大类（错题、习题、知识点、作品），再细分具体知识点或错类——最终写入对应模块的结构化数据表，并生成 HTML 内容文件。

## 功能模块

### 收件箱（Inbox）

接收外部转发内容的主入口。支持从剪贴板粘贴、Android 分享 Intent 导入。每条收件可手动或批量进行 AI 分类，分类结果可人工修正后重新归档。分类完成后，内容被解析为结构化数据并分发到目标栏目。

### 错题本（Error Book）

管理学习中的错题记录。每条记录包含题目、错误答案、正确答案、错因分析、预防措施等字段，支持按错类大纲（如概念混淆、审题不清、计算失误等）进行层级分类和筛选。

### 习题集（Exercises）

练习和测试管理。支持试卷（Test）和题目（Question）两级结构，记录答题状态、批改结果和成绩评分。

### 知识点（Knowledge Points）

系统化知识管理。按知识点大纲（如词汇、写作手法、阅读理解等）组织，每条知识点包含内容详情、摘要、标签，并关联练习和错题记录。

### 作品集（Portfolio）

收集优秀范文和原创作品。支持 AI 点评、内容编辑，关联知识点和课程单元。

### 技能库（Skills）

AI 辅助学习工具集，分为两类：

- **内部技能**：应用内置的 AI 功能（如自动分类、内容解析、标题优化）。
- **外部命令**：预定义的提示语模板，用户可一键复制到剪贴板，粘贴到其它 AI Agent 的对话框中，指挥外部 AI Agent 按指定格式解析和搜集资料，再将结果转发回本应用。

### 效率与计划

- **效率记录**：跟踪学习效率指标。
- **学习计划**：管理日程安排和定时学习任务。
- **计时器**：番茄钟式专注计时。

### AI 对话

内置 AI 对话界面，支持推理过程展示，可与 LLM 进行学习交流。

## 技术架构

```
┌─────────────────────────────────────────────┐
│                    UI 层                     │
│  MainScreen (导航控制器) + 各功能页面         │
│  components/ (可复用 UI 组件)                 │
├─────────────────────────────────────────────┤
│                  服务层                       │
│  InboxService    — 收件箱与分类器核心逻辑      │
│  AppService      — 统一业务操作门面            │
│  LlmService      — 火山引擎 Ark API 客户端     │
│  ShareIntentService — Android 分享桥接        │
│  ConfigImporter  — 配置导入/导出              │
│  DocumentManager — 文件与目录管理              │
├─────────────────────────────────────────────┤
│                 数据层                        │
│  SQLite (sqflite) + DAO 模式                 │
│  文件系统 (HTML 内容存储)                      │
└─────────────────────────────────────────────┘
```

- **框架**：Flutter 3.x（Dart SDK ^3.11.5）
- **数据库**：SQLite（sqflite），当前版本 v33，含完整迁移历史
- **状态管理**：setState（StatefulWidget）
- **AI 接口**：火山引擎 Ark API（豆包模型），支持普通生成、结构化 JSON 输出、工具调用
- **环境配置**：flutter_dotenv（.env 文件管理 API Key）
- **导航**：命令式导航（Navigator.push + MaterialPageRoute），无路由框架

## 项目目录结构

```
myAILangTutor/
├── .env                          # API 配置（API_KEY, BASE_URL, MODEL_NAME 等）
├── pubspec.yaml                  # Flutter 依赖配置
│
├── lib/                          # 主要源码
│   ├── main.dart                 # 应用入口，加载 .env，初始化技能配置
│   │
│   ├── components/               # 可复用 UI 组件（19 个）
│   │   ├── app_title_bar.dart    #   应用标题栏
│   │   ├── ai_reply_bar.dart     #   AI 回复展示区（可折叠）
│   │   ├── chat_bubble_list.dart #   聊天气泡列表
│   │   ├── menu_grid.dart        #   主页六宫格菜单
│   │   ├── efficiency_section.dart#  效率与计划卡片
│   │   ├── input_area.dart       #   底部输入区
│   │   ├── submenu_tabs.dart     #   子菜单标签页
│   │   ├── pull_up_control.dart  #   上拉收起控件
│   │   ├── outline_editor.dart   #   大纲树编辑器
│   │   ├── html_preview.dart     #   HTML 内容预览
│   │   ├── generic_filter_dialog.dart # 通用筛选弹窗
│   │   ├── sortable_list_view.dart    # 拖拽排序列表
│   │   ├── webview_extractor.dart     # WebView 页面内容提取
│   │   ├── wysiwyg_editor.dart        # 富文本编辑器
│   │   └── ...                   #   其它样式与辅助组件
│   │
│   ├── database/                 # 数据层
│   │   ├── db_helper.dart        #   SQLite 单例帮助类（含迁移逻辑）
│   │   └── models/               #   数据模型 + DAO（16 个文件）
│   │       ├── schema.dart       #     表结构集中定义
│   │       ├── inbox_item.dart   #     收件箱条目
│   │       ├── error_record.dart #     错误记录
│   │       ├── error_type_outline.dart # 错类大纲
│   │       ├── knowledge_point.dart    # 知识点
│   │       ├── knowledge_outline.dart  # 知识点大纲
│   │       ├── test.dart         #     试卷
│   │       ├── question.dart     #     题目
│   │       ├── portfolio_item.dart     # 作品
│   │       ├── skill.dart        #     技能
│   │       ├── chat_message.dart #     聊天消息
│   │       ├── efficiency_record.dart  # 效率记录
│   │       ├── move_record.dart  #     分类移动记录
│   │       └── ...               #     其它辅助模型
│   │
│   ├── pages/                    # 页面（27 个）
│   │   ├── entry_page.dart       #   欢迎页（数据导入、初始化入口）
│   │   ├── main_screen.dart      #   主屏幕（导航控制器 + 页面栈管理）
│   │   ├── home_page.dart        #   主页（标题栏 + 菜单网格 + 输入区）
│   │   ├── chat_page.dart        #   聊天页面（对话模式）
│   │   ├── inbox_page.dart       #   收件箱列表（AI 批量分类）
│   │   ├── inbox_detail_page.dart#   收件箱详情
│   │   ├── error_record_page_simple.dart  # 错题本列表
│   │   ├── error_record_detail_page.dart  # 错题详情
│   │   ├── error_record_grouped_view.dart # 按错类分组视图
│   │   ├── hierarchical_error_view.dart   # 层级错题树
│   │   ├── error_type_outline_page.dart   # 错类大纲管理
│   │   ├── knowledge_point_page_simple.dart # 知识点列表
│   │   ├── knowledge_point_detail_page.dart # 知识点详情
│   │   ├── knowledge_outline_page.dart      # 知识点大纲管理
│   │   ├── exercises_page_simple.dart       # 习题集列表
│   │   ├── portfolio_page_simple.dart       # 作品集列表
│   │   ├── portfolio_detail_page.dart       # 作品详情
│   │   ├── skills_page_simple.dart          # 技能库列表
│   │   ├── skill_detail_page.dart           # 技能详情（提示语、参数）
│   │   ├── efficiency_record_page.dart      # 效率记录
│   │   ├── schedule_page.dart    #   学习计划
│   │   ├── timer_page.dart       #   专注计时器
│   │   ├── question_detail_page.dart  # 题目详情
│   │   └── original_editor_page.dart  # 原创内容编辑器
│   │
│   ├── services/                 # 业务逻辑服务（7 个）
│   │   ├── inbox_service.dart    #   收件箱核心：扫描、下载、AI 分类、结构化写入
│   │   ├── app_service.dart      #   统一操作门面：各模块 CRUD + 导航状态
│   │   ├── llm_service.dart      #   LLM 客户端：火山引擎 Ark API 调用
│   │   ├── share_intent_service.dart # Android 分享 Intent 桥接
│   │   ├── config_importer.dart  #   配置与数据导入/导出
│   │   ├── document_manager.dart #   文件系统文档管理
│   │   └── demo_data_initializer.dart # 演示数据初始化
│   │
│   ├── assets/                   # 课程单元 YAML 配置
│   └── scripts/                  # 辅助脚本
│
├── assets/                       # 打包静态资源
│   ├── config/                   #   默认配置 JSON
│   ├── images/                   #   图片资源
│   ├── portfolio/                #   示例作品 HTML
│   └── test_data/                #   示例数据 JSON（5 个文件）
│
├── android/                      # Android 平台代码（含 Intent 处理）
├── ios/ / macos/ / linux/ / windows/ / web/  # 其它平台
└── test/                         # 测试
```

## Android 分享接收机制

应用通过三层架构实现从其它 App 接收转发内容：

**AndroidManifest.xml** — 注册 `ACTION_SEND`、`ACTION_SEND_MULTIPLE`、`ACTION_PROCESS_TEXT` 三种 Intent Filter，使应用出现在系统分享菜单中。`launchMode="singleTop"` 确保已有实例时复用而非新建。

**MainActivity.kt** — 原生层捕获 Intent 中的 `sharedText`、`sharedTitle`、`sharedSubject`，通过 `MethodChannel("com.example.myailangtutor/share")` 暴露给 Dart 层。

**ShareIntentService（Dart）** — 单例服务，在应用启动时调用 `init()` 获取共享数据，交由 `InboxService` 创建收件箱条目。

## 数据模型概览

| 模型 | 数据表 | 核心字段 |
|------|--------|----------|
| InboxItem | inbox_items | title, source, content, category, status |
| ErrorRecord | error_records | question, wrongAnswer, correctAnswer, whyWrong, howPrevent, eids |
| ErrorTypeOutline | error_type_outlines | eid, content（层级错类分类） |
| KnowledgePoint | knowledge_points | title, brief, content, knowledgeTag, testTimes, errorTimes |
| KnowledgeOutline | knowledge_outlines | cid, content（层级知识分类） |
| Test | tests | title, examDate, totalScore, status |
| Question | questions | question, correctAnswer, answer, grading, progress |
| PortfolioItem | portfolio_items | title, contentPath, isOriginal, aiReview |
| Skill | skills | name, category(内部/外部), promptText, parameters |
| ChatMessage | chat_messages | content, reasoning, isUser |
| EfficiencyRecord | efficiency_records | title, unitCount, unitEfficiency |

## 配置文件

| 文件 | 用途 |
|------|------|
| `error_type_outlines.json` | 错类大纲（层级错类分类树） |
| `knowledge_outlines.json` | 知识点大纲（层级知识分类树） |
| `skills.json` | 技能定义（内部技能 + 外部命令模板） |
| `error_records.json` | 示例错题数据 |
| `exercises.json` | 示例习题数据 |
| `knowledge_points.json` | 示例知识点数据 |
| `portfolio_items.json` | 示例作品数据 |

错类和知识点大纲支持 SQLite 数据库与 JSON 配置文件的双向同步。首次启动从 `assets/config/` 加载默认配置，运行时修改自动回写到应用文档目录的配置文件。

## 运行项目

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 APK
flutter build apk
```
