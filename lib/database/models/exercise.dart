import 'package:sqflite/sqflite.dart';

class Exercise {
  final int? id;
  final String question;
  final String? options;
  final String? correctAnswer;
  final String? explanation;
  final String? category;
  final int difficulty;
  final bool completed;
  final DateTime? createdAt;
  final String lang;
  final String? contentPath;
  final String? exerciseId;
  final String? paperId; // 关联试卷ID（E开头，如 E1, E2）
  final String? lessonUnit;
  final String? knowledgeTag;
  final String progress;
  final String? examPaper;
  final String? answerSheet;
  final String? answerKey;
  final String? grading;
  final String? source;

  Exercise({
    this.id,
    required this.question,
    this.options,
    this.correctAnswer,
    this.explanation,
    this.category,
    this.difficulty = 1,
    this.completed = false,
    this.createdAt,
    this.lang = 'cn',
    this.contentPath,
    this.exerciseId,
    this.paperId,
    this.lessonUnit,
    this.knowledgeTag,
    this.progress = '未答题',
    this.examPaper,
    this.answerSheet,
    this.answerKey,
    this.grading,
    this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'category': category,
      'difficulty': difficulty,
      'completed': completed ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'content_path': contentPath,
      'exercise_id': exerciseId,
      'paper_id': paperId,
      'lesson_unit': lessonUnit,
      'knowledge_tag': knowledgeTag,
      'progress': progress,
      'exam_paper': examPaper,
      'answer_sheet': answerSheet,
      'answer_key': answerKey,
      'grading': grading,
      'source': source,
    };
  }

  static Exercise fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      question: map['question'] as String,
      options: map['options'] as String?,
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
      lessonUnit: map['lesson_unit'] as String?,
      knowledgeTag: map['knowledge_tag'] as String?,
      progress: map['progress'] as String? ?? '未答题',
      examPaper: map['exam_paper'] as String?,
      answerSheet: map['answer_sheet'] as String?,
      answerKey: map['answer_key'] as String?,
      grading: map['grading'] as String?,
      source: map['source'] as String?,
    );
  }

  Exercise copyWith({
    int? id,
    String? question,
    String? options,
    String? correctAnswer,
    String? explanation,
    String? category,
    int? difficulty,
    bool? completed,
    DateTime? createdAt,
    String? lang,
    String? contentPath,
    String? exerciseId,
    String? lessonUnit,
    String? knowledgeTag,
    String? progress,
    String? examPaper,
    String? answerSheet,
    String? answerKey,
    String? grading,
    String? source,
  }) {
    return Exercise(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      contentPath: contentPath ?? this.contentPath,
      exerciseId: exerciseId ?? this.exerciseId,
      lessonUnit: lessonUnit ?? this.lessonUnit,
      knowledgeTag: knowledgeTag ?? this.knowledgeTag,
      progress: progress ?? this.progress,
      examPaper: examPaper ?? this.examPaper,
      answerSheet: answerSheet ?? this.answerSheet,
      answerKey: answerKey ?? this.answerKey,
      grading: grading ?? this.grading,
      source: source ?? this.source,
    );
  }
}

class ExerciseDao {
  final Database db;

  ExerciseDao(this.db);

