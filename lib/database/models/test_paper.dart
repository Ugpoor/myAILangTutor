import 'package:sqflite/sqflite.dart';

class QuestionItem {
  final String qid;
  final String question;
  final List<String> correctAnswer;
  final List<String> answerSheet;
  final String? explanation;
  final int difficulty;
  final bool completed;
  final DateTime? createdAt;
  final String lang;
  final List<Map<String, List<List<int>>>> imageCont;
  final String? kid;
  final String? unitNumber;
  final String? lessonNumber;

  QuestionItem({
    required this.qid,
    required this.question,
    required this.correctAnswer,
    required this.answerSheet,
    this.explanation,
    this.difficulty = 1,
    this.completed = false,
    this.createdAt,
    this.lang = 'cn',
    required this.imageCont,
    this.kid,
    this.unitNumber,
    this.lessonNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'qid': qid,
      'question': question,
      'correct_answer': correctAnswer.join('|||'),
      'answer_sheet': answerSheet.join('|||'),
      'explanation': explanation,
      'difficulty': difficulty,
      'completed': completed ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'image_cont': _encodeImageCont(imageCont),
      'kid': kid,
      'unit_number': unitNumber,
      'lesson_number': lessonNumber,
    };
  }

  static QuestionItem fromMap(Map<String, dynamic> map) {
    return QuestionItem(
      qid: map['qid'] as String,
      question: map['question'] as String,
      correctAnswer: (map['correct_answer'] as String?)?.split('|||') ?? [],
      answerSheet: (map['answer_sheet'] as String?)?.split('|||') ?? [],
      explanation: map['explanation'] as String?,
      difficulty: map['difficulty'] as int? ?? 1,
      completed: (map['completed'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      imageCont: _decodeImageCont(map['image_cont'] as String?),
      kid: map['kid'] as String?,
      unitNumber: map['unit_number'] as String?,
      lessonNumber: map['lesson_number'] as String?,
    );
  }

  static String _encodeImageCont(List<Map<String, List<List<int>>>> imageCont) {
    List<String> parts = [];
    for (final item in imageCont) {
      item.forEach((key, value) {
        String coords = value.map((p) => '${p[0]},${p[1]}').join(';');
        parts.add('$key:$coords');
      });
    }
    return parts.join('|');
  }

  static List<Map<String, List<List<int>>>> _decodeImageCont(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    List<Map<String, List<List<int>>>> result = [];
    for (final part in encoded.split('|')) {
      final parts = part.split(':');
      if (parts.length == 2) {
        final key = parts[0];
        final coords = parts[1].split(';').map((c) {
          final xy = c.split(',').map(int.parse).toList();
          return [xy[0], xy[1]];
        }).toList();
        result.add({key: coords});
      }
    }
    return result;
  }
}

class TestPaper {
  final int? id;
  final String testTitle;
  final String? tid;
  final List<String> images;
  final List<QuestionItem> questionList;
  final String contentPath;
  final String? unitNumber;
  final String? lessonNumber;
  final String? source;
  final DateTime? createdAt;
  final String lang;

  TestPaper({
    this.id,
    required this.testTitle,
    this.tid,
    required this.images,
    required this.questionList,
    required this.contentPath,
    this.unitNumber,
    this.lessonNumber,
    this.source,
    this.createdAt,
    this.lang = 'cn',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'test_title': testTitle,
      'tid': tid,
      'images': images.join('|||'),
      'question_list': _encodeQuestionList(questionList),
      'content_path': contentPath,
      'unit_number': unitNumber,
      'lesson_number': lessonNumber,
      'source': source,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
    };
  }

  static TestPaper fromMap(Map<String, dynamic> map) {
    return TestPaper(
      id: map['id'] as int?,
      testTitle: map['test_title'] as String,
      tid: map['tid'] as String?,
      images: (map['images'] as String?)?.split('|||') ?? [],
      questionList: _decodeQuestionList(map['question_list'] as String?),
      contentPath: map['content_path'] as String,
      unitNumber: map['unit_number'] as String?,
      lessonNumber: map['lesson_number'] as String?,
      source: map['source'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
    );
  }

  static String _encodeQuestionList(List<QuestionItem> questions) {
    List<String> encoded = [];
    for (final q in questions) {
      encoded.add(q.toMap().entries.map((e) => '${e.key}=${e.value}').join(';'));
    }
    return encoded.join('|||');
  }

  static List<QuestionItem> _decodeQuestionList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    List<QuestionItem> questions = [];
    for (final part in encoded.split('|||')) {
      Map<String, dynamic> map = {};
      for (final kv in part.split(';')) {
        final idx = kv.indexOf('=');
        if (idx > 0) {
          final key = kv.substring(0, idx);
          final value = kv.substring(idx + 1);
          map[key] = value;
        }
      }
      if (map.isNotEmpty) {
        questions.add(QuestionItem.fromMap(map));
      }
    }
    return questions;
  }

  TestPaper copyWith({
    int? id,
    String? testTitle,
    String? tid,
    List<String>? images,
    List<QuestionItem>? questionList,
    String? contentPath,
    String? unitNumber,
    String? lessonNumber,
    String? source,
    DateTime? createdAt,
    String? lang,
  }) {
    return TestPaper(
      id: id ?? this.id,
      testTitle: testTitle ?? this.testTitle,
      tid: tid ?? this.tid,
      images: images ?? this.images,
      questionList: questionList ?? this.questionList,
      contentPath: contentPath ?? this.contentPath,
      unitNumber: unitNumber ?? this.unitNumber,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
    );
  }
}

class TestPaperDao {
  final Database db;

  TestPaperDao(this.db);

  Future<int> insert(TestPaper paper) async {
    final id = await db.insert('test_papers', paper.toMap());
    if (id > 0 && paper.tid == null) {
      final tid = 'T$id';
      await db.update(
        'test_papers',
        {'tid': tid},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return id;
  }

  Future<List<TestPaper>> getAll({
    String? lang,
    String? source,
    String? unitNumber,
    String? lessonNumber,
    String? keyword,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (source != null) {
      conditions.add('source = ?');
      args.add(source);
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
      conditions.add('(test_title LIKE ? OR tid LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'test_papers',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => TestPaper.fromMap(map)).toList();
  }

  Future<TestPaper?> getById(int id) async {
    final maps = await db.query(
      'test_papers',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? TestPaper.fromMap(maps.first) : null;
  }

  Future<TestPaper?> getByTid(String tid) async {
    final maps = await db.query(
      'test_papers',
      where: 'tid = ?',
      whereArgs: [tid],
    );
    return maps.isNotEmpty ? TestPaper.fromMap(maps.first) : null;
  }

  Future<int> update(TestPaper paper) async {
    return await db.update(
      'test_papers',
      paper.toMap(),
      where: 'id = ?',
      whereArgs: [paper.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'test_papers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count({String? lang}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM test_papers${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteAll() async {
    return await db.rawDelete('DELETE FROM test_papers');
  }
}