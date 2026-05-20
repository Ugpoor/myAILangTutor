# myAILangTutor - 我的AI语言学习助理 V2

一个基于 Flutter 开发的跨平台 AI 语言学习辅助应用，整合了收件箱、错题本、知识点管理、习题集、作品集、技能库等模块，结合大语言模型（LLM）为学生提供智能化的语文学习体验。

## 📱 项目概述

**应用名称：** 我的AI语言学习助理 V2  
**包名：** `com.example.myAILangTutor`  
**开发框架：** Flutter 3.x (SDK ^3.11.5)  
**支持语言：** 中文 (`cn`) / 英文 (`en`)  
**主要 AI 服务：** Volcengine 豆包种子模型 (doubao-seed-2-0-mini-260428)  
**本地数据库：** SQLite (sqflite) — 当前版本 v15

### 核心特性

- **双模式导航**：主页菜单模式 + AI 聊天浮层模式无缝切换
- **剪贴板集成**：自动检测系统剪贴板中的 URL，一键保存至收件箱
- **Android 分享Intent**：支持从浏览器/其他 APP 直接分享到本应用（ACTION_SEND / SEND_MULTIPLE / PROCESS_TEXT）
- **本地持久化**：所有数据存储在 SQLite 数据库，支持离线访问
- **LLM 智能生成**：自动从知识点生成练习题、对作品集进行 AI 评析、对错误记录进行订正建议

---

## 🏗️ 功能模块一览

### 主菜单模块（HomePage 首页展示）

| 序号 | 中文名称 | 英文标识 | 页面 Key | 核心功能 |
|------|---------|---------|----------|---------|
| 1 | **收件箱** | Inbox | `inbox` | 收藏网页内容、URL 文章阅读、分类管理 |
| 2 | **错误本** | Errors | `error` | 错题记录、错因分析、订正跟踪、分组查看 |
| 3 | **知识点** | Knowledge | `knowledge` | 知识卡片管理、知识谱筛选、大纲浏览、LLM 生成练习 |
| 4 | **习题集** | Exercises | `exercise` | 试卷级列表（E 开头 ID）、试题详情（EnTm 格式）、批阅订正 |
| 5 | **作品集** | Portfolio | `portfolio` | 学生习作/名篇赏析管理、富文本编辑、AI 评析自动生成 |
| 6 | **技能库** | Skills | `skills` | 内部/外部技能定义与提示语管理 |

### 二级模块

| 中文名称 | 英文标识 | 页面 Key | 核心功能 |
|---------|---------|---------|---------|
| 效率记录 | Efficiency | `efficiency` | 学习效率统计与记录 |
| 课程表 | Schedule | `schedule` | 日常学习任务排程（重复类型：日/周） |
| 计时器 | Timer | — | Pomodoro 番茄钟 |

### 工具页面

| 页面 | 功能说明 |
|------|---------|
| `llm_test_screen.dart` | LLM API 调试测试页 |
| `widget_gallery.dart` | UI 组件展示画廊 |
| `original_editor_page.dart` | HTML/富文本编辑器 |

---

## 🛠️ 技术栈

### 前端框架
- **Flutter** 3.x — 跨平台 UI 框架
- **Dart** SDK ^3.11.5

### 数据存储
- **sqflite** ^2.3.3 — SQLite 本地数据库
- **path_provider** ^2.1.3 — 文件路径获取
- **path** ^1.9.0 — 路径处理

### UI 组件
- **flutter_html** ^3.0.0 — HTML 渲染
- **flutter_markdown** ^0.6.18 — Markdown 渲染
- **webview_flutter** ^4.4.0 — WebView 嵌入
- **html** ^0.15.4 — HTML 解析

### 多媒体
- **image_picker** ^1.1.2 — 图片选择
- **video_player** ^2.8.6 — 视频播放
- **archive** ^3.4.10 — 归档处理

### 网络与其他
- **http** ^1.2.1 — HTTP 请求（LLM API 调用）
- **flutter_dotenv** ^5.1.0 — 环境变量管理

### 后端服务
- **Volcengine Doubao Seed 2.0 Mini** — 大语言模型推理

---

## 📂 项目结构

