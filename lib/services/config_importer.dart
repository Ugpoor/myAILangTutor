import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../database/models/error_record.dart';
import '../database/models/question.dart';
import '../database/models/test_paper.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/error_type_outline.dart';
import '../database/models/knowledge_outline.dart';
import '../database/models/skill.dart';

class ConfigImporter {
  static final ConfigImporter _instance = ConfigImporter._internal();
  factory ConfigImporter() => _instance;
  ConfigImporter._internal();

  Future<String> get _appDocumentsPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<bool> syncKnowledgeOutlinesFromConfig() async {
    try {
      // 先尝试从应用目录读取，再从资源文件读取
      final appConfigPath = await _getConfigFilePath('knowledge_outlines.json');
      String? jsonString;

      if (await File(appConfigPath).exists()) {
        print('[ConfigImporter] 从应用目录读取配置: $appConfigPath');
        jsonString = await File(appConfigPath).readAsString();
      } else {
        // 从资源文件读取
        try {
          print('[ConfigImporter] 从资源文件读取配置');
          jsonString = await rootBundle.loadString(
            'lib/pages/knowledge_outlines.json',
          );
        } catch (e) {
          print('[ConfigImporter] 资源文件读取失败: $e');
        }
      }

      if (jsonString == null) {
        print('[ConfigImporter] 知识大纲配置文件不存在');
        return false;
      }

      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);

      // 获取配置文件修改时间（仅从应用目录文件获取，资源文件无法获取修改时间）
      DateTime? configLastModified;
      final appConfigFile = File(appConfigPath);
      if (await appConfigFile.exists()) {
        configLastModified = (await appConfigFile.stat()).modified;
      }

      // 获取数据库中最新记录的更新时间
      final dbOutlines = await dao.getAll();
      DateTime? dbLastModified;
      if (dbOutlines.isNotEmpty) {
        dbLastModified = dbOutlines
            .map((o) => o.updatedAt ?? o.createdAt ?? DateTime(2000))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      // 如果数据库为空，或者配置文件（从应用目录）更新时间 > 数据库最新更新时间，执行同步
      bool shouldSync = dbLastModified == null;
      if (!shouldSync && configLastModified != null) {
        shouldSync = configLastModified.isAfter(dbLastModified!);
      }

      // 如果从资源文件读取且数据库有数据，不进行同步（避免覆盖用户修改）
      if (!shouldSync && !await appConfigFile.exists()) {
        print('[ConfigImporter] 从资源文件读取，数据库已有数据，不进行同步');
        return false;
      }

      if (shouldSync) {
        print('[ConfigImporter] 配置文件比数据库新，开始同步...');

        final data = json.decode(jsonString!);
        final outlines = data['knowledge_outlines'] as List;

        // 清空现有数据
        await db.delete('knowledge_outlines');

        // 插入新数据
        for (final item in outlines) {
          await dao.insert(
            KnowledgeOutline(
              cid: item['cid'],
              content: item['content'],
              lang: item['lang'] ?? 'cn',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        print('[ConfigImporter] 同步知识大纲完成: ${outlines.length} 条');
        return true;
      } else {
        print('[ConfigImporter] 数据库比配置文件新，无需同步');
        return false;
      }
    } catch (e) {
      print('[ConfigImporter] 同步知识大纲失败: $e');
      return false;
    }
  }

  Future<bool> syncErrorTypeOutlinesFromConfig() async {
    try {
      // 先尝试从应用目录读取，再从资源文件读取
      final appConfigPath = await _getConfigFilePath(
        'error_type_outlines.json',
      );
      String? jsonString;

      if (await File(appConfigPath).exists()) {
        print('[ConfigImporter] 从应用目录读取配置: $appConfigPath');
        jsonString = await File(appConfigPath).readAsString();
      } else {
        // 从资源文件读取
        try {
          print('[ConfigImporter] 从资源文件读取配置');
          jsonString = await rootBundle.loadString(
            'lib/pages/error_type_outlines.json',
          );
        } catch (e) {
          print('[ConfigImporter] 资源文件读取失败: $e');
        }
      }

      if (jsonString == null) {
        print('[ConfigImporter] 错类大纲配置文件不存在');
        return false;
      }

      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);

      // 获取配置文件修改时间（仅从应用目录文件获取，资源文件无法获取修改时间）
      DateTime? configLastModified;
      final appConfigFile = File(appConfigPath);
      if (await appConfigFile.exists()) {
        configLastModified = (await appConfigFile.stat()).modified;
      }

      // 获取数据库中最新记录的更新时间
      final dbOutlines = await dao.getAll();
      DateTime? dbLastModified;
      if (dbOutlines.isNotEmpty) {
        dbLastModified = dbOutlines
            .map((o) => o.updatedAt ?? o.createdAt ?? DateTime(2000))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      // 如果数据库为空，或者配置文件（从应用目录）更新时间 > 数据库最新更新时间，执行同步
      bool shouldSync = dbLastModified == null;
      if (!shouldSync && configLastModified != null) {
        shouldSync = configLastModified.isAfter(dbLastModified!);
      }

      // 如果从资源文件读取且数据库有数据，不进行同步（避免覆盖用户修改）
      if (!shouldSync && !await appConfigFile.exists()) {
        print('[ConfigImporter] 从资源文件读取，数据库已有数据，不进行同步');
        return false;
      }

      if (shouldSync) {
        print('[ConfigImporter] 配置文件比数据库新，开始同步...');

        final data = json.decode(jsonString);
        final outlines = data['error_type_outlines'] as List;

        // 清空现有数据
        await db.delete('error_type_outlines');

        // 插入新数据
        for (final item in outlines) {
          await dao.insert(
            ErrorTypeOutline(
              eid: item['eid'],
              content: item['content'],
              lang: item['lang'] ?? 'cn',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        print('[ConfigImporter] 同步错类大纲完成: ${outlines.length} 条');
        return true;
      } else {
        print('[ConfigImporter] 数据库比配置文件新，无需同步');
        return false;
      }
    } catch (e) {
      print('[ConfigImporter] 同步错类大纲失败: $e');
      return false;
    }
  }

  Future<bool> importAllConfig({bool clearExisting = true}) async {
    try {
      final db = await DatabaseHelper().database;

      if (clearExisting) {
        await _clearAllTables(db);
      }

      // 导入大纲数据（不覆盖已有的大纲数据）
      await _importErrorTypeOutlines(db, skipIfExists: !clearExisting);
      await _importKnowledgeOutlines(db, skipIfExists: !clearExisting);

      // 导入其他测试数据
      await _importErrorRecords(db);
      await _importExercises(db);
      await _importPortfolioItems(db);
      await _importKnowledgePoints(db);
      await _importSkills(db);

      return true;
    } catch (e) {
      print('[ConfigImporter] 导入配置数据失败: $e');
      return false;
    }
  }

  Future<void> _clearAllTables(Database db) async {
    await db.delete('error_type_outlines');
    await db.delete('knowledge_outlines');
    await db.delete('error_records');
    await db.delete('exercises');
    await db.delete('portfolio_items');
    await db.delete('knowledge_points');
  }

  Future<void> _importErrorTypeOutlines(
    Database db, {
    bool skipIfExists = false,
  }) async {
    if (skipIfExists) {
      final existingCount = await db.rawQuery(
        'SELECT COUNT(*) FROM error_type_outlines',
      );
      if (existingCount.isNotEmpty && existingCount[0].values.first != 0) {
        print('[ConfigImporter] 错类大纲已存在，跳过导入');
        return;
      }
    }

    final jsonString = await _getConfigFileContent('error_type_outlines.json');
    final data = json.decode(jsonString);
    final outlines = data['error_type_outlines'] as List;

    final dao = ErrorTypeOutlineDao(db);
    for (final item in outlines) {
      await dao.insert(
        ErrorTypeOutline(
          eid: item['eid'],
          content: item['content'],
          lang: item['lang'] ?? 'cn',
          createdAt: DateTime.now(),
        ),
      );
    }
    print('[ConfigImporter] 导入错类大纲: ${outlines.length} 条');
  }

  Future<void> _importKnowledgeOutlines(
    Database db, {
    bool skipIfExists = false,
  }) async {
    if (skipIfExists) {
      final existingCount = await db.rawQuery(
        'SELECT COUNT(*) FROM knowledge_outlines',
      );
      if (existingCount.isNotEmpty && existingCount[0].values.first != 0) {
        print('[ConfigImporter] 知识点大纲已存在，跳过导入');
        return;
      }
    }

    final jsonString = await _getConfigFileContent('knowledge_outlines.json');
    final data = json.decode(jsonString);
    final outlines = data['knowledge_outlines'] as List;

    final dao = KnowledgeOutlineDao(db);
    for (final item in outlines) {
      await dao.insert(
        KnowledgeOutline(
          cid: item['cid'],
          content: item['content'],
          lang: item['lang'] ?? 'cn',
          createdAt: DateTime.now(),
        ),
      );
    }
    print('[ConfigImporter] 导入知识点大纲: ${outlines.length} 条');
  }

  Future<void> _importErrorRecords(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/error_records.json',
    );
    final data = json.decode(jsonString);
    final records = data['error_records'] as List;

    final dao = ErrorRecordDao(db);
    for (final item in records) {
      await dao.insert(
        ErrorRecord(
          errorId: item['errorId'],
          eids: List<String>.from(item['eids']),
          progress: item['progress'],
          question: item['question'],
          wrongAnswer: item['wrongAnswer'],
          correctAnswer: item['correctAnswer'],
          wrongWhere: item['wrongWhere'],
          whyWrong: item['whyWrong'],
          howPrevent: item['howPrevent'],
          notes: item['notes'],
          tid: item['tid'],
          qid: item['qid'],
          kid: item['kid'],
          unitNumber: item['unitNumber'],
          lessonNumber: item['lessonNumber'],
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入错误记录: ${records.length} 条');
  }

  Future<void> _importExercises(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/exercises.json',
    );
    final data = json.decode(jsonString);
    final exercises = data['exercises'] as List;

    final questionDao = QuestionDao(db);
    final testPaperDao = TestPaperDao(db);

    for (final item in exercises) {
      String? unitNumber;
      String? lessonNumber;
      if (item['lessonUnit'] != null) {
        final unitMatch = RegExp(r'(\d+)年级').firstMatch(item['lessonUnit']);
        if (unitMatch != null) {
          unitNumber = unitMatch.group(1);
        }
        final lessonMatch = RegExp(r'第(\d+)单元').firstMatch(item['lessonUnit']);
        if (lessonMatch != null) {
          lessonNumber = lessonMatch.group(1);
        }
      }

      final tid = item['exerciseId'];

      await testPaperDao.insert(
        TestPaper(
          tid: tid,
          testTitle: item['question'],
          images: [],
          questionList: [],
          contentPath: 'test_data/exercises',
          unitNumber: unitNumber,
          lessonNumber: lessonNumber,
          source: '测试数据',
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );

      await questionDao.insert(
        Question(
          question: item['examPaper'] ?? item['question'],
          exerciseId: tid,
          tid: tid,
          lessonNumber: lessonNumber != null
              ? int.tryParse(lessonNumber)
              : null,
          unitNumber: unitNumber != null ? int.tryParse(unitNumber) : null,
          kid: item['knowledgeTag'],
          progress: item['progress'],
          category: item['category'],
          grading: item['grading'],
          correctAnswer: item['answerKey'],
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入习题: ${exercises.length} 条');
  }

  Future<void> _importPortfolioItems(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/portfolio_items.json',
    );
    final data = json.decode(jsonString);
    final items = data['portfolio_items'] as List;

    final dao = PortfolioDao(db);
    for (final item in items) {
      await dao.insert(
        PortfolioItem(
          title: item['title'],
          isOriginal: item['isOriginal'],
          contentPath: item['contentPath'],
          brief: item['brief'],
          kid: item['kid'],
          unitNumber: item['unitNumber'],
          lessonNumber: item['lessonNumber'],
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入作品集: ${items.length} 条');
  }

  Future<void> _importKnowledgePoints(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/knowledge_points.json',
    );
    final data = json.decode(jsonString);
    final points = data['knowledge_points'] as List;

    final dao = KnowledgePointDao(db);
    for (final item in points) {
      await dao.insert(
        KnowledgePoint(
          title: item['title'],
          cid: item['cid'],
          kid: item['kid'],
          contentPath: item['contentPath'],
          brief: item['brief'],
          unitNumber: item['unitNumber'],
          lessonNumber: item['lessonNumber'],
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入知识点: ${points.length} 条');
  }

  Future<void> _importSkills(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/skills.json',
    );
    final data = json.decode(jsonString);
    final skills = data['skills'] as List;

    final dao = SkillDao(db);
    for (final item in skills) {
      await dao.insert(
        Skill(
          name: item['name'],
          skillId: item['skillId'],
          category: item['category'],
          prerequisite: item['prerequisite'],
          promptText: item['promptText'],
          internalFunction: item['internalFunction'],
          parameters: item['parameters'],
          returnType: item['returnType'],
          description: item['description'],
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入技能: ${skills.length} 条');
  }

  Future<bool> exportErrorTypeOutlinesToConfig() async {
    try {
      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);
      final outlines = await dao.getAll();

      final data = {
        'error_type_outlines': outlines
            .map((o) => {'eid': o.eid, 'content': o.content, 'lang': o.lang})
            .toList(),
      };

      final configPath = await _getConfigFilePath('error_type_outlines.json');
      await File(
        configPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      print('[TestDataImporter] 导出错类大纲到配置文件: $configPath');
      return true;
    } catch (e) {
      print('[TestDataImporter] 导出错类大纲失败: $e');
      return false;
    }
  }

  Future<bool> exportKnowledgeOutlinesToConfig() async {
    try {
      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);
      final outlines = await dao.getAll();

      final data = {
        'knowledge_outlines': outlines
            .map((o) => {'cid': o.cid, 'content': o.content, 'lang': o.lang})
            .toList(),
      };

      final configPath = await _getConfigFilePath('knowledge_outlines.json');
      await File(
        configPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      print('[TestDataImporter] 导出知识点大纲到配置文件: $configPath');
      return true;
    } catch (e) {
      print('[TestDataImporter] 导出知识点大纲失败: $e');
      return false;
    }
  }

  Future<bool> syncErrorTypeOutline(ErrorTypeOutline outline) async {
    try {
      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);

      final existing = await dao.getById(outline.id!);
      if (existing != null) {
        await dao.update(outline);
      } else {
        await dao.insert(outline);
      }

      await exportErrorTypeOutlinesToConfig();
      return true;
    } catch (e) {
      print('[TestDataImporter] 同步错类大纲失败: $e');
      return false;
    }
  }

  Future<bool> syncKnowledgeOutline(KnowledgeOutline outline) async {
    try {
      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);

      final existing = await dao.getById(outline.id!);
      if (existing != null) {
        await dao.update(outline);
      } else {
        await dao.insert(outline);
      }

      await exportKnowledgeOutlinesToConfig();
      return true;
    } catch (e) {
      print('[TestDataImporter] 同步知识点大纲失败: $e');
      return false;
    }
  }

  Future<bool> deleteErrorTypeOutline(String eid) async {
    try {
      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);
      await dao.deleteByEid(eid);
      await exportErrorTypeOutlinesToConfig();
      return true;
    } catch (e) {
      print('[TestDataImporter] 删除错类大纲失败: $e');
      return false;
    }
  }

  Future<bool> deleteKnowledgeOutline(String cid) async {
    try {
      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);
      await dao.deleteByCid(cid);
      await exportKnowledgeOutlinesToConfig();
      return true;
    } catch (e) {
      print('[TestDataImporter] 删除知识点大纲失败: $e');
      return false;
    }
  }

  Future<String> _getConfigFilePath(String fileName) async {
    final documentsPath = await _appDocumentsPath;
    final configDir = Directory('$documentsPath/test_data');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return '${configDir.path}/$fileName';
  }

  Future<String> _getConfigFileContent(String fileName) async {
    final appConfigPath = await _getConfigFilePath(fileName);
    final appConfigFile = File(appConfigPath);

    if (await appConfigFile.exists()) {
      print('[ConfigImporter] 从应用目录读取配置: $appConfigPath');
      return await appConfigFile.readAsString();
    } else {
      final defaultConfigPath = 'lib/pages/$fileName';
      print('[ConfigImporter] 从默认配置目录读取: $defaultConfigPath');
      try {
        // 使用 rootBundle 读取资源文件
        return await rootBundle.loadString(defaultConfigPath);
      } catch (e) {
        print('[ConfigImporter] 资源文件读取失败，尝试文件系统: $e');
        // 回退到文件系统读取（用于开发环境）
        return await File(defaultConfigPath).readAsString();
      }
    }
  }
}
