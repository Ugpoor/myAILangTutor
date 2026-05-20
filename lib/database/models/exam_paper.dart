import 'package:sqflite/sqflite.dart';

/// 试卷模型（考试/测试的一次完整试卷）
class ExamPaper {
  final int? id;
  final String paperId; // E开头，如 E1, E2
  final String title; // 试卷标题
  final String? subject; // 科目
  final String? lessonUnit; // 课内单元
  final String? knowledgeTag; // 知识标签
  final DateTime? createdAt;
  final DateTime? examDate; // 考试日期
  final String lang;
  final int? totalScore; // 总分
  final int? duration; // 时长（分钟）
  final String status; // 状态：未开始/进行中/已完成

  ExamPaper({
    this.id,
    required this.paperId,
    required this.title,
    this.subject,
    this.lessonUnit,
    this.knowledgeTag,
    this.createdAt,
    this.examDate,
    this.lang = 'cn',
    this.totalScore,
    this.duration,
    this.status = '未开始',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paper_id': paperId,
      'title': title,
      'subject': subject,
      'lesson_unit': lessonUnit,
      'knowledge_tag': knowledgeTag,
      'created_at': createdAt?.toIso8601String(),
      'exam_date': examDate?.toIso8601String(),
      'lang': lang,
      'total_score': totalScore,
      'duration': duration,
      'status': status,
    };
  }

  static ExamPaper fromMap(Map<String, dynamic> map) {
    return ExamPaper(
      id: map['id'] as int?,
      paperId: map['paper_id'] as String,
      title: map['title'] as String,
      subject: map['subject'] as String?,
      lessonUnit: map['lesson_unit'] as String?,
      knowledgeTag: map['knowledge_tag'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      examDate: map['exam_date'] != null
          ? DateTime.parse(map['exam_date'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      totalScore: map['total_score'] as int?,
      duration: map['duration'] as int?,
      status: map['status'] as String? ?? '未开始',
    );
  }

  ExamPaper copyWith({
    int? id,
    String? paperId,
    String? title,
    String? subject,
    String? lessonUnit,
    String? knowledgeTag,
    DateTime? createdAt,
    DateTime? examDate,
    String? lang,
    int? totalScore,
    int? duration,
    String? status,
  }) {
    return ExamPaper(
      id: id ?? this.id,
      paperId: paperId ?? this.paperId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      lessonUnit: lessonUnit ?? this.lessonUnit,
      knowledgeTag: knowledgeTag ?? this.knowledgeTag,
      createdAt: createdAt ?? this.createdAt,
      examDate: examDate ?? this.examDate,
      lang: lang ?? this.lang,
      totalScore: totalScore ?? this.totalScore,
      duration: duration ?? this.duration,
      status: status ?? this.status,
    );
  }
}

class ExamPaperDao {
  final Database db;

  ExamPaperDao(this.db);

  Future<int> insert(ExamPaper paper) async {
    return await db.insert('exam_papers', paper.toMap());
  }

  Future<List<ExamPaper>> getAll({
    String? lang,
    String? subject,
    String? status,
    String? keyword,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (subject != null) {
      conditions.add('subject = ?');
      args.add(subject);
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(title LIKE ? OR paper_id LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'exam_papers',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'exam_date DESC, created_at DESC',
    );
    return maps.map((map) => ExamPaper.fromMap(map)).toList();
  }

  Future<ExamPaper?> getById(int id) async {
    final maps = await db.query(
      'exam_papers',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? ExamPaper.fromMap(maps.first) : null;
  }

  Future<ExamPaper?> getByPaperId(String paperId) async {
    final maps = await db.query(
      'exam_papers',
      where: 'paper_id = ?',
      whereArgs: [paperId],
    );
    return maps.isNotEmpty ? ExamPaper.fromMap(maps.first) : null;
  }

  Future<int> update(ExamPaper paper) async {
    return await db.update(
      'exam_papers',
      paper.toMap(),
      where: 'id = ?',
      whereArgs: [paper.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'exam_papers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> nextPaperIdNumber() async {
    final result = await db.rawQuery(
      "SELECT paper_id FROM exam_papers WHERE paper_id LIKE 'E%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['paper_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'E(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }

  /// 删除所有试卷
  Future<int> deleteAll() async {
    return await db.rawDelete('DELETE FROM exam_papers');
  }
}
