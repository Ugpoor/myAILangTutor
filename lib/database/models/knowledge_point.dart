import 'package:sqflite/sqflite.dart';

class KnowledgePoint {
  final int? id;
  final String title;
  final String? content;
  final String? category;
  final String? lessonUnit;
  final String? errorType;
  final int? parentId;
  final String? cid;      // 类 ID（知识谱分类标识）
  final int? fatherId;    // 父节点 ID（大纲层级中的父亲节点）
  final int difficulty;
  final bool mastered;
  final DateTime? createdAt;
  final String lang;
  final String? contentPath;
  final String? knowledgeTag;

  KnowledgePoint({
    this.id,
    required this.title,
    this.content,
    this.category,
    this.lessonUnit,
    this.errorType,
    this.parentId,
    this.cid,
    this.fatherId,
    this.difficulty = 1,
    this.mastered = false,
    this.createdAt,
    this.lang = 'cn',
    this.contentPath,
    this.knowledgeTag,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'lesson_unit': lessonUnit,
      'error_type': errorType,
      'difficulty': difficulty,
      'mastered': mastered ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'content_path': contentPath,
      'knowledge_tag': knowledgeTag,
    };
  }

  static KnowledgePoint fromMap(Map<String, dynamic> map) {
    return KnowledgePoint(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String?,
      category: map['category'] as String?,
      lessonUnit: map['lesson_unit'] as String?,
      errorType: map['error_type'] as String?,
      parentId: map['parent_id'] as int?,
      cid: map['cid'] as String?,
      fatherId: map['father_id'] as int?,
      difficulty: map['difficulty'] as int? ?? 1,
      mastered: (map['mastered'] as int?) == 1,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : null,
      lang: map['lang'] as String? ?? 'cn',
      contentPath: map['content_path'] as String?,
      knowledgeTag: map['knowledge_tag'] as String?,
    );
  }

  KnowledgePoint copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    String? lessonUnit,
    String? errorType,
    int? parentId,
    String? cid,
    int? fatherId,
    int? difficulty,
    bool? mastered,
    DateTime? createdAt,
    String? lang,
    String? contentPath,
    String? knowledgeTag,
  }) {
    return KnowledgePoint(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      lessonUnit: lessonUnit ?? this.lessonUnit,
      errorType: errorType ?? this.errorType,
      parentId: parentId ?? this.parentId,
      cid: cid ?? this.cid,
      fatherId: fatherId ?? this.fatherId,
      difficulty: difficulty ?? this.difficulty,
      mastered: mastered ?? this.mastered,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      contentPath: contentPath ?? this.contentPath,
      knowledgeTag: knowledgeTag ?? this.knowledgeTag,
    );
  }
}

class KnowledgePointDao {
  final Database db;

  KnowledgePointDao(this.db);

  Future<int> insert(KnowledgePoint point) async {
    return await db.insert('knowledge_points', point.toMap());
  }

  Future<List<KnowledgePoint>> getAll({
    String? lang, 
    String? category,
    String? lessonUnit,
    String? errorType,
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
    if (lessonUnit != null) {
      conditions.add('lesson_unit LIKE ?');
      args.add('%$lessonUnit%');
    }
    if (errorType != null) {
      conditions.add('error_type LIKE ?');
      args.add('%$errorType%');
    }
    if (keyword != null) {
      conditions.add('(title LIKE ? OR content LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'id ASC',
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

  Future<int> count({String? lang, String? category}) async {
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

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM knowledge_points${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getAllCategories() async {
    final result = await db.rawQuery('SELECT DISTINCT category FROM knowledge_points WHERE category IS NOT NULL');
    return result.map((map) => map['category'] as String).toList();
  }

  Future<List<String>> getAllLessonUnits() async {
    final result = await db.rawQuery('SELECT DISTINCT lesson_unit FROM knowledge_points WHERE lesson_unit IS NOT NULL');
    return result.map((map) => map['lesson_unit'] as String).toList();
  }

  Future<List<String>> getAllErrorTypes() async {
    final result = await db.rawQuery('SELECT DISTINCT error_type FROM knowledge_points WHERE error_type IS NOT NULL');
    return result.map((map) => map['error_type'] as String).toList();
  }

  /// 获取指定父级 ID 下的子知识点
  Future<List<KnowledgePoint>> getByParentId(int parentId, {String? lang}) async {
    List<String> conditions = ['parent_id = ?'];
    List<dynamic> args = [parentId];
    
    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'id ASC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  /// 获取所有根节点（无父级的知识点）
  Future<List<KnowledgePoint>> getRootNodes({String? lang}) async {
    List<String> conditions = ['parent_id IS NULL'];
    List<dynamic> args = [];
    
    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'id ASC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  /// 根据 cid 查找知识点
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
      orderBy: 'id ASC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  /// 根据 fatherId 查找子知识点
  Future<List<KnowledgePoint>> getByFatherId(int fatherId, {String? lang}) async {
    List<String> conditions = ['father_id = ?'];
    List<dynamic> args = [fatherId];
    
    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'id ASC',
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  /// 根据 cid 模糊匹配搜索知识点
  Future<List<KnowledgePoint>> searchByCidOrTitle(String query, {String? lang}) async {
    List<String> conditions = ['(cid LIKE ? OR title LIKE ?)'];
    List<dynamic> args = ['%$query%', '%$query%'];
    
    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_points',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'id ASC',
      limit: 20,
    );
    return maps.map((map) => KnowledgePoint.fromMap(map)).toList();
  }

  /// 获取指定知识点的父类知识点（基于 fatherId）
  Future<KnowledgePoint?> getParentByFatherId(int childId, {String? lang}) async {
    final point = await getById(childId);
    if (point?.fatherId == null) return null;
    
    return await getByFatherId(point!.fatherId!, lang: lang).then(
      (list) => list.isNotEmpty ? list.first : null,
    );
  }

  /// 获取指定知识点的所有子类知识点（基于 fatherId）
  Future<List<KnowledgePoint>> getAllChildrenByFatherId(int fatherId, {String? lang}) async {
    return getByFatherId(fatherId, lang: lang);
  }
}
