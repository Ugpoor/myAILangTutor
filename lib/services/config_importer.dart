import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../database/models/error_record.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/error_type_outline.dart';
import '../database/models/knowledge_outline.dart';
import '../database/models/skill.dart';
import 'llm_service.dart';

class ConfigImporter {
  static final ConfigImporter _instance = ConfigImporter._internal();
  factory ConfigImporter() => _instance;
  ConfigImporter._internal();

  /// 最近一次导入的错误详情（null 表示全部成功）
  String? lastErrorMessage;

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
    lastErrorMessage = null;
    final errors = <String>[];

    try {
      final db = await DatabaseHelper().database;

      if (clearExisting) {
        await _clearAllTables(db);
        print('[ConfigImporter] 已清除所有表数据');
      }

      // 逐步导入，每步独立容错
      try {
        await _importErrorTypeOutlines(db, skipIfExists: !clearExisting);
        print('[ConfigImporter] 已导入错类大纲');
      } catch (e) {
        errors.add('错类大纲: $e');
        print('[ConfigImporter] 导入错类大纲失败: $e');
      }

      try {
        await _importKnowledgeOutlines(db, skipIfExists: !clearExisting);
        print('[ConfigImporter] 已导入知识点大纲');
      } catch (e) {
        errors.add('知识点大纲: $e');
        print('[ConfigImporter] 导入知识点大纲失败: $e');
      }

      try {
        await _importErrorRecords(db);
        print('[ConfigImporter] 已导入错误记录');
      } catch (e) {
        errors.add('错误记录: $e');
        print('[ConfigImporter] 导入错误记录失败: $e');
      }

      try {
        await _importExercises(db);
        print('[ConfigImporter] 已导入习题');
      } catch (e) {
        errors.add('习题集: $e');
        print('[ConfigImporter] 导入习题失败: $e');
      }

      try {
        await _importPortfolioItems(db);
        print('[ConfigImporter] 已导入作品集');
      } catch (e) {
        errors.add('作品集: $e');
        print('[ConfigImporter] 导入作品集失败: $e');
      }

      try {
        await _importKnowledgePoints(db);
        print('[ConfigImporter] 已导入知识点');
      } catch (e) {
        errors.add('知识点: $e');
        print('[ConfigImporter] 导入知识点失败: $e');
      }

      try {
        print('[ConfigImporter] 准备导入技能...');
        await _importSkills(db);
        final skillCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM skills'),
        );
        print('[ConfigImporter] 导入后 skills 表记录数: $skillCount');
      } catch (e) {
        errors.add('技能库: $e');
        print('[ConfigImporter] 导入技能失败: $e');
      }

      if (errors.isNotEmpty) {
        lastErrorMessage = '以下项目导入失败: ${errors.join("; ")}';
        print('[ConfigImporter] $lastErrorMessage');
        return false;
      }