```
myAILangTutor/
├── lib/
│   ├── main.dart                          # 应用入口
│   ├── pages/                             # 页面（29 个）
│   │   ├── main_screen.dart               # 主导航容器
│   │   ├── home_page.dart                 # 首页仪表板
│   │   ├── chat_page.dart                 # AI 聊天浮层
│   │   ├── inbox_page.dart                # 收件箱列表
│   │   ├── inbox_detail_page.dart         # 收件箱详情
│   │   ├── knowledge_point_page_simple.dart     # 知识点列表
│   │   ├── knowledge_outline_page.dart          # 知识大纲
│   │   ├── knowledge_point_detail_page.dart     # 知识点详情
│   │   ├── error_record_page_simple.dart        # 错误本列表
│   │   ├── error_record_detail_page.dart        # 错误本详情
│   │   ├── error_record_grouped_view.dart       # 错误本分组视图
│   │   ├── hierarchical_error_view.dart         # 错误本层级视图
│   │   ├── exercises_page_simple.dart           # 习题集列表（试卷级）
│   │   ├── exercise_detail_page.dart            # 习题详情（试题级）
│   │   ├── paper_detail_page.dart               # 试卷详情
│   │   ├── portfolio_page_simple.dart           # 作品集列表
│   │   ├── portfolio_detail_page.dart           # 作品集详情
│   │   ├── skills_page_simple.dart              # 技能库列表
│   │   ├── skill_detail_page.dart               # 技能详情
│   │   ├── efficiency_record_page.dart          # 效率记录
│   │   ├── efficiency_record_add_page.dart      # 添加效率记录
│   │   ├── schedule_page.dart                   # 课程表
│   │   ├── schedule_add_page.dart               # 添加日程
│   │   ├── timer_page.dart                      # 计时器
│   │   ├── llm_test_screen.dart                 # LLM 调试页
│   │   ├── chat_screen.dart                     # 聊天界面变体
│   │   └── widget_gallery.dart                  # UI 组件画廊
│   ├── components/                        # 共享 UI 组件（16 个）
│   │   ├── ai_reply_bar.dart              # AI 回复气泡栏
│   │   ├── app_title_bar.dart             # 自定义标题栏
│   │   ├── chat_bubble_list.dart          # 聊天消息气泡列表
│   │   ├── colored_label.dart             # 彩色标签
│   │   ├── dynamic_tag_selector.dart      # 动态标签选择器
│   │   ├── html_preview.dart              # HTML 预览
│   │   ├── input_area.dart                # 输入区域
│   │   ├── menu_grid.dart                 # 网格菜单
│   │   ├── pull_up_control.dart           # 上拉控制
│   │   ├── rich_media_editor.dart         # 富媒体编辑器
│   │   ├── sortable_list_view.dart        # 可排序列表
│   │   ├── submenu_tabs.dart              # 底部标签栏
│   │   ├── webview_extractor.dart         # WebView 内容提取器
│   │   └── wysiwyg_editor.dart            # 所见即所得编辑器
│   ├── database/
│   │   ├── db_helper.dart                 # SQLite 数据库助手
│   │   ├── models/                        # 数据模型（13 个）
│   │   │   ├── exam_paper.dart            # 试卷模型（E 开头）
│   │   │   ├── exercise.dart              # 习题模型（EnTm 格式）
│   │   │   ├── error_record.dart          # 错误记录模型
│   │   │   ├── knowledge_point.dart       # 知识点模型
│   │   │   ├── portfolio_item.dart        # 作品集模型
│   │   │   ├── skill.dart                 # 技能模型
│   │   │   ├── inbox_item.dart            # 收件箱模型
│   │   │   ├── chat_message.dart          # 聊天消息模型
│   │   │   ├── efficiency_record.dart     # 效率记录模型
│   │   │   ├── document.dart              # 文档模型
│   │   │   ├── setting.dart               # 设置模型
│   │   │   ├── todo_item.dart             # TODO 模型
│   │   │   └── schema.dart                # 数据库 Schema 定义
│   │   └── db_helper.dart                 # 数据库操作封装
│   ├── services/                          # 业务逻辑服务（6 个）
│   │   ├── app_service.dart               # 核心应用服务
│   │   ├── demo_data_initializer.dart     # 演示数据初始化
│   │   ├── document_manager.dart          # 文件管理
│   │   ├── inbox_service.dart             # 收件箱业务逻辑
│   │   ├── llm_service.dart               # LLM API 调用
│   │   └── share_intent_service.dart      # Android 分享意图处理
│   ├── scripts/                           # 数据生成脚本
│   │   └── generate_exercises.dart        # 批量生成练习题脚本
│   └── assets/                            # 静态资源
│       ├── images/                        # 图片资源
│       ├── lesson_units_grade4.yaml       # 四年级课内单元数据
│       └── .env                           # 环境变量（LLM 配置）
├── android/                               # Android 原生配置
│   └── app/src/main/
│       ├── AndroidManifest.xml            # Android 清单
│       └── res/                           # Android 资源
├── ios/                                   # iOS 原生配置
├── pubspec.yaml                           # 依赖声明
├── .env                                   # 环境变量（含 API Key）
└── README.md                              # 项目说明文档
```

