# 我的AI语言学习助手

一个基于Flutter的智能语文学习助手应用。

## 功能特性

- 📚 **错题本** - 记录和管理学习中的错题，支持错类分类
- 📝 **作品集** - 收集和整理优秀文章和原创作品
- 📖 **知识点** - 系统化学习和复习语文知识点
- 📋 **习题集** - 练习和测试语文知识
- 📥 **收件箱** - 收集和整理待处理的学习内容
- ⚡ **技能库** - AI辅助学习功能

## 核心数据结构

### 1. 错类大纲 (ErrorTypeOutline)

用于对错误记录进行分类管理的层级结构。

**字段说明：**
| 字段 | 类型 | 说明 |
|------|------|------|
| eid | String | 错类唯一标识（格式：E+数字，如 E1） |
| fid | String | 父错类ID（空字符串表示顶级分类） |
| content | String | 错类名称/描述 |
| lang | String | 语言标识（cn/en） |

**示例结构：**
```
E1 概念混淆
├── E6 近义词辨析错误
└── E7 形近字混淆
E2 审题不清
├── E8 关键词忽略
└── E9 会错题意
E3 计算失误
E4 知识遗漏
E5 推理错误
```

### 2. 知识点大纲 (KnowledgeOutline)

用于组织和管理知识点的层级结构。

**字段说明：**
| 字段 | 类型 | 说明 |
|------|------|------|
| cid | String | 大纲分类唯一标识 |
| fid | String | 父分类ID（空字符串表示顶级分类） |
| content | String | 大纲内容/名称 |
| lang | String | 语言标识（cn/en） |

**示例结构：**
```
vocabulary 词汇
├── synonym 近义词辨析
└── antonym 反义词运用
writing_method 写作手法
├── metaphor 借物喻人
└── contrast 对比手法
reading 阅读理解
├── main_idea 主旨归纳
└── inference 推理判断
```

### 3. 错误记录 (ErrorRecord)

记录每次错误的详细信息。

**字段说明：**
| 字段 | 类型 | 说明 |
|------|------|------|
| errorId | String | 错误记录唯一标识 |
| eids | List\<String\> | 关联的错类ID列表（支持多错类） |
| wrongWhere | String | 错在哪里（条目标题） |
| question | String | 题目内容 |
| wrongAnswer | String | 错误答案 |
| correctAnswer | String | 正确答案 |
| whyWrong | String | 为什么错 |
| howPrevent | String | 如何预防 |
| kid | String | 关联的知识点ID |
| tid/qid | String | 关联的试卷/题目ID |

## 配置文件同步机制

### 错类和知识点大纲的双向同步

应用支持错类大纲和知识点大纲的配置文件双向同步：

#### 数据流向

```
用户界面操作
      │
      ▼
   SQLite数据库
      │
      ▼
   配置文件 (JSON)
```

#### 配置文件存储位置

配置文件存储在应用的文档目录下的 `config` 文件夹中：

- **错类大纲**: `{app_documents}/config/error_type_outlines.json`
- **知识点大纲**: `{app_documents}/config/knowledge_outlines.json`

#### 同步机制

1. **导入数据**: 点击"从配置文件导入数据"按钮时，系统会：
   - 优先从应用文档目录读取配置文件
   - 如果不存在，则从 `assets/config/` 目录读取默认配置
   - 将配置数据导入到 SQLite 数据库

2. **保存配置**: 当用户在界面中修改错类或知识点大纲时，系统会：
   - 更新 SQLite 数据库中的记录
   - 自动导出最新数据到配置文件
   - 确保配置文件与数据库保持同步

3. **配置文件格式**:
   ```json
   {
     "error_type_outlines": [
       {"eid": "E1", "fid": "", "content": "概念混淆", "lang": "cn"},
       {"eid": "E6", "fid": "E1", "content": "近义词辨析错误", "lang": "cn"}
     ]
   }
   ```

#### 配置文件管理

- **首次启动**: 使用 `assets/config/` 目录下的默认配置初始化
- **后续运行**: 使用应用文档目录中的配置文件
- **手动修改**: 可直接编辑 JSON 配置文件，点击导入按钮重新加载
- **备份恢复**: 配置文件可作为数据备份，迁移到其他设备

## 开发工具

### SQLite3 终端

在欢迎页面点击"SQLite3 终端"按钮可打开数据库查询终端，支持执行 SQL 命令：

```sql
-- 查询错类大纲
SELECT * FROM error_type_outlines;

-- 查询错误记录
SELECT * FROM error_records LIMIT 10;

-- 统计各错类错误数量
SELECT e.content, COUNT(r.id) as count 
FROM error_type_outlines e
LEFT JOIN error_records r ON r.error_type LIKE '%' || e.eid || '%'
GROUP BY e.eid;
```

### 文件浏览器

在欢迎页面点击"文件浏览器"按钮可浏览应用本地目录结构。

## 项目结构

```
lib/
├── database/          # 数据库相关代码
│   ├── models/        # 数据模型
│   ├── db_helper.dart # 数据库帮助类
│   └── schema.dart    # 数据库表结构
├── pages/             # 页面组件
├── services/          # 业务逻辑服务
│   ├── config_importer.dart # 配置数据导入/导出服务
│   └── demo_data_initializer.dart # 演示数据初始化
└── main.dart          # 应用入口
```

## 技术栈

- **框架**: Flutter 3.x
- **数据库**: SQLite (sqflite)
- **状态管理**: GetX
- **环境配置**: flutter_dotenv

## 运行项目

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建APK
flutter build apk

# 构建iOS
flutter build ios
```

## 数据导入流程

1. 启动应用，进入欢迎页面
2. 点击"从配置文件导入数据"按钮
3. 等待数据导入完成（会显示成功/失败提示）
4. 点击"进入主页"按钮进入应用

## 配置文件说明

### 配置文件类型

| 文件 | 用途 | 说明 |
|------|------|------|
| `error_type_outlines.json` | 错类大纲配置 | 用于错误记录分类，支持层级结构 |
| `knowledge_outlines.json` | 知识点大纲配置 | 用于知识点分类，支持层级结构 |
| `skills.json` | 技能配置 | AI辅助学习功能定义 |
| `error_records.json` | 错误记录示例 | 示例错题数据 |
| `exercises.json` | 习题集示例 | 示例习题数据 |
| `portfolio_items.json` | 作品集示例 | 示例作品数据 |
| `knowledge_points.json` | 知识点示例 | 示例知识点数据 |

### 配置文件结构

**错类大纲 (`error_type_outlines.json`)**:
```json
{
  "error_type_outlines": [
    {"eid": "E1", "fid": "", "content": "概念混淆", "lang": "cn"},
    {"eid": "E6", "fid": "E1", "content": "近义词辨析错误", "lang": "cn"}
  ]
}
```

**知识点大纲 (`knowledge_outlines.json`)**:
```json
{
  "knowledge_outlines": [
    {"cid": "vocabulary", "fid": "", "content": "词汇", "lang": "cn"},
    {"cid": "synonym", "fid": "vocabulary", "content": "近义词辨析", "lang": "cn"}
  ]
}
```

## 注意事项

- 配置文件采用 JSON 格式，修改后需确保格式正确
- 错类和知识点大纲的修改会自动同步到配置文件
- 首次导入时会清空现有数据，请谨慎操作
- 建议定期备份配置文件目录
- 配置文件是正式的生产数据，不是测试数据