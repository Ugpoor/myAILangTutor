import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 知识点数据模型
///
/// 知识点是学习内容的基本单元，用于存储和管理知识卡片信息。

class KnowledgePoint {
  final int? id; // 数据库自增主键
  final String? kid; // 知识点唯一标识，格式为 "K" + id（如 K1, K2），用于跨模块引用
  final String title; // 知识点标题
  final String? unitNumber; // 单元号（如 "1" 表示第1单元）
  final String? lessonNumber; // 课号（如 "3" 表示第3课）
  final String cid; // 知识点大纲分类ID，用于关联知识点大纲
  final DateTime? createdAt; // 创建时间
  final DateTime? lastPracticeTime; // 最后练习时间
  final String lang; // 语言标识（cn/en）
  final String? contentPath; // 内容文件路径，知识点详细内容存储在文件系统中
  final String? knowledgeTag; // 知识标签（冗余字段，用于兼容旧数据）
  final int testTimes; // 测试次数
  final int errorTimes; // 错误次数
  final String? testRecs; // 测试记录（JSON格式存储）
  final String? errorRecs; // 错误记录（JSON格式存储）
  final String? brief; // 知识点摘要/简介

  KnowledgePoint({
    this.id,
    this.kid,
    required this.title,
    this.unitNumber,
    this.lessonNumber,
    required this.cid,
    this.createdAt,
    this.lastPracticeTime,
    this.lang = 'cn',
    this.contentPath,
    this.knowledgeTag,
    this.testTimes = 0,
    this.errorTimes = 0,
    this.testRecs,
    this.errorRecs,
    this.brief,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kid': kid,
      'title': title,
      'unit_number': unitNumber,
      'lesson_number': lessonNumber,
      'cid': cid,
      'created_at': createdAt?.toIso8601String(),
      'last_practice_time': lastPracticeTime?.toIso8601String(),
      'lang': lang,
      'content_path': contentPath,
      'knowledge_tag': knowledgeTag,
      'test_times': testTimes,
      'error_times': errorTimes,
      'test_recs': testRecs,
      'error_recs': errorRecs,
      'brief': brief,
    };
  }

