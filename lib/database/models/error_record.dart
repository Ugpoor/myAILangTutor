import 'package:sqflite/sqflite.dart';

class ErrorRecord {
  final int? id;
  final String content;
  final String? correctAnswer;
  final String? subject;
  final String? lesson;
  final DateTime? createdAt;
  final bool reviewed;
  final String lang;
  final String? contentPath;
  final String? errorId;
  final String? errorType;
  final String? exerciseTag;
  final String? knowledgeTag;
  final String progress;
  final String? question;
  final String? wrongAnswer;
  final String? wrongWhere;
  final String? whyWrong;
  final String? howPrevent;
  final String? notes;
  final String? images;

  ErrorRecord({
    this.id,
    required this.content,
    this.correctAnswer,
    this.subject,
    this.lesson,
    this.createdAt,
    this.reviewed = false,
    this.lang = 'cn',
    this.contentPath,
    this.errorId,
    this.errorType,
    this.exerciseTag,
    this.knowledgeTag,
    this.progress = '待订正',
    this.question,
    this.wrongAnswer,
    this.wrongWhere,
    this.whyWrong,
    this.howPrevent,
    this.notes,
    this.images,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'correct_answer': correctAnswer,
      'subject': subject,
      'lesson': lesson,
      'created_at': createdAt?.toIso8601String(),
      'reviewed': reviewed ? 1 : 0,
      'lang': lang,
      'content_path': contentPath,
      'error_id': errorId,
      'error_type': errorType,
      'exercise_tag': exerciseTag,
      'knowledge_tag': knowledgeTag,
      'progress': progress,
      'question': question,
      'wrong_answer': wrongAnswer,
      'wrong_where': wrongWhere,
      'why_wrong': whyWrong,
      'how_prevent': howPrevent,
      'notes': notes,
      'images': images,
    };
  }

  static ErrorRecord fromMap(Map<String, dynamic> map) {
    return ErrorRecord(
      id: map['id'] as int?,
      content: map['content'] as String,
      correctAnswer: map['correct_answer'] as String?,
      subject: map['subject'] as String?,
      lesson: map['lesson'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      reviewed: (map['reviewed'] as int?) == 1,
      lang: map['lang'] as String? ?? 'cn',
      contentPath: map['content_path'] as String?,
      errorId: map['error_id'] as String?,
      errorType: map['error_type'] as String?,
      exerciseTag: map['exercise_tag'] as String?,
      knowledgeTag: map['knowledge_tag'] as String?,
      progress: map['progress'] as String? ?? '待订正',
      question: map['question'] as String?,
      wrongAnswer: map['wrong_answer'] as String?,
      wrongWhere: map['wrong_where'] as String?,
      whyWrong: map['why_wrong'] as String?,
      howPrevent: map['how_prevent'] as String?,
      notes: map['notes'] as String?,
      images: map['images'] as String?,
    );
  }

  ErrorRecord copyWith({
    int? id,
    String? content,
    String? correctAnswer,
    String? subject,
    String? lesson,
    DateTime? createdAt,
    bool? reviewed,
    String? lang,
    String? contentPath,
    String? errorId,
    String? errorType,
    String? exerciseTag,
    String? knowledgeTag,
    String? progress,
    String? question,
    String? wrongAnswer,
    String? wrongWhere,
    String? whyWrong,
    String? howPrevent,
    String? notes,
    String? images,
  }) {
    return ErrorRecord(
      id: id ?? this.id,
      content: content ?? this.content,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      subject: subject ?? this.subject,
      lesson: lesson ?? this.lesson,
      createdAt: createdAt ?? this.createdAt,
      reviewed: reviewed ?? this.reviewed,
      lang: lang ?? this.lang,
      contentPath: contentPath ?? this.contentPath,
      errorId: errorId ?? this.errorId,
      errorType: errorType ?? this.errorType,
      exerciseTag: exerciseTag ?? this.exerciseTag,
      knowledgeTag: knowledgeTag ?? this.knowledgeTag,
      progress: progress ?? this.progress,
      question: question ?? this.question,
      wrongAnswer: wrongAnswer ?? this.wrongAnswer,
      wrongWhere: wrongWhere ?? this.wrongWhere,
      whyWrong: whyWrong ?? this.whyWrong,
      howPrevent: howPrevent ?? this.howPrevent,
      notes: notes ?? this.notes,
      images: images ?? this.images,
    );
  }
}

class ErrorRecordDao {
  final Database db;

  ErrorRecordDao(this.db);

  Future<int> insert(ErrorRecord record) async {
    return await db.insert('error_records', record.toMap());
  }

  Future<List<ErrorRecord>> getAll({
    String? lang,
    bool? reviewed,
    String? errorType,
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
    if (reviewed != null) {
      conditions.add('reviewed = ?');
      args.add(reviewed ? 1 : 0);
    }
    if (errorType != null) {
      conditions.add('error_type = ?');
      args.add(errorType);
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
      conditions.add('(content LIKE ? OR question LIKE ? OR error_id LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'error_records',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => ErrorRecord.fromMap(map)).toList();
  }

  Future<ErrorRecord?> getById(int id) async {
    final maps = await db.query(
      'error_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? ErrorRecord.fromMap(maps.first) : null;
  }

  Future<int> update(ErrorRecord record) async {
    return await db.update(
      'error_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'error_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count({String? lang, bool? reviewed}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (reviewed != null) {
      conditions.add('reviewed = ?');
      args.add(reviewed ? 1 : 0);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM error_records${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> nextErrorIdNumber() async {
    final result = await db.rawQuery(
      "SELECT error_id FROM error_records WHERE error_id LIKE 'T%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['error_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'T(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }
}
