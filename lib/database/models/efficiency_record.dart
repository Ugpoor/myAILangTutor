import 'package:sqflite/sqflite.dart';

class EfficiencyRecord {
  final int? id;
  final String recordId;  // e.g., "R1"
  final String title;
  final int unitCount;
  final double unitEfficiency;
  final DateTime recordTime;
  final DateTime? createdAt;
  final String lang;

  EfficiencyRecord({
    this.id,
    required this.recordId,
    required this.title,
    this.unitCount = 0,
    this.unitEfficiency = 0.0,
    required this.recordTime,
    this.createdAt,
    this.lang = 'cn',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'record_id': recordId,
      'title': title,
      'unit_count': unitCount,
      'unit_efficiency': unitEfficiency,
      'record_time': recordTime.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'lang': lang,
    };
  }

  static EfficiencyRecord fromMap(Map<String, dynamic> map) {
    return EfficiencyRecord(
      id: map['id'] as int?,
      recordId: map['record_id'] as String,
      title: map['title'] as String,
      unitCount: (map['unit_count'] as int?) ?? 0,
      unitEfficiency: (map['unit_efficiency'] as num?)?.toDouble() ?? 0.0,
      recordTime: DateTime.parse(map['record_time'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lang: map['lang'] as String? ?? 'cn',
    );
  }

  EfficiencyRecord copyWith({
    int? id,
    String? recordId,
    String? title,
    int? unitCount,
    double? unitEfficiency,
    DateTime? recordTime,
    DateTime? createdAt,
    String? lang,
  }) {
    return EfficiencyRecord(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      title: title ?? this.title,
      unitCount: unitCount ?? this.unitCount,
      unitEfficiency: unitEfficiency ?? this.unitEfficiency,
      recordTime: recordTime ?? this.recordTime,
      createdAt: createdAt ?? this.createdAt,
      lang: lang ?? this.lang,
    );
  }
}

class EfficiencyRecordDao {
  final Database db;

  EfficiencyRecordDao(this.db);

  Future<int> insert(EfficiencyRecord item) async {
    return await db.insert('efficiency_records', item.toMap());
  }

  Future<List<EfficiencyRecord>> getAll({String? lang}) async {
    final maps = await db.query(
      'efficiency_records',
      where: lang != null ? 'lang = ?' : null,
      whereArgs: lang != null ? [lang] : null,
      orderBy: 'record_time DESC',
    );
    return maps.map((map) => EfficiencyRecord.fromMap(map)).toList();
  }

  Future<EfficiencyRecord?> getById(int id) async {
    final maps = await db.query(
      'efficiency_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? EfficiencyRecord.fromMap(maps.first) : null;
  }

  Future<EfficiencyRecord?> getByRecordId(String recordId) async {
    final maps = await db.query(
      'efficiency_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    return maps.isNotEmpty ? EfficiencyRecord.fromMap(maps.first) : null;
  }

  Future<int> update(EfficiencyRecord item) async {
    return await db.update(
      'efficiency_records',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      'efficiency_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> generateNextRecordId() async {
    final result = await db.rawQuery(
      'SELECT record_id FROM efficiency_records ORDER BY id DESC LIMIT 1',
    );
    if (result.isEmpty) {
      return 'R1';
    }
    final lastId = result.first['record_id'] as String;
    final numStr = lastId.substring(1);
    final num = int.parse(numStr);
    return 'R${num + 1}';
  }
}
