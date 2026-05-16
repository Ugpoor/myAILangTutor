
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
    );
  }
}

class ErrorRecordDao {
  final Database db;

  ErrorRecordDao(this.db);

  Future<int> insert(ErrorRecord record) async {
    return await db.insert('error_records', record.toMap());
  }

  Future<List<ErrorRecord>> getAll({String? lang, bool? reviewed}) async {
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
}