---

## 🚀 快速开始

### 前置要求

1. **Android Studio**（推荐最新版）
2. **Flutter SDK** >= 3.11.5
3. **Dart SDK**（随 Flutter 一并安装）
4. **Java JDK 17**（构建 Android 应用）
5. **Android SDK**（Min SDK 23，Target SDK 按需）

### 安装 Flutter SDK

#### macOS

```bash
# 方法一：通过 Homebrew
brew install --cask flutter

# 方法二：手动下载
# 1. 访问 https://docs.flutter.dev/release
# 2. 下载最新稳定版 Flutter SDK
# 3. 解压到指定目录
unzip ~/Downloads/flutter_macos_*.zip -d ~/development
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

#### Windows

```powershell
# 手动下载安装包
# 1. 访问 https://docs.flutter.dev/release
# 2. 下载 Windows Flutter SDK ZIP
# 3. 解压到 C:\src\flutter
# 4. 将 C:\src\flutter\bin 添加到系统 PATH
```

### 验证安装

```bash
flutter doctor
```

根据输出结果安装缺失的组件，重点关注：

```
[✓] Flutter (channel stable, ...)
    - Framework • revision xxx
    - Engine • revision xxx
    - Tools • Dart 3.x.x
    - DevTools • 2.x.x

[✓] Android toolchain — develop for Android devices
    - Android SDK at ...
    - Android NDK at ...

[✓] Android Studio (version x.x)
    - Flutter plugin installed
    - Dart plugin version xxxxxxxx
```

### Android Studio 插件安装

1. 打开 Android Studio → **Settings/Preferences** → **Plugins**
2. 搜索 **Flutter** → 安装 Google 官方 Flutter 插件
3. 搜索 **Dart** → 安装 Dart 语言支持插件
4. 重启 IDE

### 克隆并初始化项目

```bash
# 克隆仓库
git clone <repository-url>
cd myAILangTutor

# 获取依赖
flutter pub get

# 检查项目状态
flutter doctor
```

---

## ⚙️ 环境配置

### LLM API 配置

项目使用 `flutter_dotenv` 管理敏感配置。请创建 `.env` 文件在项目根目录：

```env
API_KEY=your_api_key_here
BASE_URL=https://ark.cn-beijing.volces.com/api/v3
MODEL_NAME=doubao-seed-2-0-mini-260428
MAX_TOKENS=256000
TEMPERATURE=0.7
```

**配置说明：**

| 变量名 | 说明 | 示例值 |
|--------|------|--------|
| `API_KEY` | Volcengine 平台的 API 密钥 | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `BASE_URL` | LLM API 端点地址 | `https://ark.cn-beijing.volces.com/api/v3` |
| `MODEL_NAME` | 使用的模型名称 | `doubao-seed-2-0-mini-260428` |
| `MAX_TOKENS` | 单次响应最大 token 数 | `256000` |
| `TEMPERATURE` | 随机性（0-1，越高越有创造性） | `0.7` |

