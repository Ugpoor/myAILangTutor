import 'package:sqflite/sqflite.dart';

class PortfolioItem {
  final int? id;
  final String title;
  final String? type;
  final String? contentPath;
  final String? thumbnailPath;
  final DateTime? createdAt;
  final String lang;
  final String? portfolioId;
  final bool isOriginal;
  final String? knowledgeTag;
  final String? lessonUnit;
  final String? aiReview;
  final String? content; // 文章内容正文

  PortfolioItem({
    this.id,
    required this.title,
    this.type,
    this.contentPath,
    this.thumbnailPath,
    this.createdAt,
    this.lang = 'cn',
    this.portfolioId,
    this.isOriginal = false,
    this.knowledgeTag,
    this.lessonUnit,
    this.aiReview,
    this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'content_path': contentPath,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'portfolio_id': portfolioId,
      'is_original': isOriginal ? 1 : 0,
      'knowledge_tag': knowledgeTag,
      'lesson_unit': lessonUnit,
      'ai_review': aiReview,
      'content': content,
    };
  }

  static PortfolioItem fromMap(Map<String, dynamic> map) {
    return PortfolioItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      type: map['type'] as String?,
      contentPath: map['content_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      portfolioId: map['portfolio_id'] as String?,
      isOriginal: (map['is_original'] as int?) == 1,
      knowledgeTag: map['knowledge_tag'] as String?,
      lessonUnit: map['lesson_unit'] as String?,
      aiReview: map['ai_review'] as String?,
      content: map['content'] as String?,
    );
  }

  PortfolioItem copyWith({
    int? id,
    String? title,
    String? type,
    String? contentPath,
    String? thumbnailPath,
    DateTime? createdAt,
    String? lang,
    String? portfolioId,
    bool? isOriginal,
    String? knowledgeTag,
    String? lessonUnit,
    String? aiReview,
    String? content,
  }) {
    return PortfolioItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      contentPath: contentPath ?? this.contentPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      portfolioId: portfolioId ?? this.portfolioId,
      isOriginal: isOriginal ?? this.isOriginal,
      knowledgeTag: knowledgeTag ?? this.knowledgeTag,
      lessonUnit: lessonUnit ?? this.lessonUnit,
      aiReview: aiReview ?? this.aiReview,
      content: content ?? this.content,
    );
  }
}

class PortfolioDao {
  final Database db;

  PortfolioDao(this.db);

  Future<int> insert(PortfolioItem item) async {
    return await db.insert('portfolio_items', item.toMap());
  }

  Future<List<PortfolioItem>> getAll({
    String? lang,
    String? type,
    bool? isOriginal,
    String? knowledgeTag,
    String? lessonUnit,
    String? keyword,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (isOriginal != null) {
      conditions.add('is_original = ?');
      args.add(isOriginal ? 1 : 0);
    }
    if (knowledgeTag != null) {
      conditions.add('knowledge_tag LIKE ?');
      args.add('%$knowledgeTag%');
    }
    if (lessonUnit != null) {
      conditions.add('lesson_unit = ?');
      args.add(lessonUnit);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(title LIKE ? OR portfolio_id LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'portfolio_items',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => PortfolioItem.fromMap(map)).toList();
  }

  Future<PortfolioItem?> getById(int id) async {
    final maps = await db.query(
      'portfolio_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? PortfolioItem.fromMap(maps.first) : null;
  }

  Future<int> update(PortfolioItem item) async {
    return await db.update(
      'portfolio_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'portfolio_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除所有作品集条目
  Future<int> deleteAll() async {
    // 先计算总数用于返回
    final count = await this.count();
    if (count > 0) {
      await db.delete('portfolio_items');
      return count;
    }
    return 0;
  }

  Future<int> count({String? lang, String? type, bool? isOriginal}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (isOriginal != null) {
      conditions.add('is_original = ?');
      args.add(isOriginal ? 1 : 0);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM portfolio_items${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> nextPortfolioIdNumber() async {
    final result = await db.rawQuery(
      "SELECT portfolio_id FROM portfolio_items WHERE portfolio_id LIKE 'W%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['portfolio_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'W(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }
}