  static KnowledgePoint fromMap(Map<String, dynamic> map) {
    return KnowledgePoint(
      id: map['id'] as int?,
      kid: map['kid'] as String?,
      title: map['title'] as String,
      unitNumber: map['unit_number'] as String?,
      lessonNumber: map['lesson_number'] as String?,
      cid: map['cid'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lastPracticeTime: map['last_practice_time'] != null
          ? DateTime.parse(map['last_practice_time'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      contentPath: map['content_path'] as String?,
      knowledgeTag: map['knowledge_tag'] as String?,
      testTimes: map['test_times'] as int? ?? 0,
      errorTimes: map['error_times'] as int? ?? 0,
      testRecs: map['test_recs'] as String?,
      errorRecs: map['error_recs'] as String?,
      brief: map['brief'] as String?,
    );
  }

  KnowledgePoint copyWith({
    int? id,
    String? kid,
    String? title,
    String? unitNumber,
    String? lessonNumber,
    String? cid,
    DateTime? createdAt,
    DateTime? lastPracticeTime,
    String? lang,
    String? contentPath,
    String? knowledgeTag,
    int? testTimes,
    int? errorTimes,
    String? testRecs,
    String? errorRecs,
    String? brief,
  }) {
    return KnowledgePoint(
      id: id ?? this.id,
      kid: kid ?? this.kid,
      title: title ?? this.title,
      unitNumber: unitNumber ?? this.unitNumber,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      cid: cid ?? this.cid,
      createdAt: createdAt ?? this.createdAt,
      lastPracticeTime: lastPracticeTime ?? this.lastPracticeTime,
      lang: lang ?? this.lang,
      contentPath: contentPath ?? this.contentPath,
      knowledgeTag: knowledgeTag ?? this.knowledgeTag,
      testTimes: testTimes ?? this.testTimes,
      errorTimes: errorTimes ?? this.errorTimes,
      testRecs: testRecs ?? this.testRecs,
      errorRecs: errorRecs ?? this.errorRecs,
      brief: brief ?? this.brief,
    );
  }
}

class KnowledgePointDao {
  final Database db;

  KnowledgePointDao(this.db);

  Future<int> insert(KnowledgePoint point) async {
    final id = await db.insert('knowledge_points', point.toMap());
    if (id > 0) {
      // 如果已经有 wid 和 contentPath，则不重新生成
      if (point.kid == null || point.contentPath == null) {
        final kid = 'K$id';

        final documentsDir = await getApplicationDocumentsDirectory();
        final knowledgeDir = Directory('${documentsDir.path}/knowledge/$kid');
        if (!await knowledgeDir.exists()) {
          await knowledgeDir.create(recursive: true);
        }

        final contentPath = knowledgeDir.path;

        await db.update(
          'knowledge_points',
          {'kid': kid, 'content_path': contentPath},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // 只更新 kid（如果已经有 contentPath）
        if (point.kid != null) {
          await db.update(
            'knowledge_points',
            {'kid': point.kid},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }
    return id;
  }

  Future<List<KnowledgePoint>> getAll({
    String? lang,
    String? unitNumber,
    String? lessonNumber,
    List<String>? tags,
    String? keyword,
    String? cid,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (unitNumber != null) {
      conditions.add('unit_number = ?');
      args.add(unitNumber);
    }
    if (lessonNumber != null) {
      conditions.add('lesson_number = ?');
      args.add(lessonNumber);
    }
    if (cid != null) {
      conditions.add('cid = ?');
      args.add(cid);
    }
    if (keyword != null) {
      conditions.add('(title LIKE ? OR brief LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  Future<KnowledgePoint?> getById(int id) async {
    final maps = await db.query(
      'knowledge_points',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? KnowledgePoint.fromMap(maps.first) : null;
  }

  Future<KnowledgePoint?> getByPid(String kid) async {
    final maps = await db.query(
      'knowledge_points',
      where: 'kid = ?',
      whereArgs: [kid],
    );
    return maps.isNotEmpty ? KnowledgePoint.fromMap(maps.first) : null;
  }

  Future<List<KnowledgePoint>> getByCid(String cid, {String? lang}) async {
    List<String> conditions = ['cid = ?'];
    List<dynamic> args = [cid];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  Future<List<KnowledgePoint>> getByCids(
    List<String> cids, {
    String? lang,
  }) async {
    if (cids.isEmpty) return [];

    List<String> conditions = ['cid IN (${cids.map((_) => '?').join(',')})'];
    List<dynamic> args = List.from(cids);

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  Future<int> update(KnowledgePoint point) async {
    return await db.update(
      'knowledge_points',
      point.toMap(),
      where: 'id = ?',
      whereArgs: [point.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'knowledge_points',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count({String? lang, String? cid}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (cid != null) {
      conditions.add('cid = ?');
      args.add(cid);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM knowledge_points${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getAllUnitNumbers() async {
    final result = await db.rawQuery(
      'SELECT DISTINCT unit_number FROM knowledge_points WHERE unit_number IS NOT NULL',
    );
    return result.map((map) => map['unit_number'] as String).toList();
  }

  Future<List<String>> getAllCids() async {
    final result = await db.rawQuery(
      'SELECT DISTINCT cid FROM knowledge_points WHERE cid IS NOT NULL',
    );
    return result.map((map) => map['cid'] as String).toList();
  }

  Future<List<KnowledgePoint>> searchByTitleOrBrief(
    String query, {
    String? lang,
  }) async {
    List<String> conditions = ['(title LIKE ? OR brief LIKE ?)'];
    List<dynamic> args = ['%$query%', '%$query%'];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: 20,
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  Future<int> incrementTestTimes(int id) async {
    return await db.rawUpdate(
      'UPDATE knowledge_points SET test_times = test_times + 1 WHERE id = ?',
      [id],
    );
  }

  Future<int> incrementErrorTimes(int id) async {
    return await db.rawUpdate(
      'UPDATE knowledge_points SET error_times = error_times + 1 WHERE id = ?',
      [id],
    );
  }

  Future<int> addTestRec(int id, String testId) async {
    final point = await getById(id);
    if (point == null) return 0;

    List<String> recs = point.testRecs != null
        ? (point.testRecs!.isEmpty ? [] : point.testRecs!.split(','))
        : [];

    if (!recs.contains(testId)) {
      recs.add(testId);
      return await db.rawUpdate(
        'UPDATE knowledge_points SET test_recs = ? WHERE id = ?',
        [recs.join(','), id],
      );
    }
    return 0;
  }

  Future<int> addErrorRec(int id, String errorId) async {
    final point = await getById(id);
    if (point == null) return 0;

    List<String> recs = point.errorRecs != null
        ? (point.errorRecs!.isEmpty ? [] : point.errorRecs!.split(','))
        : [];

    if (!recs.contains(errorId)) {
      recs.add(errorId);
      return await db.rawUpdate(
        'UPDATE knowledge_points SET error_recs = ? WHERE id = ?',
        [recs.join(','), id],
      );
    }
    return 0;
  }

  Future<int> updateLastPracticeTime(int id, DateTime time) async {
    return await db.rawUpdate(
      'UPDATE knowledge_points SET last_practice_time = ? WHERE id = ?',
      [time.toIso8601String(), id],
    );
  }

  Future<int> deleteMathKnowledgePoints() async {
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
      '积分',
      '面积公式',
      '周长公式',
      '体积公式',
    ];

    int deletedCount = 0;

    for (final keyword in mathKeywords) {
      final result = await db.rawDelete(
        "DELETE FROM knowledge_points WHERE "
        "(title LIKE ? OR brief LIKE ? OR knowledge_tag LIKE ?)",
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      deletedCount += result;
    }

    return deletedCount;
  }
}
