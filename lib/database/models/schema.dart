/// 统一的数据结构定义
/// 为各模块提供标准化的数据访问接口

import 'package:sqflite/sqflite.dart';

// ============================================================
// 通用字段常量 - 所有模块共享的基础字段
// ============================================================

class CommonFields {
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String Lang = 'lang';
}

// ============================================================
// 知识点模块 (Knowledge Point)
// ============================================================

class KnowledgePointSchema {
  static const String tableName = 'knowledge_points';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'title': 'TEXT NOT NULL',
    'content': 'TEXT',
    'category': 'TEXT',
    'lesson_unit': 'TEXT',
    'error_type': 'TEXT',
    'parent_id': 'INTEGER',
    'difficulty': 'INTEGER DEFAULT 1',
    'mastered': 'INTEGER DEFAULT 0',
    'content_path': 'TEXT',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
  };
}

// ============================================================
// 错题本模块 (Error Record)
// ============================================================

class ErrorRecordSchema {
  static const String tableName = 'error_records';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'content': 'TEXT NOT NULL',
    'correct_answer': 'TEXT',
    'subject': 'TEXT',
    'lesson': 'TEXT',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'reviewed': 'INTEGER DEFAULT 0',
    'lang': "TEXT DEFAULT 'cn'",
    'content_path': 'TEXT',
    'error_id': 'TEXT',
    'error_type': 'TEXT',
    'exercise_tag': 'TEXT',
    'knowledge_tag': 'TEXT',
    'progress': "TEXT DEFAULT '待订正'",
    'question': 'TEXT',
    'wrong_answer': 'TEXT',
    'wrong_where': 'TEXT',
    'why_wrong': 'TEXT',
    'how_prevent': 'TEXT',
    'notes': 'TEXT',
    'images': 'TEXT',
  };

  // 进度状态枚举
  static const List<String> progressStatuses = [
    '待订正',
    '已订正',
    '已掌握',
    '学习中',
  ];

  // 错误类型枚举
  static const List<String> errorTypes = [
    '概念混淆',
    '计算失误',
    '审题不清',
    '知识遗漏',
    '推理错误',
  ];
}

// ============================================================
// 习题集模块 (Exercise)
// ============================================================

class ExerciseSchema {
  static const String tableName = 'exercises';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'question': 'TEXT NOT NULL',
    'options': 'TEXT',
    'correct_answer': 'TEXT',
    'explanation': 'TEXT',
    'category': 'TEXT',
    'difficulty': 'INTEGER DEFAULT 1',
    'completed': 'INTEGER DEFAULT 0',
    'content_path': 'TEXT',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
    'exercise_id': 'TEXT',
    'paper_id': 'TEXT', // 关联试卷ID（E开头，如 E1, E2）
    'lesson_unit': 'TEXT',
    'knowledge_tag': 'TEXT',
    'progress': "TEXT DEFAULT '未答题'",
    'exam_paper': 'TEXT',
    'answer_sheet': 'TEXT',
    'answer_key': 'TEXT',
    'grading': 'TEXT',
  };

  // 答题进度状态枚举
  static const List<String> progressStatuses = [
    '未答题',
    '已答题',
    '已批阅',
    '已订正',
  ];
}

// ============================================================
// 作品集模块 (Portfolio Item)
// ============================================================

class PortfolioItemSchema {
  static const String tableName = 'portfolio_items';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'title': 'TEXT NOT NULL',
    'type': 'TEXT',
    'content_path': 'TEXT',
    'thumbnail_path': 'TEXT',
    'content': 'TEXT', // 文章内容正文
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
    'portfolio_id': 'TEXT',
    'is_original': 'INTEGER DEFAULT 0',
    'knowledge_tag': 'TEXT',
    'lesson_unit': 'TEXT',
    'ai_review': 'TEXT',
  };

  // 作品类型枚举
  static const List<String> itemTypes = [
    '课文赏析',
    '习作',
    '名篇赏析',
    '阅读笔记',
    '作文',
    '其他',
  ];
}

// ============================================================
// 技能模块 (Skill)
// ============================================================

