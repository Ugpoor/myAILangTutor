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
  final String? lessonUnit;
  final String? knowledgeTag;
  final String progress;
  final String? examPaper;
  final String? answerSheet;
  final String? answerKey;
  final String? grading;

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
    this.lessonUnit,
    this.knowledgeTag,
    this.progress = '未答题',
    this.examPaper,
    this.answerSheet,
    this.answerKey,
    this.grading,
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
      'lesson_unit': lessonUnit,
      'knowledge_tag': knowledgeTag,
      'progress': progress,
      'exam_paper': examPaper,
      'answer_sheet': answerSheet,
      'answer_key': answerKey,
      'grading': grading,
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
    String? keyword,
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
      conditions.add('lesson_unit = ?');
      args.add(lessonUnit);
    }
    if (knowledgeTag != null) {
      conditions.add('knowledge_tag LIKE ?');
      args.add('%$knowledgeTag%');
    }
    if (progress != null) {
      conditions.add('progress = ?');
      args.add(progress);
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
}
