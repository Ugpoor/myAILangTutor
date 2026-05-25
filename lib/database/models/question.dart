import 'dart:convert';
import 'package:sqflite/sqflite.dart';

class ImageRegion {
  final int imgNum;
  final List<double> leftTop;
  final List<double> bottomRight;

  const ImageRegion({
    required this.imgNum,
    required this.leftTop,
    required this.bottomRight,
  });

  Map<String, dynamic> toMap() => {
    'imgNum': imgNum,
    'left-top': leftTop,
    'bottom-right': bottomRight,
  };

  static ImageRegion fromMap(Map<String, dynamic> map) => ImageRegion(
    imgNum: map['imgNum'] as int,
    leftTop: (map['left-top'] as List)
        .map((e) => (e as num).toDouble())
        .toList(),
    bottomRight: (map['bottom-right'] as List)
        .map((e) => (e as num).toDouble())
        .toList(),
  );
}

class Question {
  final int? id; // 数据库自增主键
  final String question; // 题目内容（题干文本）
  final String? correctAnswer; // 正确答案
  final String? explanation; // 答案解析/说明
  final String? category; // 题目分类（填空题、选择题、判断题、简答题、作文题）
  final int difficulty; // 难度级别（1-5级）
  final bool completed; // 是否已完成作答
  final DateTime? createdAt; // 创建时间
  final String lang; // 语言标识（cn/en）
  final String? contentPath; // 内容文件路径（关联外部文件）
  final String? exerciseId; // 题目唯一标识，格式为 tid + "-Q" + 序号（如 T1-Q1），用于跨模块引用和显示
  final String? tid; // 关联的试卷ID（外键，关联 Test.tid）
  final int? lessonNumber; // 单元号（如 1、2、3）
  final int? unitNumber; // 课号（如 1、2、3）
  final String? kid; // 关联知识点ID（格式：K+数字，如 K1）
  final String progress; // 答题进度（未答题、已答题、已批阅、已订正）
  final ImageRegion? examPaper; // 题目区域截图信息（试卷图片中的题目位置）
  final ImageRegion? answerSheet; // 答题区域截图信息（答卷图片中的答题位置）
  final ImageRegion? answerKey; // 答案区域截图信息（答案图片中的答案位置）
  final ImageRegion? gradingSheet; // 批阅区域截图信息（已批改答卷中的批阅位置）
  final String? grading; // 批阅意见/评语
  final String? gradingResult; // 批改结果（正确/部分正确/错误/未评分）
  final String? answer; // 用户答题结果（学生作答内容）
  final String? source; // 来源（如：错题本、知识点、作品集）

  String? get lessonUnit {
    if (lessonNumber != null && unitNumber != null) {
      return '${lessonNumber}单元${unitNumber}课';
    }
    return null;
  }

  Question({
    this.id,
    required this.question,
    this.correctAnswer,
    this.explanation,
    this.category,
    this.difficulty = 1,
    this.completed = false,
    this.createdAt,
    this.lang = 'cn',
    this.contentPath,
    this.exerciseId,
    this.tid,
    this.lessonNumber,
    this.unitNumber,
    this.kid,
    this.progress = '未答题',
    this.examPaper,
    this.answerSheet,
    this.answerKey,
    this.gradingSheet,
    this.grading,
    this.gradingResult,
    this.answer,
    this.source,
  });

  static List<String> get validCategories => [
    '填空题',
    '选择题',
    '判断题',
    '简答题',
    '作文题',
  ];

  static List<String> get validCategoriesEn => [
    'fill_blank',
    'multiple_choice',
    'true_false',
    'short_answer',
    'essay',
  ];

