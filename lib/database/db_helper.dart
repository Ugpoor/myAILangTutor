import 'package:sqflite/sqflite.dart';
import 'models/inbox_item.dart';
import 'models/schema.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _version = 33;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      'myAILangTutor.db',
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createErrorTypeOutlinesTable(db);
    await _createKnowledgeOutlinesTable(db);
    await _createKnowledgePointsTable(db);
    await _createErrorRecordsTable(db);
    await _createTestPapersTable(db);
    await _createExercisesTable(db);
    await _createQuestionsTable(db);
    await _createTestsTable(db);
    await _createPortfolioItemsTable(db);
    await _createSkillsTable(db);
    await _createInboxItemsTable(db);
    await _createOtherTables(db);
  }

  Future<void> _createErrorTypeOutlinesTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${ErrorTypeOutlineSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eid TEXT NOT NULL,
        content TEXT NOT NULL,
        lang TEXT DEFAULT 'cn',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createKnowledgeOutlinesTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${KnowledgeOutlineSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cid TEXT NOT NULL,
        content TEXT NOT NULL,
        lang TEXT DEFAULT 'cn',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createKnowledgePointsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${KnowledgePointSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kid TEXT UNIQUE,
        title TEXT NOT NULL,
        unit_number TEXT,
        lesson_number TEXT,
        cid TEXT NOT NULL,
        content_path TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_practice_time TEXT,
        lang TEXT DEFAULT 'cn',
        knowledge_tag TEXT,
        test_times INTEGER DEFAULT 0,
        error_times INTEGER DEFAULT 0,
        test_recs TEXT,
        error_recs TEXT,
        brief TEXT
      )
    ''');
  }

  Future<void> _createErrorRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${ErrorRecordSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        correct_answer TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        error_id TEXT,
        error_type TEXT,
        progress TEXT DEFAULT '待订正',
        question TEXT,
        wrong_answer TEXT,
        wrong_where TEXT,
        why_wrong TEXT,
        how_prevent TEXT,
        notes TEXT,
        images TEXT,
        tid TEXT,
        qid TEXT,
        grade_memo TEXT,
        correction TEXT,
        kid TEXT,
        unit_number TEXT,
        lesson_number TEXT,
        cid TEXT
      )
    ''');
  }

  Future<void> _createTestPapersTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${TestPaperSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tid TEXT UNIQUE,
        test_title TEXT NOT NULL,
        images TEXT,
        question_list TEXT,
        content_path TEXT NOT NULL,
        unit_number TEXT,
        lesson_number TEXT,
        source TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');
  }

  Future<void> _createExercisesTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${ExerciseSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        options TEXT,
        correct_answer TEXT,
        explanation TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        completed INTEGER DEFAULT 0,
        content_path TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        progress TEXT DEFAULT '未答题',
        exam_paper TEXT,
        answer_sheet TEXT,
        answer_key TEXT,
        grading TEXT,
        source TEXT,
        exercise_id TEXT,
        paper_id TEXT,
        lesson_unit TEXT,
        knowledge_tag TEXT
      )
    ''');
  }

  Future<void> _createQuestionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        correct_answer TEXT,
        explanation TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        completed INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        content_path TEXT,
        exercise_id TEXT,
        tid TEXT,
        lesson_number INTEGER,
        unit_number INTEGER,
        kid TEXT,
        progress TEXT DEFAULT '未答题',
        exam_paper TEXT,
        answer_sheet TEXT,
        answer_key TEXT,
        grading_sheet TEXT,
        grading TEXT,
        grading_result TEXT,
        answer TEXT,
        source TEXT
      )
    ''');
  }

  Future<void> _createTestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE tests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tid TEXT UNIQUE,
        title TEXT NOT NULL,
        lesson_unit_list TEXT,
        kids TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        exam_date TIMESTAMP,
        grade_date TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        total_score INTEGER,
        duration INTEGER,
        status TEXT DEFAULT '未开始',
        images TEXT
      )
    ''');
  }

  Future<void> _createPortfolioItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${PortfolioItemSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wid TEXT UNIQUE,
        title TEXT NOT NULL,
        content_path TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        is_original INTEGER DEFAULT 0,
        ai_review TEXT,
        brief TEXT,
        kid TEXT,
        unit_number TEXT,
        lesson_number TEXT,
        test_recs TEXT
      )
    ''');
  }

  Future<void> _createSkillsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${SkillSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        skill_id TEXT,
        category TEXT,
        prerequisite TEXT,
        prompt_text TEXT,
        internal_function TEXT,
        parameters TEXT,
        return_type TEXT,
        description TEXT
      )
    ''');
  }

  Future<void> _createInboxItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${InboxItemSchema.tableName} (
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

  Future<void> _createOtherTables(Database db) async {
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
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE ${ChatMessageSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        reasoning TEXT,
        is_user INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn'
      )
    ''');

    await db.execute('''
      CREATE TABLE ${EfficiencyRecordSchema.tableName} (
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
      CREATE TABLE ${ScheduleItemSchema.tableName} (
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
    if (oldVersion < 16) {
      await _upgradeToV16(db);
    }
    if (oldVersion < 17) {
      await _upgradeToV17(db);
    }
    if (oldVersion < 18) {
      await _upgradeToV18(db);
    }
    if (oldVersion < 19) {
      await _upgradeToV19(db);
    }
    if (oldVersion < 20) {
      await _upgradeToV20(db);
    }
    if (oldVersion < 21) {
      await _upgradeToV21(db);
    }
    if (oldVersion < 22) {
      await _upgradeToV22(db);
    }
    if (oldVersion < 23) {
      await _upgradeToV23(db);
    }
    if (oldVersion < 24) {
      await _upgradeToV24(db);
    }
    if (oldVersion < 25) {
      await _upgradeToV25(db);
    }
    if (oldVersion < 26) {
      await _upgradeToV26(db);
    }
    if (oldVersion < 27) {
      await _upgradeToV27(db);
    }
    if (oldVersion < 28) {
      await _upgradeToV28(db);
    }
    if (oldVersion < 29) {
      await _upgradeToV29(db);
    }
    if (oldVersion < 30) {
      await _upgradeToV30(db);
    }
    if (oldVersion < 31) {
      await _upgradeToV31(db);
    }
    if (oldVersion < 32) {
      await _upgradeToV32(db);
    }
    if (oldVersion < 33) {
      await _upgradeToV33(db);
    }
  }

  Future<void> _upgradeToV24(Database db) async {
    try {
      await db.execute('ALTER TABLE exercises ADD COLUMN exercise_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE exercises ADD COLUMN paper_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE exercises ADD COLUMN lesson_unit TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE exercises ADD COLUMN knowledge_tag TEXT');
    } catch (_) {}
  }

  Future<void> _upgradeToV25(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS efficiency_records (
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

  Future<void> _upgradeToV26(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        correct_answer TEXT,
        explanation TEXT,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        completed INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        content_path TEXT,
        exercise_id TEXT,
        tid TEXT,
        lesson_number INTEGER,
        unit_number INTEGER,
        kid TEXT,
        progress TEXT DEFAULT '未答题',
        exam_paper TEXT,
        answer_sheet TEXT,
        answer_key TEXT,
        grading_sheet TEXT,
        grading TEXT,
        grading_result TEXT,
        answer TEXT,
        source TEXT
      )
    ''');
  }

  Future<void> _upgradeToV27(Database db) async {
    try {
      await db.execute('ALTER TABLE knowledge_points ADD COLUMN last_practice_time TEXT');
    } catch (_) {}
  }

  Future<void> _upgradeToV28(Database db) async {
    await _createTestsTable(db);
  }

  Future<void> _upgradeToV29(Database db) async {
    try {
      await db.execute('ALTER TABLE questions ADD COLUMN grading_sheet TEXT');
    } catch (_) {}
  }

  Future<void> _upgradeToV30(Database db) async {
    try {
      await db.execute('ALTER TABLE questions ADD COLUMN grading_result TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE questions ADD COLUMN answer TEXT');
    } catch (_) {}
  }

  Future<void> _upgradeToV31(Database db) async {
    try {
      await db.execute('ALTER TABLE portfolio_items ADD COLUMN test_recs TEXT');
    } catch (_) {}
  }

  Future<void> _upgradeToV32(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MoveRecordSchema.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inbox_item_id TEXT NOT NULL,
        from_category TEXT NOT NULL,
        to_category TEXT NOT NULL,
        from_path TEXT NOT NULL,
        to_path TEXT NOT NULL,
        moved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _upgradeToV33(Database db) async {
    try {
      await db.execute('ALTER TABLE tests ADD COLUMN content TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE portfolio_items ADD COLUMN content TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE knowledge_points ADD COLUMN content TEXT');
    } catch (_) {}
  }

  Future<void> _upgradeToV23(Database db) async {
    // SQLite不支持DROP NOT NULL，需要创建新表并迁移数据
    await db.execute('''
      CREATE TABLE error_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        correct_answer TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lang TEXT DEFAULT 'cn',
        content_path TEXT,
        error_id TEXT,
        error_type TEXT,
        progress TEXT DEFAULT '待订正',
        question TEXT,
        wrong_answer TEXT,
        wrong_where TEXT,
        why_wrong TEXT,
        how_prevent TEXT,
        notes TEXT,
        images TEXT,
        tid TEXT,
        qid TEXT,
        grade_memo TEXT,
        correction TEXT,
        kid TEXT,
        unit_number TEXT,
        lesson_number TEXT,
        cid TEXT
      )
    ''');
    await db.execute('INSERT INTO error_records_new SELECT * FROM error_records');
    await db.execute('DROP TABLE error_records');
    await db.execute('ALTER TABLE error_records_new RENAME TO error_records');
  }

  Future<void> _upgradeToV16(Database db) async {
    await _createTestPapersTable(db);
  }

  Future<void> _upgradeToV17(Database db) async {
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN kid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN cid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN brief TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN test_times INTEGER DEFAULT 0");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN error_times INTEGER DEFAULT 0");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN test_recs TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE knowledge_points ADD COLUMN error_recs TEXT");
    } catch (e) {}
  }

  Future<void> _upgradeToV18(Database db) async {
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN tid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN qid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN grade_memo TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN correction TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN kid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN unit_number TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE error_records ADD COLUMN lesson_number TEXT");
    } catch (e) {}
  }

  Future<void> _upgradeToV19(Database db) async {
    try {
      await db.execute("ALTER TABLE portfolio_items ADD COLUMN wid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE portfolio_items ADD COLUMN brief TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE portfolio_items ADD COLUMN kid TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE portfolio_items ADD COLUMN unit_number TEXT");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE portfolio_items ADD COLUMN lesson_number TEXT");
    } catch (e) {}
  }

  Future<void> _upgradeToV20(Database db) async {
    try {
      await db.execute("ALTER TABLE skills DROP COLUMN level");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE skills DROP COLUMN progress");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE skills DROP COLUMN last_practiced");
    } catch (e) {}
    try {
      await db.execute("ALTER TABLE skills DROP COLUMN content_path");
    } catch (e) {}
  }

  Future<void> _upgradeToV21(Database db) async {
    await _createKnowledgeOutlinesTable(db);
  }

  Future<void> _upgradeToV22(Database db) async {
    await _createErrorTypeOutlinesTable(db);
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

  Future<InboxItem?> getInboxItemById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbox_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return InboxItem.fromMap(maps.first);
    }
    return null;
  }

  Future<InboxItem?> getInboxItemByFilePath(String filePath) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inbox_items',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    if (maps.isNotEmpty) {
      return InboxItem.fromMap(maps.first);
    }
    return null;
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

  Future<List<Map<String, dynamic>>> getRecentEfficiencyRecords(int limit) async {
    final db = await database;
    return await db.query(
      'efficiency_records',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

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

  Future<List<Map<String, dynamic>>> getClassificationMessages() async {
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'is_user = 0',
      orderBy: 'created_at DESC',
    );
  }
}