**获取 API Key：**
1. 登录 [火山引擎控制台](https://console.volcengine.com/)
2. 进入「大模型推理 BCC」服务
3. 创建接入点（Endpoint），选择模型 `doubao-seed-2-0-mini-260428`
4. 生成 API Key

### 数据安全

⚠️ **切勿将 `.env` 文件提交到 Git 仓库！** 建议在 `.gitignore` 中已排除该文件。

如需分享项目模板，可提供 `.env.example`：

```env
# 复制此文件为 .env 并填入你的 API Key
API_KEY=your_api_key_here
BASE_URL=https://ark.cn-beijing.volces.com/api/v3
MODEL_NAME=doubao-seed-2-0-mini-260428
MAX_TOKENS=256000
TEMPERATURE=0.7
```

---

## 💻 运行与调试

### 连接设备

#### 方式一：真机调试

1. 开启安卓手机的 **开发者选项**：设置 → 关于手机 → 连续点击「版本号」7 次
2. 启用 **USB 调试**：设置 → 开发者选项 → USB 调试
3. 通过 USB 连接手机，授权电脑调试
4. 在终端验证设备连接：

```bash
adb devices
```

应显示类似：

```
List of devices attached
XXXXXX    device
```

#### 方式二：虚拟机（AVD）调试

1. 打开 Android Studio → **Tools** → **Device Manager**
2. 点击 **Create Virtual Device**
3. 选择设备轮廓（如 Pixel 6、Pixel 7 等）
4. 选择系统镜像（推荐 **System Image** 带 Google Play 的版本）
5. 完成配置，点击 **Finish**
6. 启动模拟器

**推荐配置：**
- **设备：** Pixel 6 / Pixel 7 / Pixel Tablet
- **系统镜像：** Android 13 (API 33) 或 Android 14 (API 34)
- **RAM：** 至少 2048 MB（推荐 4096 MB）
- **内部存储：** 至少 8 GB

### 运行应用

#### 通过命令行

```bash
# 查看所有可用的目标设备
flutter devices

# 运行到第一个可用设备
flutter run

# 指定设备运行（通过设备 ID）
flutter run -d <device-id>

# Release 模式构建（性能更好）
flutter run --release

# Debug 模式构建（支持断点调试，默认）
flutter run --debug

# Profile 模式（性能分析）
flutter run --profile
```

#### 通过 Android Studio

1. 打开项目根目录
2. 确保 `.env` 文件存在于项目根目录
3. 顶部工具栏选择目标设备
4. 点击绿色 **Run** 按钮（或按 `Shift + F10`）

### 热重载与热重启

在运行中的应用：

| 快捷键 | 效果 |
|--------|------|
| `r` | 热重载（Hot Reload）— 保持状态，快速刷新 UI |
| `R` | 热重启（Hot Restart）— 重置状态，完整重启 |
| `q` | 退出调试会话 |

---

## 📦 构建 APK

### Debug APK（用于调试和测试）

```bash
flutter build apk --debug
```

输出位置：`build/app/outputs/flutter-apk/app-debug.apk`

### Release APK（用于分发）

```bash
flutter build apk --release
```

输出位置：`build/app/outputs/flutter-apk/app-release.apk`

### Split APK（按 ABI 拆分，减小体积）

```bash
flutter build apk --split-per-abi
```

生成三个 APK：
- `app-armeabi-v7a-release.apk` — 32 位 ARM
- `app-arm64-v8a-release.apk` — 64 位 ARM（现代手机首选）
- `app-x86_64-release.apk` — 64 位 x86_64（模拟器）

### AAB（Android App Bundle，上传到 Google Play）

```bash
flutter build appbundle
```

输出位置：`build/app/outputs/bundle/release/app-release.aab`

### 安装 APK 到设备

```bash
# 安装 debug APK
adb install build/app/outputs/flutter-apk/app-debug.apk

# 覆盖安装
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🗄️ 数据库结构

### 数据库文件位置

```
data/myAILangTutor.db   （SQLite 数据库文件）
```

### 数据表总览（v15）

| 表名 | 模型类 | 说明 |
|------|--------|------|
| `exam_papers` | `ExamPaper` | 试卷（E 开头 ID，如 E1, E2） |
| `exercises` | `Exercise` | 习题（EnTm 格式，如 E2T3） |
| `error_records` | `ErrorRecord` | 错误记录 |
| `knowledge_points` | `KnowledgePoint` | 知识点 |
| `portfolio_items` | `PortfolioItem` | 作品集 |
| `skills` | `Skill` | 技能 |
| `inbox_items` | `InboxItem` | 收件箱 |
| `chat_messages` | `ChatMessage` | 聊天记录 |
| `efficiency_records` | `EfficiencyRecord` | 效率记录 |
| `schedule_items` | `ScheduleItem` | 日程安排 |
| `documents` | `Document` | 文档 |
| `settings` | `Setting` | 应用设置 |
| `todo_items` | `TodoItem` | TODO 任务 |

### 关键字段设计

#### 习题集两层结构

```
试卷级（exam_papers 表）       试题级（exercises 表）
┌─────────────────────┐     ┌──────────────────────────┐
│ paper_id: "E1"      │◄──┼─►│ exercise_id: "E1T1"     │
│ title: "第一次月考"   │     │ exercise_id: "E1T2"     │
│ subject: "语文"      │     │ exercise_id: "E1T3"     │
│ status: "已完成"     │     │ paper_id: "E1" (外键)   │
└─────────────────────┘     └──────────────────────────┘
```

#### 知识点父子关系

```sql
-- 通过 father_id 实现树形层级
knowledge_points:
  id: 1, title: "近义词辨析", father_id: NULL  -- 根节点
  id: 2, title: "语素分析法", father_id: 1    -- 子节点
  id: 3, title: "语境代入法", father_id: 1    -- 子节点
```

### 数据库迁移历史

| 版本 | 变更内容 |
|------|---------|
| v1 | 初始建表 |
| v2-v3 | 添加 chat_messages、inbox_items 表 |
| v4 | 添加 efficiency_records 表 |
| v7 | 添加 schedule_items 表 |
| v8-v9 | 效率记录和知识点表完善 |
| v10 | error_records/exercises/portfolio/skills 扩充字段 |
| v11 | exercises 添加 source 字段 |
| v12 | exercises 添加 source 字段（修正） |
| v13 | skills/knowledge_points 添加 content_path/cid/father_id |
| v14 | portfolio_items 添加 content 字段（文章正文） |
| v15 | 新建 exam_papers 表，exercises 添加 paper_id 关联 |

---

## 🧪 调试技巧

### 日志输出

```dart
// 标准输出
print('Debug message');

// Flutter 调试工具
debugPrint('Debug message');

// 条件断点
assert(someCondition, 'Some condition failed');
```

### DevTools

启动 Flutter DevTools：

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

或在 Android Studio 中：
- **Run** → **Start Flutter DevTools**

### 常见问题排查

| 问题 | 解决方案 |
|------|---------|
| `flutter command not found` | 检查 PATH 环境变量，重启终端 |
| `No devices detected` | 运行 `flutter devices`，确认 USB 调试已开启 |
| `Gradle build failed` | 检查 Java JDK 版本是否为 17 |
| `LLM API 调用失败` | 检查 `.env` 文件中 API_KEY 是否正确 |
| `热重载不生效` | 尝试热重启（大写 R）或完全重启应用 |
| `数据库升级失败` | 删除旧数据库重新初始化（测试阶段） |

---

## 📝 开发指南

### 添加新页面

1. 在 `lib/pages/` 目录下创建新页面文件
2. 确保页面继承自 `StatefulWidget` 或 `StatelessWidget`
3. 在 `main_screen.dart` 中添加路由逻辑
4. 在 `HomePage` 菜单中添加入口

### 添加新数据模型

1. 在 `lib/database/models/` 下创建模型文件
2. 实现 `toMap()` 和 `fromMap()` 方法
3. 在 `schema.dart` 中添加 Schema 定义
4. 在 `db_helper.dart` 中添加迁移逻辑（升级版本号）
5. 创建对应的 DAO 类

### 添加新功能服务

1. 在 `lib/services/` 下创建服务文件
2. 实现业务逻辑方法
3. 在需要使用的页面中实例化服务
4. 如需 LLM 调用，使用 `LlmService.generateResponse(prompt)`

---

## 🔒 安全注意事项

1. **不要在代码中硬编码 API Key** — 始终使用 `.env` 文件
2. **不要将 `.env` 提交到版本控制** — 确保 `.gitignore` 中包含 `.env`
3. **Release 模式下禁用调试接口** — Flutter 默认行为已在 Release 中禁用
4. **用户数据本地存储** — 所有数据存储在设备本地，不上传服务器

---

## 📄 License

本项目仅供学习和内部使用。

---

## 👥 联系方式

如有问题或建议，请联系项目维护者。

---

**最后更新：** 2026-05-20
