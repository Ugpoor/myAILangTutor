import 'package:sqflite/sqflite.dart';

class PortfolioItem {
  final int? id;
  final String? wid;
  final String title;
  final String? contentPath;
  final String? thumbnailPath;
  final DateTime? createdAt;
  final String lang;
  final bool isOriginal;
  final String? aiReview;
  final String? brief;
  final String? kid;
  final String? unitNumber;
  final String? lessonNumber;

  PortfolioItem({
    this.id,
    this.wid,
    required this.title,
    this.contentPath,
    this.thumbnailPath,
    this.createdAt,
    this.lang = 'cn',
    this.isOriginal = false,
    this.aiReview,
    this.brief,
    this.kid,
    this.unitNumber,
    this.lessonNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wid': wid,
      'title': title,
      'content_path': contentPath,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'is_original': isOriginal ? 1 : 0,
      'ai_review': aiReview,
      'brief': brief,
      'kid': kid,
      'unit_number': unitNumber,
      'lesson_number': lessonNumber,
    };
  }

  static PortfolioItem fromMap(Map<String, dynamic> map) {
    return PortfolioItem(
      id: map['id'] as int?,
      wid: map['wid'] as String?,
      title: map['title'] as String,
      contentPath: map['content_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      isOriginal: (map['is_original'] as int?) == 1,
      aiReview: map['ai_review'] as String?,
      brief: map['brief'] as String?,
      kid: map['kid'] as String?,
      unitNumber: map['unit_number'] as String?,
      lessonNumber: map['lesson_number'] as String?,
    );
  }

  PortfolioItem copyWith({
    int? id,
    String? wid,
    String? title,
    String? contentPath,
    String? thumbnailPath,
    DateTime? createdAt,
    String? lang,
    bool? isOriginal,
    String? aiReview,
    String? brief,
    String? kid,
    String? unitNumber,
    String? lessonNumber,
  }) {
    return PortfolioItem(
      id: id ?? this.id,
      wid: wid ?? this.wid,
      title: title ?? this.title,
      contentPath: contentPath ?? this.contentPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      isOriginal: isOriginal ?? this.isOriginal,
      aiReview: aiReview ?? this.aiReview,
      brief: brief ?? this.brief,
      kid: kid ?? this.kid,
      unitNumber: unitNumber ?? this.unitNumber,
      lessonNumber: lessonNumber ?? this.lessonNumber,
    );
  }
}

class PortfolioDao {
  final Database db;

  PortfolioDao(this.db);

  Future<int> insert(PortfolioItem item) async {
    final id = await db.insert('portfolio_items', item.toMap());
    if (id > 0 && item.wid == null) {
      final wid = 'W$id';
      await db.update(
        'portfolio_items',
        {'wid': wid},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return id;
  }

  Future<List<PortfolioItem>> getAll({
    String? lang,
    bool? isOriginal,
    String? kid,
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
    if (isOriginal != null) {
      conditions.add('is_original = ?');
      args.add(isOriginal ? 1 : 0);
    }
    if (kid != null) {
      conditions.add('kid = ?');
      args.add(kid);
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
      conditions.add('(title LIKE ? OR wid LIKE ? OR brief LIKE ?)');
      args.add('%$keyword%');
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

  Future<PortfolioItem?> getByWid(String wid) async {
    final maps = await db.query(
      'portfolio_items',
      where: 'wid = ?',
      whereArgs: [wid],
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

  Future<int> deleteAll() async {
    final count = await this.count();
    if (count > 0) {
      await db.delete('portfolio_items');
      return count;
    }
    return 0;
  }

  Future<int> count({String? lang, bool? isOriginal}) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (lang != null) {
      conditions.add('lang = ?');
      args.add(lang);
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

  Future<List<String>> getAllKids() async {
    final result = await db.rawQuery('SELECT DISTINCT kid FROM portfolio_items WHERE kid IS NOT NULL');
    return result.map((map) => map['kid'] as String).toList();
  }

  Future<List<String>> getAllUnitNumbers() async {
    final result = await db.rawQuery('SELECT DISTINCT unit_number FROM portfolio_items WHERE unit_number IS NOT NULL');
    return result.map((map) => map['unit_number'] as String).toList();
  }
}