  static String translateCategory(String category, String lang) {
    if (lang == 'en') {
      switch (category) {
        case '填空题':
          return 'fill_blank';
        case '选择题':
          return 'multiple_choice';
        case '判断题':
          return 'true_false';
        case '简答题':
          return 'short_answer';
        case '作文题':
          return 'essay';
        default:
          return category;
      }
    } else {
      switch (category) {
        case 'fill_blank':
          return '填空题';
        case 'multiple_choice':
          return '选择题';
        case 'true_false':
          return '判断题';
        case 'short_answer':
          return '简答题';
        case 'essay':
          return '作文题';
        default:
          return category;
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'category': category,
      'difficulty': difficulty,
      'completed': completed ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'content_path': contentPath,
      'exercise_id': exerciseId,
      'tid': tid,
      'lesson_number': lessonNumber,
      'unit_number': unitNumber,
      'kid': kid,
      'progress': progress,
      'exam_paper': examPaper != null ? jsonEncode(examPaper!.toMap()) : null,
      'answer_sheet': answerSheet != null
          ? jsonEncode(answerSheet!.toMap())
          : null,
      'answer_key': answerKey != null ? jsonEncode(answerKey!.toMap()) : null,
      'grading_sheet': gradingSheet != null
          ? jsonEncode(gradingSheet!.toMap())
          : null,
      'grading': grading,
      'grading_result': gradingResult,
      'answer': answer,
      'source': source,
    };
  }

  static Question fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int?,
      question: map['question'] as String,
      correctAnswer: map['correct_answer'] as String?,
      explanation: map['explanation'] as String?,
      category: map['category'] as String?,
      difficulty: map['difficulty'] as int? ?? 1,
      completed: (map['completed'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      contentPath: map['content_path'] as String?,
      exerciseId: map['exercise_id'] as String?,
      tid: map['tid'] as String?,
      lessonNumber: map['lesson_number'] as int?,
      unitNumber: map['unit_number'] as int?,
      kid: map['kid'] as String?,
      progress: map['progress'] as String? ?? '未答题',
      examPaper: map['exam_paper'] != null
          ? ImageRegion.fromMap(jsonDecode(map['exam_paper'] as String))
          : null,
      answerSheet: map['answer_sheet'] != null
          ? ImageRegion.fromMap(jsonDecode(map['answer_sheet'] as String))
          : null,
      answerKey: map['answer_key'] != null
          ? ImageRegion.fromMap(jsonDecode(map['answer_key'] as String))
          : null,
      gradingSheet: map['grading_sheet'] != null
          ? ImageRegion.fromMap(jsonDecode(map['grading_sheet'] as String))
          : null,
      grading: map['grading'] as String?,
      gradingResult: map['grading_result'] as String?,
      answer: map['answer'] as String?,
      source: map['source'] as String?,
    );
  }

  Question copyWith({
    int? id,
    String? question,
    String? correctAnswer,
    String? explanation,
    String? category,
    int? difficulty,
    bool? completed,
    DateTime? createdAt,
    String? lang,
    String? contentPath,
    String? exerciseId,
    String? tid,
    int? lessonNumber,
    int? unitNumber,
    String? kid,
    String? progress,
    ImageRegion? examPaper,
    ImageRegion? answerSheet,
    ImageRegion? answerKey,
    ImageRegion? gradingSheet,
    String? grading,
    String? gradingResult,
    String? answer,
    String? source,
  }) {
    return Question(
      id: id ?? this.id,
      question: question ?? this.question,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      contentPath: contentPath ?? this.contentPath,
      exerciseId: exerciseId ?? this.exerciseId,
      tid: tid ?? this.tid,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      unitNumber: unitNumber ?? this.unitNumber,
      kid: kid ?? this.kid,
      progress: progress ?? this.progress,
      examPaper: examPaper ?? this.examPaper,
      answerSheet: answerSheet ?? this.answerSheet,
      answerKey: answerKey ?? this.answerKey,
      gradingSheet: gradingSheet ?? this.gradingSheet,
      grading: grading ?? this.grading,
      gradingResult: gradingResult ?? this.gradingResult,
      answer: answer ?? this.answer,
      source: source ?? this.source,
    );
  }
}

class QuestionDao {
  final Database db;

  QuestionDao(this.db);

  Future<int> insert(Question question) async {
    return await db.insert('questions', question.toMap());
  }

