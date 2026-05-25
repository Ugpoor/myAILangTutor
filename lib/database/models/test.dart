import 'package:sqflite/sqflite.dart';

class Test {
  final int? id;
  final String tid;
  final String title;
  final List<String> lessonUnitList;
  final List<String> kids;
  final DateTime? createdAt;
  final DateTime? examDate;
  final DateTime? gradeDate;
  final String lang;
  final int? totalScore;
  final int? duration;
  final String status;
  final List<String> images;
  final String? content; // 全文搜索内容

  Test({
    this.id,
    required this.tid,
    required this.title,
    this.lessonUnitList = const [],
    this.kids = const [],
    this.createdAt,
    this.examDate,
    this.gradeDate,
    this.lang = 'cn',
    this.totalScore,
    this.duration,
    this.status = '未开始',
    this.images = const [],
    this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tid': tid,
      'title': title,
      'lesson_unit_list': lessonUnitList.join(','),
      'kids': kids.join(','),
      'created_at': createdAt?.toIso8601String(),
      'exam_date': examDate?.toIso8601String(),
      'grade_date': gradeDate?.toIso8601String(),
      'lang': lang,
      'total_score': totalScore,
      'duration': duration,
      'status': status,
      'images': images.join(','),
      'content': content,
    };
  }

  static Test fromMap(Map<String, dynamic> map) {
    return Test(
      id: map['id'] as int?,
      tid: map['tid'] as String,
      title: map['title'] as String,
      lessonUnitList: (map['lesson_unit_list'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      kids: (map['kids'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      examDate: map['exam_date'] != null
          ? DateTime.parse(map['exam_date'] as String)
          : null,
      gradeDate: map['grade_date'] != null
          ? DateTime.parse(map['grade_date'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      totalScore: map['total_score'] as int?,
      duration: map['duration'] as int?,
      status: map['status'] as String? ?? '未开始',
      images: (map['images'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      content: map['content'] as String?,
    );
  }

  Test copyWith({
    int? id,
    String? tid,
    String? title,
    List<String>? lessonUnitList,
    List<String>? kids,
    DateTime? createdAt,
    DateTime? examDate,
    DateTime? gradeDate,
    String? lang,
    int? totalScore,
    int? duration,
    String? status,
    List<String>? images,
    String? content,
  }) {
    return Test(
      id: id ?? this.id,
      tid: tid ?? this.tid,
      title: title ?? this.title,
      lessonUnitList: lessonUnitList ?? this.lessonUnitList,
      kids: kids ?? this.kids,
      createdAt: createdAt ?? this.createdAt,
      examDate: examDate ?? this.examDate,
      gradeDate: gradeDate ?? this.gradeDate,
      lang: lang ?? this.lang,
      totalScore: totalScore ?? this.totalScore,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      images: images ?? this.images,
      content: content ?? this.content,
    );
  }
}

class TestDao {
  final Database db;

  TestDao(this.db);

  Future<int> insert(Test test) async {
    return await db.insert('tests', test.toMap());
  }

  Future<List<Test>> getAll({
    String? lang,
    String? status,
    String? keyword,
    String? contentKeyword,
    List<String>? unitNumbers,
    List<String>? lessonNumbers,
    List<String>? kidList,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(title LIKE ? OR tid LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }
    if (contentKeyword != null && contentKeyword.isNotEmpty) {
      conditions.add('content LIKE ?');
      args.add('%$contentKeyword%');
    }
    if (unitNumbers != null && unitNumbers.isNotEmpty) {
      conditions.add('lesson_unit_list LIKE ?');
      args.add('%${unitNumbers.join('%')}%');
    }
    if (lessonNumbers != null && lessonNumbers.isNotEmpty) {
      conditions.add('lesson_unit_list LIKE ?');
      args.add('%${lessonNumbers.join('%')}%');
    }
    if (kidList != null && kidList.isNotEmpty) {
      conditions.add('kids LIKE ?');
      args.add('%${kidList.join('%')}%');
    }

    final maps = await db.query(
      'tests',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'exam_date DESC, created_at DESC',
    );
    return maps.map((map) => Test.fromMap(map)).toList();
  }

  Future<Test?> getById(int id) async {
    final maps = await db.query(
      'tests',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? Test.fromMap(maps.first) : null;
  }

  Future<Test?> getByTid(String tid) async {
    final maps = await db.query(
      'tests',
      where: 'tid = ?',
      whereArgs: [tid],
    );
    return maps.isNotEmpty ? Test.fromMap(maps.first) : null;
  }

  Future<int> update(Test test) async {
    return await db.update(
      'tests',
      test.toMap(),
      where: 'id = ?',
      whereArgs: [test.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'tests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> nextTidNumber() async {
    final result = await db.rawQuery(
      "SELECT tid FROM tests WHERE tid LIKE 'T%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['tid'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'T(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }

  Future<int> deleteAll() async {
    return await db.rawDelete('DELETE FROM tests');
  }
}