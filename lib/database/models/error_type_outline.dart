import 'package:sqflite/sqflite.dart';

/// 错类大纲数据模型
/// 
/// 错类大纲用于组织和管理错误类型的层级结构，支持多级分类。
/// 使用点分ID体系表示层级关系，如：
/// 1. 概念混淆
///   1.1 近义词辨析错误
///   1.2 形近字混淆

class ErrorTypeOutline {
  final int? id;                    // 数据库自增主键
  final String eid;                 // 错类唯一标识，使用点分ID（如 1, 1.1, 1.2）
  final String content;             // 错类内容
  final String lang;                // 语言标识（cn/en）
  final DateTime? createdAt;        // 创建时间
  final DateTime? updatedAt;        // 更新时间

  ErrorTypeOutline({
    this.id,
    required this.eid,
    required this.content,
    this.lang = 'cn',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eid': eid,
      'content': content,
      'lang': lang,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static ErrorTypeOutline fromMap(Map<String, dynamic> map) {
    return ErrorTypeOutline(
      id: map['id'] as int?,
      eid: map['eid'] as String,
      content: map['content'] as String,
      lang: map['lang'] as String? ?? 'cn',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}

class ErrorTypeOutlineDao {
  final Database db;

  ErrorTypeOutlineDao(this.db);

  Future<int> insert(ErrorTypeOutline outline) async {
    final now = DateTime.now();
    final outlineWithTimestamps = ErrorTypeOutline(
      eid: outline.eid,
      content: outline.content,
      lang: outline.lang,
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert('error_type_outlines', outlineWithTimestamps.toMap());
  }

  Future<List<ErrorTypeOutline>> getAll({String? lang}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'error_type_outlines',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'eid ASC',
    );
    return maps.map((map) => ErrorTypeOutline.fromMap(map)).toList();
  }

  Future<ErrorTypeOutline?> getById(int id) async {
    final maps = await db.query(
      'error_type_outlines',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? ErrorTypeOutline.fromMap(maps.first) : null;
  }

  Future<ErrorTypeOutline?> getByEid(String eid, {String? lang}) async {
    List<String> conditions = ['eid = ?'];
    List<dynamic> args = [eid];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }

    final maps = await db.query(
      'error_type_outlines',
      where: conditions.join(' AND '),
      whereArgs: args,
    );
    return maps.isNotEmpty ? ErrorTypeOutline.fromMap(maps.first) : null;
  }

  Future<int> update(ErrorTypeOutline outline) async {
    final updatedOutline = ErrorTypeOutline(
      id: outline.id,
      eid: outline.eid,
      content: outline.content,
      lang: outline.lang,
      createdAt: outline.createdAt,
      updatedAt: DateTime.now(),
    );
    return await db.update(
      'error_type_outlines',
      updatedOutline.toMap(),
      where: 'id = ?',
      whereArgs: [outline.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'error_type_outlines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByEid(String eid) async {
    return await db.delete(
      'error_type_outlines',
      where: 'eid = ?',
      whereArgs: [eid],
    );
  }
}