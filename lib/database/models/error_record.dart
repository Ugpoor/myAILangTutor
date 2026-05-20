import 'package:sqflite/sqflite.dart';

class ErrorRecord {
  final int? id;
  final String content;
  final String? correctAnswer;
  final DateTime? createdAt;
  final String lang;
  final String? contentPath;
  final String? errorId;
  final String? errorType;
  final String progress;
  final String? question;
  final String? wrongAnswer;
  final String? wrongWhere;
  final String? whyWrong;
  final String? howPrevent;
  final String? notes;
  final String? images;
  final String? tid;
  final String? qid;
  final String? gradeMemo;
  final String? correction;
  final String? kid;
  final String? unitNumber;
  final String? lessonNumber;
  final String? cid;

  ErrorRecord({
    this.id,
    required this.content,
    this.correctAnswer,
    this.createdAt,
    this.lang = 'cn',
    this.contentPath,
    this.errorId,
    this.errorType,
    this.progress = '待订正',
    this.question,
    this.wrongAnswer,
    this.wrongWhere,
    this.whyWrong,
    this.howPrevent,
    this.notes,
    this.images,
    this.tid,
    this.qid,
    this.gradeMemo,
    this.correction,
    this.kid,
    this.unitNumber,
    this.lessonNumber,
    this.cid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'correct_answer': correctAnswer,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'content_path': contentPath,
      'error_id': errorId,
      'error_type': errorType,
      'progress': progress,
      'question': question,
      'wrong_answer': wrongAnswer,
      'wrong_where': wrongWhere,
      'why_wrong': whyWrong,
      'how_prevent': howPrevent,
      'notes': notes,
      'images': images,
      'tid': tid,
      'qid': qid,
      'grade_memo': gradeMemo,
      'correction': correction,
      'kid': kid,
      'unit_number': unitNumber,
      'lesson_number': lessonNumber,
      'cid': cid,
    };
  }

  static ErrorRecord fromMap(Map<String, dynamic> map) {
    return ErrorRecord(
      id: map['id'] as int?,
      content: map['content'] as String,
      correctAnswer: map['correct_answer'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      contentPath: map['content_path'] as String?,
      errorId: map['error_id'] as String?,
      errorType: map['error_type'] as String?,
      progress: map['progress'] as String? ?? '待订正',
      question: map['question'] as String?,
      wrongAnswer: map['wrong_answer'] as String?,
      wrongWhere: map['wrong_where'] as String?,
      whyWrong: map['why_wrong'] as String?,
      howPrevent: map['how_prevent'] as String?,
      notes: map['notes'] as String?,
      images: map['images'] as String?,
      tid: map['tid'] as String?,
      qid: map['qid'] as String?,
      gradeMemo: map['grade_memo'] as String?,
      correction: map['correction'] as String?,
      kid: map['kid'] as String?,
      unitNumber: map['unit_number'] as String?,
      lessonNumber: map['lesson_number'] as String?,
      cid: map['cid'] as String?,
    );
  }

  ErrorRecord copyWith({
    int? id,
    String? content,
    String? correctAnswer,
    DateTime? createdAt,
    String? lang,
    String? contentPath,
    String? errorId,
    String? errorType,
    String? progress,
    String? question,
    String? wrongAnswer,
    String? wrongWhere,
    String? whyWrong,
    String? howPrevent,
    String? notes,
    String? images,
    String? tid,
    String? qid,
    String? gradeMemo,
    String? correction,
    String? kid,
    String? unitNumber,
    String? lessonNumber,
    String? cid,
  }) {
    return ErrorRecord(
      id: id ?? this.id,
      content: content ?? this.content,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      contentPath: contentPath ?? this.contentPath,
      errorId: errorId ?? this.errorId,
      errorType: errorType ?? this.errorType,
      progress: progress ?? this.progress,
      question: question ?? this.question,
      wrongAnswer: wrongAnswer ?? this.wrongAnswer,
      wrongWhere: wrongWhere ?? this.wrongWhere,
      whyWrong: whyWrong ?? this.whyWrong,
      howPrevent: howPrevent ?? this.howPrevent,
      notes: notes ?? this.notes,
      images: images ?? this.images,
      tid: tid ?? this.tid,
      qid: qid ?? this.qid,
      gradeMemo: gradeMemo ?? this.gradeMemo,
      correction: correction ?? this.correction,
      kid: kid ?? this.kid,
      unitNumber: unitNumber ?? this.unitNumber,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      cid: cid ?? this.cid,
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
    String? errorType,
    String? progress,
    String? keyword,
    String? kid,
    String? cid,
    String? unitNumber,
    String? lessonNumber,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (errorType != null) {
      conditions.add('error_type = ?');
      args.add(errorType);
    }
    if (progress != null) {
      conditions.add('progress = ?');
      args.add(progress);
    }
    if (kid != null) {
      conditions.add('kid = ?');
      args.add(kid);
    }
    if (cid != null) {
      conditions.add('cid = ?');
      args.add(cid);
    }
    if (unitNumber != null) {
      conditions.add('unit_number = ?');
      args.add(unitNumber);
    }
    if (lessonNumber != null) {
      conditions.add('lesson_number = ?');
      args.add(lessonNumber);
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
    return await db.delete('error_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count({String? lang}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
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

  Future<int> deleteAll() async {
    final count = await this.count();
    if (count > 0) {
      await db.delete('error_records');
      return count;
    }
    return 0;
  }

  Future<int> deleteMathErrors() async {
    const mathKeywords = [
      'π=',
      'π值',
      '勾股定理',
      '二次方程',
      '一元二次方程',
      'x²=',
      'x^2=',
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
      '面积公式',
      '周长公式',
      '体积公式',
      '计算题',
      '求解',
      '方程式',
    ];

    List<String> conditions = [];
    List<dynamic> args = [];

    for (final keyword in mathKeywords) {
      conditions.add(
        '(content LIKE ? OR question LIKE ? OR error_type LIKE ?)',
      );
      args.addAll(['%$keyword%', '%$keyword%', '%$keyword%']);
    }

    if (conditions.isEmpty) return 0;

    final maps = await db.query(
      'error_records',
      where: conditions.join(' OR '),
      whereArgs: args,
    );

    if (maps.isEmpty) return 0;

    final ids = maps.map((m) => m['id'] as int).toList();
    return await db.delete(
      'error_records',
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<List<String>> getAllErrorTypes() async {
    final result = await db.rawQuery(
      'SELECT DISTINCT error_type FROM error_records WHERE error_type IS NOT NULL',
    );
    return result.map((map) => map['error_type'] as String).toList();
  }

  Future<List<String>> getAllCids() async {
    final result = await db.rawQuery(
      'SELECT DISTINCT cid FROM error_records WHERE cid IS NOT NULL',
    );
    return result.map((map) => map['cid'] as String).toList();
  }

  Future<List<String>> getAllKids() async {
    final result = await db.rawQuery(
      'SELECT DISTINCT kid FROM error_records WHERE kid IS NOT NULL',
    );
    return result.map((map) => map['kid'] as String).toList();
  }
}
