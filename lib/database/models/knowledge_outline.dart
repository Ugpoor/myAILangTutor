import 'package:sqflite/sqflite.dart';

class KnowledgeOutline {
  final int? id;
  final String cid;
  final String? fid;
  final String content;
  final String lang;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  KnowledgeOutline({
    this.id,
    required this.cid,
    this.fid,
    required this.content,
    this.lang = 'cn',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cid': cid,
      'fid': fid,
      'content': content,
      'lang': lang,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static KnowledgeOutline fromMap(Map<String, dynamic> map) {
    return KnowledgeOutline(
      id: map['id'] as int?,
      cid: map['cid'] as String,
      fid: map['fid'] as String?,
      content: map['content'] as String,
      lang: map['lang'] as String? ?? 'cn',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}

class KnowledgeOutlineDao {
  final Database db;

  KnowledgeOutlineDao(this.db);

  Future<int> insert(KnowledgeOutline outline) async {
    final now = DateTime.now();
    final outlineWithTimestamps = KnowledgeOutline(
      cid: outline.cid,
      fid: outline.fid,
      content: outline.content,
      lang: outline.lang,
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert('knowledge_outlines', outlineWithTimestamps.toMap());
  }

  Future<List<KnowledgeOutline>> getAll({String? lang}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_outlines',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'cid ASC',
    );
    return maps.map((map) => KnowledgeOutline.fromMap(map)).toList();
  }

  Future<KnowledgeOutline?> getByCid(String cid, {String? lang}) async {
    List<String> conditions = ['cid = ?'];
    List<dynamic> args = [cid];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_outlines',
      where: conditions.join(' AND '),
      whereArgs: args,
    );
    return maps.isNotEmpty ? KnowledgeOutline.fromMap(maps.first) : null;
  }

  Future<List<KnowledgeOutline>> getByFid(String fid, {String? lang}) async {
    List<String> conditions = ['fid = ?'];
    List<dynamic> args = [fid];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'knowledge_outlines',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'cid ASC',
    );
    return maps.map((map) => KnowledgeOutline.fromMap(map)).toList();
  }

  Future<int> update(KnowledgeOutline outline) async {
    final updatedOutline = KnowledgeOutline(
      id: outline.id,
      cid: outline.cid,
      fid: outline.fid,
      content: outline.content,
      lang: outline.lang,
      createdAt: outline.createdAt,
      updatedAt: DateTime.now(),
    );
    return await db.update(
      'knowledge_outlines',
      updatedOutline.toMap(),
      where: 'id = ?',
      whereArgs: [outline.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'knowledge_outlines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByCid(String cid) async {
    return await db.delete(
      'knowledge_outlines',
      where: 'cid = ?',
      whereArgs: [cid],
    );
  }
}