class SkillSchema {
  static const String tableName = 'skills';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'name': 'TEXT NOT NULL',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
    'skill_id': 'TEXT',
    'category': 'TEXT',
    'prerequisite': 'TEXT',
    'prompt_text': 'TEXT',
    'internal_function': 'TEXT',
    'parameters': 'TEXT',
    'return_type': 'TEXT',
    'description': 'TEXT',
    'content_path': 'TEXT',
  };

  // 技能分类枚举
  static const List<String> categories = [
    '内部',
    '外部',
  ];
}

// ============================================================
// 效率记录模块 (Efficiency Record)
// ============================================================

class EfficiencyRecordSchema {
  static const String tableName = 'efficiency_records';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'record_id': 'TEXT',
    'title': 'TEXT NOT NULL',
    'unit_count': 'INTEGER DEFAULT 0',
    'unit_efficiency': 'REAL DEFAULT 0',
    'record_time': 'TEXT',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
  };
}

// ============================================================
// 日程模块 (Schedule Item)
// ============================================================

class ScheduleItemSchema {
  static const String tableName = 'schedule_items';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'schedule_id': 'TEXT NOT NULL UNIQUE',
    'title': 'TEXT NOT NULL',
    'start_time': 'TEXT NOT NULL',
    'end_time': 'TEXT NOT NULL',
    'repeat_type': "TEXT DEFAULT 'none'",
    'repeat_days': 'TEXT',
    'date': "TEXT NOT NULL DEFAULT CURRENT_DATE",
    'completed': 'INTEGER DEFAULT 0',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
  };

  // 重复类型枚举
  static const List<String> repeatTypes = [
    'none',
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];
}

// ============================================================
// 聊天消息模块 (Chat Message)
// ============================================================

class ChatMessageSchema {
  static const String tableName = 'chat_messages';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'content': 'TEXT NOT NULL',
    'reasoning': 'TEXT',
    'is_user': 'INTEGER DEFAULT 0',
    'created_at': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
    'lang': "TEXT DEFAULT 'cn'",
  };

  // 消息类型枚举
  static const String TYPE_USER = 'user';
  static const String TYPE_AI = 'ai';
}

// ============================================================
// 收件箱模块 (Inbox Item)
// ============================================================

class InboxItemSchema {
  static const String tableName = 'inbox_items';
  
  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'title': 'TEXT NOT NULL',
    'source': 'TEXT NOT NULL',
    'url': 'TEXT NOT NULL',
    'filePath': 'TEXT NOT NULL',
    'content': 'TEXT',
    'category': "TEXT DEFAULT '未知归类'",
    'status': "TEXT DEFAULT '未处理'",
    'createdAt': 'TEXT NOT NULL',
    'updatedAt': 'TEXT',
  };

  // 状态枚举
  static const List<String> statuses = [
    '未处理',
    '处理中',
    '已完成',
    '已忽略',
  ];

  // 来源枚举
  static const List<String> sources = [
    '网页',
    '微信',
    '书签',
    '手动添加',
    'AI抓取',
  ];
}

// ============================================================
// 数据库工具类
// ============================================================

class DatabaseUtils {
  /// 安全地从数据库中读取整数字段，处理 null 值
  static int getIntValue(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    return value as int;
  }

  /// 安全地从数据库中读取布尔字段 (SQLite 存储为 0/1)
  static bool getBoolValue(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    return (value as int) == 1;
  }

  /// 构建 WHERE 条件和参数列表
  static Map<List<String>, List<dynamic>> buildConditions({
    required List<String> conditions,
    List<Map<String, dynamic>> filters = const [],
  }) {
    List<dynamic> args = [];
    for (final filter in filters) {
      filter.forEach((key, value) {
        conditions.add('$key = ?');
        args.add(value);
      });
    }
    return Map.unmodifiable({
      'conditions': conditions.toList(),
      'args': args.toList(),
    }) as Map<List<String>, List<dynamic>>;
  }

  /// 执行查询并返回结果计数
  static Future<int> queryCount(Database db, String table, {String? where, List<dynamic>? whereArgs}) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $table${where != null ? " WHERE $where" : ""}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 检查表是否存在
  static Future<bool> tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
    );
    return result.isNotEmpty;
  }
}