  Future<List<Question>> getAll({
    String? lang,
    String? category,
    bool? completed,
    String? lessonUnit,
    String? kid,
    String? progress,
    String? source,
    List<String>? kids,
    List<String>? sources,
    String? keyword,
    String? tid,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (completed != null) {
      conditions.add('completed = ?');
      args.add(completed ? 1 : 0);
    }
    if (lessonUnit != null) {
      conditions.add('(lesson_number || "单元" || unit_number || "课") LIKE ?');
      args.add('%$lessonUnit%');
    }
    if (kid != null && kids == null) {
      conditions.add('kid LIKE ?');
      args.add('%$kid%');
    }
    if (kids != null && kids.isNotEmpty) {
      final placeholders = kids.map((_) => '?').join(', ');
      conditions.add('(kid IN ($placeholders) OR kid IS NULL)');
      args.addAll(kids);
    }
    if (progress != null) {
      conditions.add('progress = ?');
      args.add(progress);
    }
    if (source != null) {
      conditions.add('source = ?');
      args.add(source);
    }
    if (sources != null && sources.isNotEmpty) {
      final placeholders = sources.map((_) => '?').join(', ');
      conditions.add('(source IN ($placeholders) OR source IS NULL)');
      args.addAll(sources);
    }
    if (tid != null) {
      conditions.add('tid = ?');
      args.add(tid);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(question LIKE ? OR exercise_id LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'questions',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Question.fromMap(map)).toList();
  }

  Future<List<Question>> getQuestionsByTid(String tid) async {
    final maps = await db.query(
      'questions',
      where: 'tid = ?',
      whereArgs: [tid],
      orderBy: 'exercise_id ASC',
    );
    return maps.map((map) => Question.fromMap(map)).toList();
  }

  Future<Question?> getByExerciseId(String exerciseId) async {
    final maps = await db.query(
      'questions',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );
    return maps.isNotEmpty ? Question.fromMap(maps.first) : null;
  }

  Future<Question?> getById(int id) async {
    final maps = await db.query('questions', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Question.fromMap(maps.first) : null;
  }

  Future<int> update(Question question) async {
    return await db.update(
      'questions',
      question.toMap(),
      where: 'id = ?',
      whereArgs: [question.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete('questions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count({
    String? lang,
    String? category,
    bool? completed,
    String? progress,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (completed != null) {
      conditions.add('completed = ?');
      args.add(completed ? 1 : 0);
    }
    if (progress != null) {
      conditions.add('progress = ?');
      args.add(progress);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM questions${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteMathQuestions() async {
    const mathKeywords = [
      'π=',
      'π值',
      '勾股',
      '二次方程',
      '一元二次',
      'x²=',
      'x^2',
      '√',
      '∑',
      '∫',
      'sin(',
      'cos(',
      'tan(',
      'log(',
      'ln(',
      'matrix',
      'determinant',
      '微积分',
      '导数',
      '积分',
    ];

    int deletedCount = 0;

    for (final keyword in mathKeywords) {
      final result = await db.rawDelete(
        "DELETE FROM questions WHERE "
        "(question LIKE ? OR kid LIKE ?)",
        ['%$keyword%', '%$keyword%'],
      );
      deletedCount += result;
    }

    return deletedCount;
  }

  Future<int> deduplicateQuestions() async {
    int deletedCount = 0;

    final duplicateById = await db.rawQuery("""
      SELECT MIN(id) as keep_id, GROUP_CONCAT(id) as all_ids
      FROM questions
      WHERE exercise_id IS NOT NULL AND exercise_id != ''
      GROUP BY exercise_id
      HAVING COUNT(*) > 1
      """);

    for (final row in duplicateById) {
      final keepId = row['keep_id'] as int?;
      final allIdsStr = row['all_ids'] as String?;
      if (keepId != null && allIdsStr != null) {
        final ids = (allIdsStr as String)
            .split(',')
            .map(int.parse)
            .where((id) => id != keepId)
            .toList();
        for (final id in ids) {
          await db.delete('questions', where: 'id = ?', whereArgs: [id]);
          deletedCount++;
        }
      }
    }

    return deletedCount;
  }

  Future<Map<String, int>> cleanQuestions() async {
    final dupDeleted = await deduplicateQuestions();

    return {'duplicate_deleted': dupDeleted};
  }

  Future<int> nextExerciseIdNumber() async {
    final result = await db.rawQuery(
      "SELECT exercise_id FROM questions WHERE exercise_id LIKE 'T%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['exercise_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'T(\d+)').firstMatch(lastId!);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }

  Future<int> deleteAll() async {
    return await db.rawDelete('DELETE FROM questions');
  }
}