  Future<int> insert(Exercise exercise) async {
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getAll({
    String? lang,
    String? category,
    bool? completed,
    String? lessonUnit,
    String? knowledgeTag,
    String? progress,
    String? source,
    List<String>? knowledgeTags,
    List<String>? sources,
    String? keyword,
    String? paperId, // 按试卷 ID 筛选
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
      conditions.add('lesson_unit LIKE ?');
      args.add('%$lessonUnit%');
    }
    if (knowledgeTag != null && knowledgeTags == null) {
      conditions.add('knowledge_tag LIKE ?');
      args.add('%$knowledgeTag%');
    }
    if (knowledgeTags != null && knowledgeTags.isNotEmpty) {
      final placeholders = knowledgeTags.map((_) => '?').join(', ');
      conditions.add('(knowledge_tag IN ($placeholders) OR knowledge_tag IS NULL)');
      args.addAll(knowledgeTags);
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
    if (paperId != null) {
      conditions.add('paper_id = ?');
      args.add(paperId);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(question LIKE ? OR exercise_id LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'exercises',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  /// 根据试卷 ID 获取该试卷下的所有试题
  Future<List<Exercise>> getExercisesByPaperId(String paperId) async {
    final maps = await db.query(
      'exercises',
      where: 'paper_id = ?',
      whereArgs: [paperId],
      orderBy: 'exercise_id ASC',
    );
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  /// 根据试题 ID（如 E2T3）获取单个试题
  Future<Exercise?> getByExerciseId(String exerciseId) async {
    final maps = await db.query(
      'exercises',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );
    return maps.isNotEmpty ? Exercise.fromMap(maps.first) : null;
  }

  Future<Exercise?> getById(int id) async {
    final maps = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? Exercise.fromMap(maps.first) : null;
  }

  Future<int> update(Exercise exercise) async {
    return await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count({String? lang, String? category, bool? completed, String? progress}) async {
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
      'SELECT COUNT(*) FROM exercises${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== 习题集清理方法 ==========

  /// 删除包含明显数学内容的习题（只删除明确是数学题的记录）
  Future<int> deleteMathExercises() async {
    // 只匹配明确的数学符号和公式，避免误删语文中的通用词汇
    const mathKeywords = [
      'π=', 'π值', '勾股', '二次方程', '一元二次', 'x²=', 'x^2',
      '√', '∑', '∫', 'sin(', 'cos(', 'tan(', 'log(', 'ln(',
      'matrix', 'determinant', '微积分', '导数', '积分',
    ];

    int deletedCount = 0;
    
    for (final keyword in mathKeywords) {
      final result = await db.rawDelete(
        "DELETE FROM exercises WHERE "
        "(question LIKE ? OR exam_paper LIKE ? OR knowledge_tag LIKE ?)",
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      deletedCount += result;
    }

    return deletedCount;
  }

  /// 删除重复的习题（保留 id 最小的那条）
  Future<int> deduplicateExercises() async {
    int deletedCount = 0;

    // 1. 基于 exercise_id 去重
    final duplicateById = await db.rawQuery(
      """
      SELECT MIN(id) as keep_id, GROUP_CONCAT(id) as all_ids
      FROM exercises
      WHERE exercise_id IS NOT NULL AND exercise_id != ''
      GROUP BY exercise_id
      HAVING COUNT(*) > 1
      """,
    );

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
          await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
          deletedCount++;
        }
      }
    }

    // 2. 基于 exam_paper 内容去重
    final duplicateByContent = await db.rawQuery(
      """
      SELECT MIN(id) as keep_id, GROUP_CONCAT(id) as all_ids
      FROM exercises
      WHERE exam_paper IS NOT NULL AND exam_paper != ''
      GROUP BY exam_paper
      HAVING COUNT(*) > 1
      """,
    );

    for (final row in duplicateByContent) {
      final keepId = row['keep_id'] as int?;
      final allIdsStr = row['all_ids'] as String?;
      if (keepId != null && allIdsStr != null) {
        final ids = (allIdsStr as String)
            .split(',')
            .map(int.parse)
            .where((id) => id != keepId)
            .toList();
        for (final id in ids) {
          await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
          deletedCount++;
        }
      }
    }

    return deletedCount;
  }

  /// 一键清理：去重
  Future<Map<String, int>> cleanExercises() async {
    final dupDeleted = await deduplicateExercises();
    
    return {
      'duplicate_deleted': dupDeleted,
    };
  }

  Future<int> nextExerciseIdNumber() async {
    final result = await db.rawQuery(
      "SELECT exercise_id FROM exercises WHERE exercise_id LIKE 'T%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['exercise_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'T(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }

  /// 删除所有习题
  Future<int> deleteAll() async {
    return await db.rawDelete('DELETE FROM exercises');
  }
}
