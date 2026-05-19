import 'package:sqflite/sqflite.dart';

class Skill {
  final int? id;
  final String name;
  final int level;
  final double progress;
  final DateTime? lastPracticed;
  final DateTime? createdAt;
  final String lang;
  final String? skillId;
  final String? category;
  final String? prerequisite;
  final String? promptText;
  final String? internalFunction;
  final String? parameters;
  final String? returnType;
  final String? description;

  Skill({
    this.id,
    required this.name,
    this.level = 1,
    this.progress = 0,
    this.lastPracticed,
    this.createdAt,
    this.lang = 'cn',
    this.skillId,
    this.category,
    this.prerequisite,
    this.promptText,
    this.internalFunction,
    this.parameters,
    this.returnType,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'progress': progress,
      'last_practiced': lastPracticed?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
      'skill_id': skillId,
      'category': category,
      'prerequisite': prerequisite,
      'prompt_text': promptText,
      'internal_function': internalFunction,
      'parameters': parameters,
      'return_type': returnType,
      'description': description,
    };
  }

  static Skill fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map['id'] as int?,
      name: map['name'] as String,
      level: map['level'] as int? ?? 1,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      lastPracticed: map['last_practiced'] != null
          ? DateTime.parse(map['last_practiced'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
      skillId: map['skill_id'] as String?,
      category: map['category'] as String?,
      prerequisite: map['prerequisite'] as String?,
      promptText: map['prompt_text'] as String?,
      internalFunction: map['internal_function'] as String?,
      parameters: map['parameters'] as String?,
      returnType: map['return_type'] as String?,
      description: map['description'] as String?,
    );
  }

  Skill copyWith({
    int? id,
    String? name,
    int? level,
    double? progress,
    DateTime? lastPracticed,
    DateTime? createdAt,
    String? lang,
    String? skillId,
    String? category,
    String? prerequisite,
    String? promptText,
    String? internalFunction,
    String? parameters,
    String? returnType,
    String? description,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      progress: progress ?? this.progress,
      lastPracticed: lastPracticed ?? this.lastPracticed,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
      skillId: skillId ?? this.skillId,
      category: category ?? this.category,
      prerequisite: prerequisite ?? this.prerequisite,
      promptText: promptText ?? this.promptText,
      internalFunction: internalFunction ?? this.internalFunction,
      parameters: parameters ?? this.parameters,
      returnType: returnType ?? this.returnType,
      description: description ?? this.description,
    );
  }
}

class SkillDao {
  final Database db;

  SkillDao(this.db);

  Future<int> insert(Skill skill) async {
    return await db.insert('skills', skill.toMap());
  }

  Future<List<Skill>> getAll({
    String? lang,
    String? category,
    String? prerequisite,
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
    if (prerequisite != null) {
      conditions.add('prerequisite = ?');
      args.add(prerequisite);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('(name LIKE ? OR skill_id LIKE ? OR description LIKE ?)');
      args.add('%$keyword%');
      args.add('%$keyword%');
      args.add('%$keyword%');
    }

    final maps = await db.query(
      'skills',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Skill.fromMap(map)).toList();
  }

  Future<Skill?> getById(int id) async {
    final maps = await db.query(
      'skills',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? Skill.fromMap(maps.first) : null;
  }

  Future<Skill?> getBySkillId(String skillId) async {
    final maps = await db.query(
      'skills',
      where: 'skill_id = ?',
      whereArgs: [skillId],
    );
    return maps.isNotEmpty ? Skill.fromMap(maps.first) : null;
  }

  Future<List<Skill>> getChildrenOf(String skillId) async {
    final maps = await db.query(
      'skills',
      where: 'prerequisite = ?',
      whereArgs: [skillId],
      orderBy: 'level ASC, created_at ASC',
    );
    return maps.map((map) => Skill.fromMap(map)).toList();
  }

  Future<int> update(Skill skill) async {
    return await db.update(
      'skills',
      skill.toMap(),
      where: 'id = ?',
      whereArgs: [skill.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'skills',
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
      'SELECT COUNT(*) FROM skills${conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')}" : ""}',
      args.isNotEmpty ? args : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> nextSkillIdNumber() async {
    final result = await db.rawQuery(
      "SELECT skill_id FROM skills WHERE skill_id LIKE 'S%' ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 1;
    final lastId = result.first['skill_id'] as String?;
    if (lastId == null) return 1;
    final match = RegExp(r'S(\d+)').firstMatch(lastId);
    if (match != null) return int.parse(match.group(1)!) + 1;
    return 1;
  }
}
