import 'package:sqflite/sqflite.dart';

class MoveRecord {
  final int? id;
  final String inboxItemId;
  final String fromCategory;
  final String toCategory;
  final String fromPath;
  final String toPath;
  final DateTime movedAt;

  MoveRecord({
    this.id,
    required this.inboxItemId,
    required this.fromCategory,
    required this.toCategory,
    required this.fromPath,
    required this.toPath,
    required this.movedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inbox_item_id': inboxItemId,
      'from_category': fromCategory,
      'to_category': toCategory,
      'from_path': fromPath,
      'to_path': toPath,
      'moved_at': movedAt.toIso8601String(),
    };
  }

  static MoveRecord fromMap(Map<String, dynamic> map) {
    return MoveRecord(
      id: map['id'] as int?,
      inboxItemId: map['inbox_item_id'] as String,
      fromCategory: map['from_category'] as String,
      toCategory: map['to_category'] as String,
      fromPath: map['from_path'] as String,
      toPath: map['to_path'] as String,
      movedAt: DateTime.parse(map['moved_at'] as String),
    );
  }
}

class MoveRecordDao {
  final Database db;

  MoveRecordDao(this.db);

  Future<int> insert(MoveRecord record) async {
    return await db.insert('move_records', record.toMap());
  }

  Future<List<MoveRecord>> getByInboxItemId(String inboxItemId) async {
    final maps = await db.query(
      'move_records',
      where: 'inbox_item_id = ?',
      whereArgs: [inboxItemId],
      orderBy: 'moved_at DESC',
    );
    return maps.map((map) => MoveRecord.fromMap(map)).toList();
  }

  Future<List<MoveRecord>> getAll({int? limit}) async {
    final maps = await db.query(
      'move_records',
      orderBy: 'moved_at DESC',
      limit: limit,
    );
    return maps.map((map) => MoveRecord.fromMap(map)).toList();
  }

  Future<int> delete(int id) async {
    return await db.delete('move_records', where: 'id = ?', whereArgs: [id]);
  }
}
