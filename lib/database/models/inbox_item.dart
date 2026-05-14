import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class InboxItem {
  final int? id;
  final String title;
  final String source;
  final String url;
  final String filePath;
  final String content;
  final String category;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  InboxItem({
    this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.filePath,
    this.content = '',
    this.category = '未知归类',
    this.status = '未处理',
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'url': url,
      'filePath': filePath,
      'content': content,
      'category': category,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory InboxItem.fromMap(Map<String, dynamic> map) {
    return InboxItem(
      id: map['id'],
      title: map['title'],
      source: map['source'],
      url: map['url'],
      filePath: map['filePath'],
      content: map['content'],
      category: map['category'],
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  InboxItem copyWith({
    int? id,
    String? title,
    String? source,
    String? url,
    String? filePath,
    String? content,
    String? category,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InboxItem(
      id: id ?? this.id,
      title: title ?? this.title,
      source: source ?? this.source,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'myAILangTutor.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inbox_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            source TEXT NOT NULL,
            url TEXT NOT NULL,
            filePath TEXT NOT NULL,
            content TEXT,
            category TEXT DEFAULT '未知归类',
            status TEXT DEFAULT '未处理',
            createdAt TEXT NOT NULL,
            updatedAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE inbox_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              source TEXT NOT NULL,
              url TEXT NOT NULL,
              filePath TEXT NOT NULL,
              content TEXT,
              category TEXT DEFAULT '未知归类',
              status TEXT DEFAULT '未处理',
              createdAt TEXT NOT NULL,
              updatedAt TEXT
            )
          ''');
        }
      },
    );
  }

  Future<int> insertInboxItem(InboxItem item) async {
    final database = await db;
    return await database.insert('inbox_items', item.toMap());
  }

  Future<List<InboxItem>> getAllInboxItems() async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      'inbox_items',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => InboxItem.fromMap(maps[i]));
  }

  Future<List<InboxItem>> getInboxItemsByStatus(String status) async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      'inbox_items',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => InboxItem.fromMap(maps[i]));
  }

  Future<List<InboxItem>> getInboxItemsByCategory(String category) async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      'inbox_items',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => InboxItem.fromMap(maps[i]));
  }

  Future<int> updateInboxItem(InboxItem item) async {
    final database = await db;
    return await database.update(
      'inbox_items',
      item.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteInboxItem(int id) async {
    final database = await db;
    return await database.delete(
      'inbox_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllProcessedItems() async {
    final database = await db;
    return await database.delete(
      'inbox_items',
      where: 'status = ?',
      whereArgs: ['已处理'],
    );
  }
}
