
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
    );
  }
}

class ExerciseDao {
  final Database db;

  ExerciseDao(this.db);

  Future<int> insert(Exercise exercise) async {
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getAll({String? lang, String? category, bool? completed}) async {
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

    final maps = await db.query(
      'exercises',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'difficulty ASC, created_at DESC',
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

  Future<int> count({String? lang, String? category, bool? completed}) async {
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

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM exercises${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