      return true;
    } catch (e) {
      lastErrorMessage = '导入配置数据失败: $e';
      print('[ConfigImporter] $lastErrorMessage');
      return false;
    }
  }

  Future<void> _clearAllTables(Database db) async {
    final tables = [
      'error_type_outlines',
      'knowledge_outlines',
      'error_records',
      'exercises',
      'test_papers',
      'tests',
      'questions',
      'portfolio_items',
      'knowledge_points',
      'skills',
    ];
    
    for (final table in tables) {
      try {
        // 检查表是否存在
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (result.isNotEmpty) {
          await db.delete(table);
        }
      } catch (e) {
        // 忽略删除表时的错误
        print('Warning: Could not clear table $table: $e');
      }
    }
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
    final outlines = (data['error_type_outlines'] as List?) ?? [];

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
    final outlines = (data['knowledge_outlines'] as List?) ?? [];

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
    final records = (data['error_records'] as List?) ?? [];

    final dao = ErrorRecordDao(db);
    for (final item in records) {
      // 安全地转换 eids 为 List<String>
      List<String> eidsList = [];
      if (item['eids'] != null) {
        final eidsDynamic = item['eids'] as List;
        eidsList = eidsDynamic.map((e) => e.toString()).toList();
      }
      
      await dao.insert(
        ErrorRecord(
          errorId: item['errorId'],
          eids: eidsList,
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

    final questionDao = QuestionDao(db);
    final testDao = TestDao(db);

    final tests = (data['tests'] as List?) ?? [];
    for (final item in tests) {
      List<String> lessonUnitList = [];
      List<String> kids = [];
      List<String> images = [];
      
      if (item['lessonUnitList'] != null) {
        final list = item['lessonUnitList'] as List;
        lessonUnitList = list.map((e) => e.toString()).toList();
      }
      
      if (item['kids'] != null) {
        final list = item['kids'] as List;
        kids = list.map((e) => e.toString()).toList();
      }

      if (item['images'] != null) {
        final list = item['images'] as List;
        images = list.map((e) => e.toString()).toList();
      }

      await testDao.insert(
        Test(
          tid: item['tid'],
          title: item['title'],
          lessonUnitList: lessonUnitList,
          kids: kids,
          status: item['status'] ?? '未开始',
          images: images,
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入试卷: ${tests.length} 条');

    final questions = (data['questions'] as List?) ?? [];
    for (final item in questions) {
      ImageRegion? examPaper;
      ImageRegion? answerSheet;
      ImageRegion? answerKey;
      ImageRegion? gradingSheet;

      if (item['examPaper'] != null) {
        final ep = item['examPaper'] as Map<String, dynamic>;
        examPaper = ImageRegion(
          imgNum: ep['imgNum'] as int,
          leftTop: (ep['left-top'] as List).map((e) => (e as num).toDouble()).toList(),
          bottomRight: (ep['bottom-right'] as List).map((e) => (e as num).toDouble()).toList(),
        );
      }

      if (item['answerSheet'] != null) {
        final as = item['answerSheet'] as Map<String, dynamic>;
        answerSheet = ImageRegion(
          imgNum: as['imgNum'] as int,
          leftTop: (as['left-top'] as List).map((e) => (e as num).toDouble()).toList(),
          bottomRight: (as['bottom-right'] as List).map((e) => (e as num).toDouble()).toList(),
        );
      }

      if (item['answerKey'] != null) {
        final ak = item['answerKey'] as Map<String, dynamic>;
        answerKey = ImageRegion(
          imgNum: ak['imgNum'] as int,
          leftTop: (ak['left-top'] as List).map((e) => (e as num).toDouble()).toList(),
          bottomRight: (ak['bottom-right'] as List).map((e) => (e as num).toDouble()).toList(),
        );
      }

      if (item['gradingSheet'] != null) {
        final gs = item['gradingSheet'] as Map<String, dynamic>;
        gradingSheet = ImageRegion(
          imgNum: gs['imgNum'] as int,
          leftTop: (gs['left-top'] as List).map((e) => (e as num).toDouble()).toList(),
          bottomRight: (gs['bottom-right'] as List).map((e) => (e as num).toDouble()).toList(),
        );
      }

      await questionDao.insert(
        Question(
          question: item['question'],
          exerciseId: item['exerciseId'],
          tid: item['tid'],
          kid: item['kid'],
          progress: item['progress'] ?? '未答题',
          category: item['category'],
          grading: item['grading'],
          gradingResult: item['gradingResult']?.toString(),
          answer: item['answer']?.toString(),
          correctAnswer: item['correctAnswer'],
          examPaper: examPaper,
          answerSheet: answerSheet,
          answerKey: answerKey,
          gradingSheet: gradingSheet,
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入题目: ${questions.length} 条');
  }

  Future<void> _importPortfolioItems(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/portfolio_items.json',
    );
    final data = json.decode(jsonString);
    final items = (data['portfolio_items'] as List?) ?? [];

    final appDocDir = await getApplicationDocumentsDirectory();
    final portfolioBaseDir = Directory('${appDocDir.path}/portfolio');
    if (!await portfolioBaseDir.exists()) {
      await portfolioBaseDir.create(recursive: true);
    }

    final dao = PortfolioDao(db);
    for (final item in items) {
      final title = item['title'] as String;
      final brief = item['brief'] as String? ?? '';
      final isOriginal = item['isOriginal'] as bool;
      final wid = item['wid'] as String?;
      
      final dirName = wid ?? 'portfolio_${DateTime.now().millisecondsSinceEpoch}';
      final itemDir = Directory('${portfolioBaseDir.path}/$dirName');
      if (!await itemDir.exists()) {
        await itemDir.create(recursive: true);
      }

      final htmlPath = '${itemDir.path}/index.html';
      if (!await File(htmlPath).exists()) {
        // 直接使用默认模板，避免导入时依赖 LLM 网络请求
        final htmlContent = _generateDefaultPortfolioHtml(title, brief, isOriginal);
        await File(htmlPath).writeAsString(htmlContent);
        print('[ConfigImporter] 生成作品集HTML: $htmlPath');
      }

      await dao.insert(
        PortfolioItem(
          wid: wid,
          title: title,
          isOriginal: isOriginal,
          contentPath: itemDir.path,
          brief: brief,
          kid: item['kid'] as String?,
          unitNumber: item['unitNumber'] as String?,
          lessonNumber: item['lessonNumber'] as String?,
          createdAt: DateTime.now(),
          lang: item['lang'] as String? ?? 'cn',
          testRecs: item['testRecs'] as String?,
          aiReview: item['aiReview'] as String?,
        ),
      );
    }
    print('[ConfigImporter] 导入作品集: ${items.length} 条');
  }

  Future<String> _generatePortfolioHtml(String title, String brief, bool isOriginal, LlmService llmService) async {
    try {
      String prompt;
      if (isOriginal) {
        prompt = '''请根据以下原创作文信息生成HTML格式的作品展示页面：

标题：$title
简介：$brief

要求：
1. 生成一篇完整的原创作文内容（根据标题和简介推断主题）
2. 使用优美的语言，适合学生作文水平
3. 输出完整的HTML文件，包含标题、正文内容
4. 不要输出任何解释性文字，只输出HTML内容
''';
      } else {
        prompt = '''请根据以下文学作品信息生成HTML格式的赏析页面：

作品标题：$title
简介：$brief

要求：
1. 如果是著名作品，请提供原文节选
2. 分析作品的写作手法和艺术特色
3. 输出完整的HTML文件，包含原文、赏析内容
4. 不要输出任何解释性文字，只输出HTML内容
''';
      }

      final response = await llmService.generateResponse(prompt);
      if (response['success'] == true && response['response'] != null) {
        return response['response'] as String;
      }
    } catch (e) {
      print('[ConfigImporter] LLM生成HTML失败: $e');
    }

    return _generateDefaultPortfolioHtml(title, brief, isOriginal);
  }

  String _generateDefaultPortfolioHtml(String title, String brief, bool isOriginal) {
    final authorMatch = RegExp(r'——(.+)$').firstMatch(title);
    final author = authorMatch != null ? authorMatch.group(1) : '';
    final cleanTitle = authorMatch != null && author != null ? title.substring(0, title.length - author.length - 2) : title;

    if (isOriginal) {
      return '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body { font-family: "Microsoft YaHei", sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.8; }
        h1 { color: #333; border-bottom: 2px solid #FF69B4; padding-bottom: 10px; }
        .brief { color: #666; font-style: italic; margin-bottom: 20px; }
        .content { margin-top: 20px; text-indent: 2em; }
    </style>
</head>
<body>
    <h1>$cleanTitle</h1>
    ${(author?.isNotEmpty ?? false) ? '<p class="author">——$author</p>' : ''}
    <p class="brief">$brief</p>
    <div class="content">
        <p>这是一篇原创作品，展示了作者独特的写作风格和视角。</p>
        <p>请在这里继续创作你的精彩内容...</p>
    </div>
</body>
</html>''';
    } else {
      return '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body { font-family: "Microsoft YaHei", sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.8; }
        h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }
        .author { color: #888; font-style: italic; }
        .brief { color: #666; margin-bottom: 20px; }
        .content { margin-top: 20px; text-indent: 2em; }
        .analysis { background-color: #E8F5E9; padding: 15px; border-radius: 8px; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>$cleanTitle</h1>
    ${(author?.isNotEmpty ?? false) ? '<p class="author">——$author</p>' : ''}
    <p class="brief">$brief</p>
    <div class="content">
        <p>这是一篇经典文学作品，具有很高的艺术价值和文学价值。</p>
        <p>作品通过细腻的描写和独特的叙事手法，展现了深刻的主题思想。</p>
    </div>
    <div class="analysis">
        <h2>写作手法赏析</h2>
        <ul>
            <li><strong>语言风格：</strong>文字优美，表达细腻，富有感染力。</li>
            <li><strong>结构特点：</strong>层次分明，过渡自然，逻辑清晰。</li>
            <li><strong>主题思想：</strong>主题深刻，寓意深远，引人深思。</li>
        </ul>
    </div>
</body>
</html>''';
    }
  }

  Future<void> _importKnowledgePoints(Database db) async {
    final jsonString = await rootBundle.loadString(
      'assets/test_data/knowledge_points.json',
    );
    final data = json.decode(jsonString);
    final points = (data['knowledge_points'] as List?) ?? [];

    final appDocDir = await getApplicationDocumentsDirectory();
    final knowledgeBaseDir = Directory('${appDocDir.path}/knowledge');
    if (!await knowledgeBaseDir.exists()) {
      await knowledgeBaseDir.create(recursive: true);
    }

    final dao = KnowledgePointDao(db);
    for (final item in points) {
      final title = item['title'] as String;
      final brief = item['brief'] as String? ?? '';
      final kid = item['kid'] as String?;
      
      final dirName = kid ?? 'knowledge_${DateTime.now().millisecondsSinceEpoch}';
      final itemDir = Directory('${knowledgeBaseDir.path}/$dirName');
      if (!await itemDir.exists()) {
        await itemDir.create(recursive: true);
      }

      final htmlPath = '${itemDir.path}/index.html';
      if (!await File(htmlPath).exists()) {
        // 直接使用默认模板，避免导入时依赖 LLM 网络请求
        final htmlContent = _generateDefaultKnowledgeHtml(title, brief);
        await File(htmlPath).writeAsString(htmlContent);
        print('[ConfigImporter] 生成知识点HTML: $htmlPath');
      }

      await dao.insert(
        KnowledgePoint(
          kid: kid,
          title: title,
          cid: item['cid'] as String? ?? '',
          contentPath: itemDir.path,
          brief: brief,
          unitNumber: item['unitNumber'] as String?,
          lessonNumber: item['lessonNumber'] as String?,
          createdAt: DateTime.now(),
          lang: item['lang'] as String? ?? 'cn',
        ),
      );
    }
    print('[ConfigImporter] 导入知识点: ${points.length} 条');
  }

  Future<String> _generateKnowledgeHtml(String title, String brief, LlmService llmService) async {
    try {
      final prompt = '''请根据以下知识点信息生成HTML格式的学习资料页面：

知识点标题：$title
简介：$brief

要求：
1. 详细解释该知识点的定义、特点、应用场景
2. 提供相关的例子和实例
3. 输出完整的HTML文件，包含标题、正文、示例等内容
4. 不要输出任何解释性文字，只输出HTML内容
''';

      final response = await llmService.generateResponse(prompt);
      if (response['success'] == true && response['response'] != null) {
        return response['response'] as String;
      }
    } catch (e) {
      print('[ConfigImporter] LLM生成知识点HTML失败: $e');
    }

    return _generateDefaultKnowledgeHtml(title, brief);
  }

  String _generateDefaultKnowledgeHtml(String title, String brief) {
    return '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body { font-family: "Microsoft YaHei", sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.8; }
        h1 { color: #333; border-bottom: 2px solid #2196F3; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 20px; }
        .brief { color: #666; margin-bottom: 20px; }
        .content { margin-top: 20px; text-indent: 2em; }
        .example { background-color: #E3F2FD; padding: 15px; border-radius: 8px; margin-top: 15px; }
    </style>
</head>
<body>
    <h1>$title</h1>
    <p class="brief">$brief</p>
    
    <h2>知识点概述</h2>
    <div class="content">
        <p>本知识点是语文学习中的重要内容，掌握它对于提升语言能力和文学素养具有重要意义。</p>
    </div>
    
    <h2>核心要点</h2>
    <ul>
        <li>深入理解概念的本质和内涵</li>
        <li>掌握相关的理论知识和方法</li>
        <li>学会在实践中灵活运用</li>
    </ul>
    
    <div class="example">
        <strong>学习提示：</strong>结合具体例子理解知识点，多做练习巩固所学内容。
    </div>
</body>
</html>''';
  }

  Future<void> _importSkills(Database db) async {
    try {
      print('[ConfigImporter] 尝试读取 skills.json...');
      
      // 首先检查应用目录中是否有旧的 skills.json 文件，如果有则删除
      final appDocumentsPath = await _appDocumentsPath;
      final appSkillsPath = '$appDocumentsPath/test_data/skills.json';
      final appSkillsFile = File(appSkillsPath);
      if (await appSkillsFile.exists()) {
        print('[ConfigImporter] 发现应用目录中有旧的 skills.json，删除它');
        await appSkillsFile.delete();
      }
      
      // 强制从资源文件读取
      final jsonString = await rootBundle.loadString(
        'assets/test_data/skills.json',
      );
      print('[ConfigImporter] 成功读取 skills.json，长度: ${jsonString.length}');
      
      // 打印前200个字符来确认内容
      print('[ConfigImporter] skills.json 内容预览: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}...');
      
      final data = json.decode(jsonString);
      print('[ConfigImporter] JSON解析成功');
      
      final skills = (data['skills'] as List?) ?? [];
      print('[ConfigImporter] 技能列表长度: ${skills.length}');
      
      // 打印第一个技能的信息
      if (skills.isNotEmpty) {
        final firstSkill = skills[0];
        print('[ConfigImporter] 第一个技能: name=${firstSkill['name']}, skillId=${firstSkill['skillId']}, category=${firstSkill['category']}');
      }
      
      if (skills.isEmpty) {
        print('[ConfigImporter] 警告：skills.json 中没有技能数据');
        return;
      }

      final dao = SkillDao(db);
      int count = 0;
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
        count++;
        print('[ConfigImporter] 已导入技能: ${item['name']} (${item['skillId']})');
      }
      print('[ConfigImporter] 导入技能完成: 共 $count 条');
    } catch (e, stackTrace) {
      print('[ConfigImporter] 导入技能失败: $e');
      print('[ConfigImporter] 堆栈跟踪: $stackTrace');
    }
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
    }

    // 从打包资源读取（debug 和 release/APK 均有效）
    final assetPaths = ['lib/pages/$fileName', 'assets/test_data/$fileName'];
    for (final assetPath in assetPaths) {
      try {
        print('[ConfigImporter] 从打包资源读取: $assetPath');
        return await rootBundle.loadString(assetPath);
      } catch (e) {
        print('[ConfigImporter] 资源 $assetPath 读取失败: $e');
      }
    }

    throw Exception('配置文件 $fileName 在所有路径均未找到');
  }
}
