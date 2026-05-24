import 'package:sqflite/sqflite.dart';

class Question {
  final int? id;
  final String question;
  final String? correctAnswer;
  final String? explanation;
  final String? category;
  final int difficulty;
  final bool completed;
  final DateTime? createdAt;
  final String lang;
  final String? contentPath;
  final String? exerciseId;
  final String? tid;
  final int? lessonNumber;
  final int? unitNumber;
  final String? kid;
  final String progress;
  final Map<String, dynamic>? examPaper;
  final Map<String, dynamic>? answerSheet;
  final Map<String, dynamic>? answerKey;
  final String? grading;
  final String? source;

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
    this.grading,
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
      'exam_paper': examPaper != null ? _encodeMap(examPaper!) : null,
      'answer_sheet': answerSheet != null ? _encodeMap(answerSheet!) : null,
      'answer_key': answerKey != null ? _encodeMap(answerKey!) : null,
      'grading': grading,
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
      examPaper: map['exam_paper'] != null ? _decodeMap(map['exam_paper'] as String) : null,
      answerSheet: map['answer_sheet'] != null ? _decodeMap(map['answer_sheet'] as String) : null,
      answerKey: map['answer_key'] != null ? _decodeMap(map['answer_key'] as String) : null,
      grading: map['grading'] as String?,
      source: map['source'] as String?,
    );
  }

  static String _encodeMap(Map<String, dynamic> map) {
    List<String> parts = [];
    if (map['imagelink'] != null) {
      parts.add('imagelink:${map['imagelink']}');
    }
    if (map['left-top'] != null) {
      final lt = map['left-top'];
      parts.add('left-top:${lt[0]},${lt[1]}');
    }
    if (map['bottom-right'] != null) {
      final br = map['bottom-right'];
      parts.add('bottom-right:${br[0]},${br[1]}');
    }
    return parts.join('|');
  }

  static Map<String, dynamic>? _decodeMap(String str) {
    if (str.isEmpty) return null;
    Map<String, dynamic> map = {};
    final parts = str.split('|');
    for (final part in parts) {
      final idx = part.indexOf(':');
      if (idx > 0) {
        final key = part.substring(0, idx);
        final value = part.substring(idx + 1);
        if (key == 'left-top' || key == 'bottom-right') {
          final coords = value.split(',').map((s) => double.tryParse(s) ?? 0).toList();
          map[key] = coords.length >= 2 ? [coords[0], coords[1]] : [0, 0];
        } else {
          map[key] = value;
        }
      }
    }
    return map;
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
    Map<String, dynamic>? examPaper,
    Map<String, dynamic>? answerSheet,
    Map<String, dynamic>? answerKey,
    String? grading,
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
      grading: grading ?? this.grading,
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
    final maps = await db.query(
      'questions',
      where: 'id = ?',
      whereArgs: [id],
    );
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
    return await db.delete(
      'questions',
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
      'SELECT COUNT(*) FROM questions${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteMathQuestions() async {
    const mathKeywords = [
      'π=', 'π值', '勾股', '二次方程', '一元二次', 'x²=', 'x^2',
      '√', '∑', '∫', 'sin(', 'cos(', 'tan(', 'log(', 'ln(',
      'matrix', 'determinant', '微积分', '导数', '积分',
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

    final duplicateById = await db.rawQuery(
      """
      SELECT MIN(id) as keep_id, GROUP_CONCAT(id) as all_ids
      FROM questions
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
          await db.delete('questions', where: 'id = ?', whereArgs: [id]);
          deletedCount++;
        }
      }
    }

    return deletedCount;
  }

  Future<Map<String, int>> cleanQuestions() async {
    final dupDeleted = await deduplicateQuestions();
    
    return {
      'duplicate_deleted': dupDeleted,
    };
  }

  Future<int> nextExerciseIdNumber() async {
    final result = await db.rawQuery(
      "SELECT exercise_id FROM questions WHERE exercise_id LIKE 'T%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['exercise_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'T(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }

  Future<int> deleteAll() async {
    return await db.rawDelete('DELETE FROM questions');
  }
}