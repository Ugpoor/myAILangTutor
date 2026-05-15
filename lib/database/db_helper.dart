import 'package:sqflite/sqflite.dart';
import 'models/inbox_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      'myAILangTutor.db',
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        folder_name TEXT NOT NULL UNIQUE,
        url TEXT,
        source TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        category TEXT,
        status TEXT DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE todo_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        due_date TIMESTAMP,
        completed INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE error_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        correct_answer TEXT,
        subject TEXT,
        lesson TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reviewed INTEGER DEFAULT 0,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        mastered INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        options TEXT,
        correct_answer TEXT,
        explanation TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        completed INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE portfolio_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT,
        content_path TEXT,
        thumbnail_path TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE skills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level INTEGER DEFAULT 1,
        progress REAL DEFAULT 0,
        last_practiced TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        reasoning TEXT,
        is_user INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

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

    await db.execute('''
      CREATE TABLE efficiency_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id TEXT,
        title TEXT NOT NULL,
        unit_count INTEGER DEFAULT 0,
        unit_efficiency REAL DEFAULT 0,
        record_time TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE schedule_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        repeat_type TEXT DEFAULT 'none',
        repeat_days TEXT,
        date TEXT NOT NULL DEFAULT CURRENT_DATE,
        completed INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE chat_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          reasoning TEXT,
          is_user INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          lang TEXT DEFAULT 'cn'
        )
      ''');
    }
    if (oldVersion < 3) {
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
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE efficiency_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          record_id TEXT,
          title TEXT NOT NULL,
          unit_count INTEGER DEFAULT 0,
          unit_efficiency REAL DEFAULT 0,
          record_time TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          lang TEXT DEFAULT 'cn'
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS schedule_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          schedule_id TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          repeat_type TEXT DEFAULT 'none',
          repeat_days TEXT,
          date TEXT NOT NULL DEFAULT CURRENT_DATE,
          completed INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          lang TEXT DEFAULT 'cn'
        )
      ''');
    }
    if (oldVersion < 8) {
      // 确保efficiency_records表有正确的字段
      try {
        await db.execute('ALTER TABLE efficiency_records ADD COLUMN IF NOT EXISTS unit_count INTEGER DEFAULT 0');
      } catch (e) {
        // 如果列已存在，忽略错误
      }
    }
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(String table, Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $table${where != null ? " WHERE $where" : ""}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Inbox items methods
  Future<int> insertInboxItem(InboxItem item) async {
    final db = await database;
    return await db.insert('inbox_items', item.toMap());
  }

  Future<List<InboxItem>> getAllInboxItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbox_items',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => InboxItem.fromMap(maps[i]));
  }

  Future<List<InboxItem>> getInboxItemsByStatus(String status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbox_items',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => InboxItem.fromMap(maps[i]));
  }

  Future<int> updateInboxItem(InboxItem item) async {
    final db = await database;
    return await db.update(
      'inbox_items',
      item.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteInboxItem(int id) async {
    final db = await database;
    return await db.delete(
      'inbox_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<InboxItem>> getInboxItemsByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbox_items',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => InboxItem.fromMap(maps[i]));
  }

  Future<int> deleteAllProcessedItems() async {
    final db = await database;
    return await db.delete(
      'inbox_items',
      where: 'status = ?',
      whereArgs: ['已处理'],
    );
  }

  // Efficiency records methods
  Future<List<Map<String, dynamic>>> getRecentEfficiencyRecords(int limit) async {
    final db = await database;
    return await db.query(
      'efficiency_records',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  // Schedule items methods
  Future<List<Map<String, dynamic>>> getAllScheduleItems() async {
    final db = await database;
    return await db.query(
      'schedule_items',
      orderBy: 'date ASC, start_time ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayScheduleItems(int limit) async {
    final db = await database;
    final today = DateTime.now().toLocal().toIso8601String().split('T')[0];
    return await db.query(
      'schedule_items',
      where: '(date = ? OR date IS NULL)',
      whereArgs: [today],
      orderBy: 'start_time ASC',
      limit: limit,
    );
  }
}
