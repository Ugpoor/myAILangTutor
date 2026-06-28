import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:html/parser.dart' as html_parser;
import '../database/models/inbox_item.dart' hide DatabaseHelper;
import '../database/models/chat_message.dart';
import '../database/models/error_record.dart';
import '../database/models/test.dart';
import '../database/models/question.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/move_record.dart';
import '../database/models/skill.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart' show DatabaseHelper;
import 'llm_service.dart';

typedef ProcessProgressCallback =
    void Function(int current, int total, String reasoning);

class SkillConfig {
  static Map<String, String> _keywordPatterns = {};

  static Future<void> loadFromSkills() async {
    final db = await DatabaseHelper().database;
    final skillDao = SkillDao(db);

    final skills = await skillDao.getAll(category: '内部');

    for (final skill in skills) {
      if (skill.internalFunction != null && skill.parameters != null) {
        _keywordPatterns[skill.internalFunction!] = skill.parameters!;
      }
    }
  }

  static String? getPattern(String functionName) {
    return _keywordPatterns[functionName];
  }
}

class IntentData {
  final String subject;
  final String text;

  IntentData({required this.subject, required this.text});

  factory IntentData.fromJson(Map<String, dynamic> json) {
    return IntentData(subject: json['subject'] ?? '', text: json['text'] ?? '');
  }
}

// 栏目和目录映射
const Map<String, String> _columnDirectories = {
  '知识点': 'knowledge',
  '习题集': 'exercises',
  '作品集': 'portfolio',
  '错题本': 'errors',
  '无法分类': 'unknown',
  '未知归类': 'inbox',
};

/// Unified classification result returned by classifyItem()
class ClassificationResult {
  final String category;
  final String reasoning;
  final String? newTitle;
  final String? content;

  ClassificationResult({
    required this.category,
    required this.reasoning,
    this.newTitle,
    this.content,
  });
}

/// 文件日志工具，用于调试 JSON 解析流程
/// 使用 StringBuffer 收集日志，在 flush 时一次性写入文件
class _ParseLog {
  static File? _logFile;
  static bool _initialized = false;
  static final StringBuffer _buffer = StringBuffer();
  static String? _logPath;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _logPath = '${docDir.path}/parse_debug.log';
      _logFile = File(_logPath!);
      // 清空旧日志
      await _logFile!.writeAsString('=== Parse Debug Log ${DateTime.now()} ===\n');
      _initialized = true;
      print('[ParseLog] 日志文件: $_logPath');
    } catch (e) {
      print('[ParseLog] 初始化失败: $e');
    }
  }

  /// 同步写入日志（收集到 buffer）
  static void log(String message) {
    final text = '[${DateTime.now().toIso8601String()}] $message';
    print(text); // 同时输出到 logcat
    _buffer.writeln(text);
  }

  /// 异步 flush buffer 到文件
  static Future<void> flush() async {
    if (_buffer.isEmpty) return;
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(_buffer.toString(), mode: FileMode.append);
        _buffer.clear();
      }
    } catch (e) {
      print('[ParseLog] flush 失败: $e');
    }
  }

  /// 获取日志文件路径
  static String? get logPath => _logPath;
}

class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LlmService _llmService = LlmService();

  // 获取app文档目录
  Future<Directory> getAppDocDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return docDir;
  }

  // 获取指定栏目的目录
  Future<Directory> getColumnDirectory(String columnName) async {
    final appDocDir = await getAppDocDirectory();
    final dirName = _columnDirectories[columnName] ?? 'inbox';
    final columnDir = Directory('${appDocDir.path}/$dirName');
    if (!await columnDir.exists()) {
      await columnDir.create(recursive: true);
    }
    return columnDir;
  }

  // 获取所有栏目目录
  Future<Map<String, Directory>> getAllColumnDirectories() async {
    final result = <String, Directory>{};
    for (final entry in _columnDirectories.entries) {
      result[entry.key] = await getColumnDirectory(entry.key);
    }
    return result;
  }

  /// 解析文件路径：如果存储的路径不存在，在所有栏目目录中搜索同名目录
  /// 用于修复之前操作失败导致 DB 路径与实际文件位置不一致的情况
  Future<String> _resolveFilePath(String filePath) async {
    final dir = Directory(filePath);
    if (await dir.exists()) {
      return filePath;
    }

    // 存储的路径不存在，搜索所有栏目目录
    final dirName = p.basename(filePath);
    print('[ResolvePath] 路径不存在: $filePath，搜索目录名: $dirName');

    final allDirs = await getAllColumnDirectories();
    for (final entry in allDirs.entries) {
      final candidatePath = '${entry.value.path}/$dirName';
      if (await Directory(candidatePath).exists()) {
        print('[ResolvePath] 找到文件: $candidatePath (栏目: ${entry.key})');
        return candidatePath;
      }
    }

    print('[ResolvePath] 未找到文件，返回原路径: $filePath');
    return filePath;
  }

  // 从文件系统扫描所有条目
  Future<List<InboxItem>> scanAllItemsFromFileSystem() async {
    final result = <InboxItem>[];
    final columnDirs = await getAllColumnDirectories();

    for (final entry in columnDirs.entries) {
      final columnName = entry.key;
      final columnDir = entry.value;

      try {
        final entities = columnDir.listSync();
        for (final entity in entities) {
          if (entity is Directory) {
            final item = await _createItemFromDirectory(columnName, entity);
            if (item != null) {
              result.add(item);
            }
          }
        }
      } catch (e) {
        print('[ScanError] 扫描目录 $columnName 失败: $e');
      }
    }

    // 按创建时间倒序
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  // 有效分类列表（非默认分类）
  static const Set<String> _validCategories = {
    '错题本', '习题集', '作品集', '知识点',
  };

  // 从目录创建条目
  Future<InboxItem?> _createItemFromDirectory(
    String columnName,
    Directory dir,
  ) async {
    try {
      final htmlFile = File('${dir.path}/index.html');
      if (!await htmlFile.exists()) {
        return null;
      }

      final stat = await dir.stat();
      final createdAt = stat.modified;

      // 从数据库读取标签信息
      final dbItem = await _dbHelper.getInboxItemByFilePath(dir.path);

      final title = dbItem?.title ?? _extractTitle(dir.path) ?? '未命名';
      final source = dbItem?.source ?? '本地文件';
      final url = dbItem?.url ?? '';
      final status = dbItem?.status ?? '未处理';
      final isValid = dbItem != null;

      // 优先使用 DB 中的分类（如果是有效分类）；否则使用目录名
      String category;
      if (dbItem != null && _validCategories.contains(dbItem.category)) {
        category = dbItem.category;
      } else if (_validCategories.contains(columnName)) {
        category = columnName;
      } else if (dbItem != null && dbItem.category.isNotEmpty) {
        category = dbItem.category;
      } else {
        category = columnName;
      }

      return InboxItem(
        id: dbItem?.id,
        title: title,
        source: source,
        url: url,
        filePath: dir.path,
        content: dbItem?.content ?? '',
        category: category,
        status: status,
        createdAt: createdAt,
        updatedAt: dbItem?.updatedAt,
        isValid: isValid,
      );
    } catch (e) {
      print('[CreateItemError] 创建条目失败: $e');
      return null;
    }
  }

  // 从目录路径提取标题
  String? _extractTitle(String dirPath) {
    final dirName = p.basename(dirPath);
    // 如果是时间戳格式，提取时间
    if (dirName.contains('-')) {
      final parts = dirName.split('-');
      if (parts.length >= 2) {
        try {
          final timestamp = int.tryParse(parts[0]);
          if (timestamp != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            return '记录 ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
        } catch (e) {
          // 忽略
        }
      }
    }
    return dirName;
  }

  // 从URL下载内容，保存到收件箱目录
  Future<InboxItem> downloadAndSaveContent({
    required String url,
    required String title,
    String source = '未知',
  }) async {
    // 使用时间戳+随机字符串创建唯一目录名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomStr = _generateRandomString(8);
    final dirName = '$timestamp-$randomStr';

    // 保存到收件箱目录
    final inboxDir = await getColumnDirectory('未知归类');
    final itemDir = Directory('${inboxDir.path}/$dirName');
    await itemDir.create(recursive: true);

    // 下载并保存HTML
    await _downloadAndSaveHtml(url, itemDir);

    // 从HTML提取文本内容
    final content = await _extractTextFromHtml(itemDir);

    // 创建条目对象
    final item = InboxItem(
      title: title,
      source: source,
      url: url,
      filePath: itemDir.path,
      content: content,
      category: '未知归类',
      status: '未处理',
      createdAt: DateTime.now(),
    );

    // 保存标签信息到数据库
    final id = await _dbHelper.insertInboxItem(item);

    return item.copyWith(id: id);
  }

  // 下载并保存HTML
  Future<void> _downloadAndSaveHtml(String url, Directory itemDir) async {
    final htmlFile = File('${itemDir.path}/index.html');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await htmlFile.writeAsString(response.body);
      }
    } catch (e) {
      // 保存失败，写入空文件
      await htmlFile.writeAsString('');
    }
  }

  // 从HTML提取文本内容
  Future<String> _extractTextFromHtml(Directory itemDir) async {
    final htmlFile = File('${itemDir.path}/index.html');
    if (!await htmlFile.exists()) {
      return '';
    }

    try {
      final html = await htmlFile.readAsString();
      final document = html_parser.parse(html);
      return document.body?.text ?? '';
    } catch (e) {
      return '';
    }
  }

  // 生成随机字符串
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String result = '';
    for (int i = 0; i < length; i++) {
      final randomIndex = DateTime.now().microsecondsSinceEpoch % chars.length;
      result += chars[randomIndex];
    }
    return result;
  }

  // 移动条目到新栏目
  Future<void> moveItemToColumn(InboxItem item, String newColumn) async {
    final oldDir = Directory(item.filePath);
    if (!await oldDir.exists()) {
      print('[MoveItem] 源目录不存在: ${item.filePath}，跳过移动');
      // 即使源目录不存在，仍然更新 DB 中的分类信息
      if (item.id != null) {
        final updatedItem = item.copyWith(
          category: newColumn,
          updatedAt: DateTime.now(),
        );
        await _dbHelper.updateInboxItem(updatedItem);
      }
      return;
    }

    // 记录移动前的信息
    final fromCategory = item.category;
    final fromPath = item.filePath;
    final inboxItemId = item.id?.toString() ?? item.filePath;

    // 获取新栏目的目录
    final newColumnDir = await getColumnDirectory(newColumn);
    final dirName = p.basename(oldDir.path);

    // 确定最终目标路径
    String finalPath = '${newColumnDir.path}/$dirName';

    // 如果源路径和目标路径相同（同目录移动），跳过 rename
    if (finalPath == oldDir.path) {
      print('[MoveItem] 源路径与目标路径相同，跳过文件移动: $finalPath');
    } else if (await Directory(finalPath).exists()) {
      // 如果目标目录已存在，添加后缀
      var suffix = 1;
      while (await Directory(
        '${newColumnDir.path}/${dirName}_$suffix',
      ).exists()) {
        suffix++;
      }
      finalPath = '${newColumnDir.path}/${dirName}_$suffix';
      await oldDir.rename(finalPath);
    } else {
      await oldDir.rename(finalPath);
    }

    // 更新数据库（使用实际移动后的路径）
    final updatedItem = item.copyWith(
      category: newColumn,
      filePath: finalPath,
      updatedAt: DateTime.now(),
    );

    if (item.id != null) {
      await _dbHelper.updateInboxItem(updatedItem);
    } else {
      // 如果数据库没有记录，插入新记录
      await _dbHelper.insertInboxItem(updatedItem);
      // 注意：InboxItem 是不可变对象，插入后不需要更新本地引用
    }

    // 记录移动历史（非关键操作，失败不中断主流程）
    try {
      final moveRecord = MoveRecord(
        inboxItemId: inboxItemId,
        fromCategory: fromCategory,
        toCategory: newColumn,
        fromPath: fromPath,
        toPath: finalPath,
        movedAt: DateTime.now(),
      );

      final db = await _dbHelper.database;
      final moveRecordDao = MoveRecordDao(db);
      await moveRecordDao.insert(moveRecord);
    } catch (e) {
      print('[MoveItem] 移动历史记录保存失败（不影响主流程）: $e');
    }

    print('[MoveItem] 条目已移动到: $finalPath');
  }

  // 删除条目
  Future<void> deleteItem(InboxItem item) async {
    // 删除文件
    final dir = Directory(item.filePath);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        print('[DeleteError] 删除文件失败: $e');
      }
    }

    // 删除数据库记录
    if (item.id != null) {
      await _dbHelper.deleteInboxItem(item.id!);
    }
  }

  // 更新条目标签信息
  Future<void> updateItemInfo(InboxItem item) async {
    if (item.id != null) {
      await _dbHelper.updateInboxItem(item);
    } else {
      await _dbHelper.insertInboxItem(item);
      // 注意：InboxItem 是不可变对象，插入后不需要更新本地引用
      // 调用者应使用数据库返回的 id 创建新对象
    }
  }

  // 获取所有条目（优先从文件系统）
  Future<List<InboxItem>> getAllInboxItems() async {
    return await scanAllItemsFromFileSystem();
  }

  // 过滤条目
  Future<List<InboxItem>> filterItems({
    String? keyword,
    Set<String>? source,
    Set<String>? category,
    Set<String>? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? isValid,
    String? contentKeyword,
  }) async {
    final allItems = await getAllInboxItems();

    return allItems.where((item) {
      bool match = true;

      if (keyword != null && keyword.isNotEmpty) {
        match =
            match && item.title.toLowerCase().contains(keyword.toLowerCase());
      }

      if (source != null && source.isNotEmpty) {
        match =
            match &&
            source.any(
              (s) => item.source.toLowerCase().contains(s.toLowerCase()),
            );
      }

      if (category != null && category.isNotEmpty) {
        match = match && category.contains(item.category);
      }

      if (status != null && status.isNotEmpty) {
        match = match && status.contains(item.status);
      }

      if (isValid != null) {
        match = match && item.isValid == isValid;
      }

      if (contentKeyword != null && contentKeyword.isNotEmpty) {
        match =
            match &&
            item.content.toLowerCase().contains(contentKeyword.toLowerCase());
      }

      return match;
    }).toList();
  }

  // Classify an inbox item: extract content, optionally optimize title, then classify via LLM
  /// Returns [ClassificationResult] with the final category and optional new title
  Future<ClassificationResult> classifyItem(InboxItem item) async {
    print('[SortLog] ========== 开始分类处理 (unified): ${item.title}');

    // Step 1: Extract headings and text content from HTML
    // 解析文件路径，修复可能的路径不一致问题
    final resolvedPath = await _resolveFilePath(item.filePath);
    final htmlPath = '$resolvedPath/index.html';
    final file = File(htmlPath);

    if (!await file.exists()) {
      throw Exception('HTML文件不存在: $htmlPath');
    }

    final htmlContent = await file.readAsString(encoding: utf8);
    final extractedTitles = _extractHeadingsFromHtml(htmlContent);
    extractedTitles.add(item.title);
    final uniqueTitles = extractedTitles.toSet().toList();

    final textContent = _extractTextFromHtmlFile(htmlContent);

    // Step 2: Optional title optimization (only if multiple headings found)
    String finalTitle = item.title;
    if (uniqueTitles.length >= 2) {
      finalTitle = await _selectBestTitle(uniqueTitles, textContent);
    }

    // Step 3: Two-stage classification using LLM
    // Stage 1: First classify into broad categories
    String category = await _firstStageClassification(textContent);

    // Stage 2: If classified as exercise-related, further determine if it's error book or exercise set
    String stageReasoning = '';
    if (category == '习题相关') {
      category = await _secondStageClassification(textContent);
      stageReasoning = ' → 二级分类完成';
    }

    print('[SortLog] 分类结果: $category (标题: $finalTitle)');
    print('[SortLog] ========== 分类处理完成 (unified) ==========');

    return ClassificationResult(
      category: category,
      reasoning: 'LLM分类完成$stageReasoning',
      newTitle: finalTitle != item.title ? finalTitle : null,
      content: textContent,
    );
  }

  /// First stage: Classify into broad categories
  Future<String> _firstStageClassification(String content) async {
    final systemPrompt =
        '''你是一位专业的文档分类助手。请将文档归类到以下四大类别之一。

=== 分类定义 ===
1，「习题相关」：包含题目、答案、练习题、试卷、答题等学习练习相关内容（无论是否有错误分析）
2，「作品集」：范文、作文、原创文章、名人名篇等作品性文本。不是练习题，也不是学习笔记。
3，「知识点」：文化知识、历史地理知识介绍、语言规则讲解、学习方法心得、笔记摘要等知识类内容。
4，「无法分类」：与学习无关的内容、工具输出、系统信息、闲聊对话等。

请对以下内容进行分类，选择最合适的栏目标签，只需回复数字序号（1-4），不要回复其他内容。

内容：
$content

请只回复一个数字（1-4）。''';

    final response = await _llmService.generateResponse(systemPrompt);
    final numberMap = <String, String>{
      '1': '习题相关',
      '2': '作品集',
      '3': '知识点',
      '4': '无法分类',
    };

    if (response['success'] == true) {
      final resp = response['response'] as String;
      final match = RegExp(r'[1-4]').firstMatch(resp);
      if (match != null) {
        final numStr = match.group(0)!;
        if (numberMap.containsKey(numStr)) {
          return numberMap[numStr]!;
        }
      }
    }
    return '无法分类';
  }

  /// Second stage: Determine if exercise-related content is error book or exercise set
  Future<String> _secondStageClassification(String content) async {
    final systemPrompt =
        '''你是一位专业的文档分类助手。请判断以下习题相关文档属于哪一类。

=== 分类定义 ===
1，「错题本」：文档中包含答卷、批改痕迹、错误分析、技巧总结、"错在哪里"、"正确答案是"、"我的答案"、"批阅"等订正相关信息。核心特征是"有错且有分析与修正"。
2，「习题集」：仅包含题目和参考答案，没有答卷、批阅记录、错误分析等订正信息。是原始练习题、试卷、思考题。

请仔细阅读内容，判断是否包含错误分析、批阅信息、错在哪里等内容：

内容：
$content

请只回复一个数字（1 或 2）。''';

    final response = await _llmService.generateResponse(systemPrompt);

    if (response['success'] == true) {
      final resp = response['response'] as String;
      if (resp.contains('1')) {
        return '错题本';
      } else if (resp.contains('2')) {
        return '习题集';
      }
    }
    // Default to exercise set if uncertain
    return '习题集';
  }

  // Extract heading tags from HTML content
  List<String> _extractHeadingsFromHtml(String html) {
    final List<String> headings = [];
    final regex = RegExp(
      r'<h([1-6])[^>]*>(.*?)</h[1-6]>',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(html)) {
      final text =
          match.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (text.isNotEmpty && text.length > 2) {
        headings.add(text);
      }
    }
    return headings;
  }

  // Extract clean text from HTML
  String _extractTextFromHtmlFile(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length > 30000) {
      text =
          text.substring(0, 30000) +
          '\n...(truncated ${text.length - 30000} more chars)';
    }
    return text;
  }

  // Use LLM to select the best title from candidates
  Future<String> _selectBestTitle(List<String> titles, String content) async {
    final titlesList = titles
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}、"${entry.value}"')
        .join('\n');

    final prompt =
        '''请选择最能反映以下内容的标题，只需回复序号（如：1、2、3等）。

内容摘要：
$content

可选标题：
$titlesList

请只回复序号。''';

    final response = await _llmService.generateResponse(prompt);

    if (response['success'] == true) {
      final responseText = response['response'] as String;
      final match = RegExp(r'(\d+)').firstMatch(responseText);
      if (match != null) {
        final index = int.tryParse(match.group(1)!) ?? 1;
        if (index >= 1 && index <= titles.length) {
          return titles[index - 1];
        }
      }
    }

    // Fallback to first title
    return titles.first;
  }

  // Classify by content string only (legacy method, kept for batch processing)
  Future<Map<String, String>> classifyByLlm(String content) async {
    final systemPrompt =
        '''你是一位专业的文档分类助手。请判断以下文档内容最属于哪个分类栏目（每篇文档只能归入一个类别，不可多选）。

请先阅读下方【分类定义】，再仔细阅读待分类文档，最后从 5 个选项中选出唯一最匹配的一个。

=== 分类定义（严格互斥） ===
1，「习题集」：仅包含题目和答案，没有答卷、批阅记录、错误分析等内容。通常是原始练习题、试卷、思考题。
2，「错题本」：在习题的基础上，额外包含答卷/批改痕迹/错误分析/技巧总结等订正信息。核心特征是"有错且有分析与修正"。
3，「作品集」：范文、作文、原创文章、名人名篇等作品性文本。不是练习题，也不是学习笔记。
4，「知识点」：文化知识、历史地理知识介绍、语言规则讲解、学习方法心得、笔记摘要等知识类内容。
5，「无法分类」：与学习无关的内容、工具输出、系统信息、闲聊对话等。

=== 核心区分要点 ===
- 习题集 vs 错题本：若文档仅有题目和参考答案 → 归为习题集；若有答卷标记、错误分析、技巧总结 → 归为错题本

请对以下内容进行分类，选择最合适的栏目标签，只需回复数字序号（1-5），不要回复其他内容。

内容：
$content

请只回复一个数字（1-5）。''';

    try {
      print('[SortLog] [classifyByLlm] 调用 LLM，内容长度: ${content.length}');
      final response = await _llmService.generateResponse(systemPrompt);
      String category = '无法分类';
      String reasoning = '';

      if (response['success'] == true) {
        final responseText = response['response'] as String;
        final match = RegExp(r'[1-5]').firstMatch(responseText);
        if (match != null) {
          final numStr = match.group(0)!;
          final numberMap = <String, String>{
            '1': '习题集',
            '2': '错题本',
            '3': '作品集',
            '4': '知识点',
            '5': '无法分类',
          };
          if (numberMap.containsKey(numStr)) {
            category = numberMap[numStr]!;
          }
        }
        reasoning = 'LLM分类完成';
      } else {
        reasoning = 'LLM分类失败: ${response['reasoning']}';
      }

      final aiReply = '分类结果：$category\n\n分类依据：$reasoning';
      await _saveClassificationChat(content, aiReply);

      return {'category': category, 'reasoning': reasoning};
    } catch (e) {
      print('LLM分类失败: $e');
      final aiReply = '分类结果：无法分类（LLM请求失败）';
      await _saveClassificationChat(content, aiReply);
      return {'category': '无法分类', 'reasoning': 'LLM请求失败: $e'};
    }
  }

  int _getCategoryNumber(String category) {
    switch (category) {
      case '习题集':
        return 1;
      case '错题本':
        return 2;
      case '作品集':
        return 3;
      case '知识点':
        return 4;
      default:
        return 5;
    }
  }

  Future<void> _saveChatMessage(String content, bool isUser) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.insert('chat_messages', {
        'content': content,
        'is_user': isUser ? 1 : 0,
        'lang': 'cn',
      });
      print('[ChatLog] ${isUser ? 'User' : 'AI'}: $content');
    } catch (e) {
      print('[ChatLogError] 保存聊天消息失败: $e');
    }
  }

  Future<void> _saveClassificationChat(String userInput, String aiReply) async {
    await _saveChatMessage(userInput, true);
    await _saveChatMessage(aiReply, false);
  }

  /// Save full classification details as a single AI reply message with proper formatting
  Future<void> _saveFullClassificationChat({
    required InboxItem item,
    required String category,
    required String reasoning,
    String? newTitle,
  }) async {
    try {
      // Build detailed AI response with proper line breaks for display
      final StringBuffer aiReply = StringBuffer();
      aiReply.writeln('📄 ${item.title}');
      if (newTitle != null && newTitle != item.title) {
        aiReply.writeln('🔄 标题优化: ${item.title} → $newTitle');
      }
      aiReply.writeln('✅ 分类结果：$category');
      aiReply.writeln('📋 分类依据：$reasoning');

      // Save as a single AI reply to chat_messages table
      await _saveChatMessage(aiReply.toString(), false);
      print(
        '[ChatLog] [Classification] Saved full chat record for: ${item.title}',
      );
    } catch (e) {
      print('[ChatLogError] 保存完整分类记录失败: $e');
    }
  }

  Future<void> processItems(
    List<InboxItem> items, {
    ProcessProgressCallback? onProgress,
  }) async {
    for (int i = 0; i < items.length; i++) {
      final result = await processAndClassifyItem(items[i]);
      final reasoning = result['reasoning']!;

      if (onProgress != null) {
        onProgress(i + 1, items.length, reasoning);
      }
    }
  }

  /// Unified batch processing: use classifyItem (reads from file) for consistent behavior
  /// If [useManualCategory] is true, it skips AI classification and uses item.category directly
  Future<Map<String, String>> processAndClassifyItem(
    InboxItem item, {
    bool useManualCategory = false,
  }) async {
    print('[SortLog] ========== 开始分类处理 (unified): ${item.title}');

    try {
      String category;
      String reasoning;
      String? newTitle;
      String? content;

      // 首先解析文件路径，修复之前操作失败导致的路径不一致问题
      final resolvedFilePath = await _resolveFilePath(item.filePath);
      final resolvedItem = item.filePath != resolvedFilePath
          ? item.copyWith(filePath: resolvedFilePath)
          : item;

      if (useManualCategory ||
          item.category != '未知归类' && item.category != '无法分类') {
        // 使用手工指定的分类
        category = item.category;
        reasoning = '手工分类';
        newTitle = item.title;
        // 从HTML文件中提取内容
        try {
          final htmlPath = '${resolvedFilePath}/index.html';
          final file = File(htmlPath);
          if (await file.exists()) {
            final htmlContent = await file.readAsString(encoding: utf8);
            content = _extractTextFromHtmlFile(htmlContent);
          }
        } catch (e) {
          content = item.content;
        }
        print('[SortLog] 使用手工分类: $category');
      } else {
        // 使用AI自动分类
        final result = await classifyItem(resolvedItem);
        category = result.category;
        reasoning = result.reasoning;
        newTitle = result.newTitle;
        content = result.content;
        print('[SortLog] AI分类结果: $category (标题: $newTitle)');
      }

      // Determine actual file path after potential move
      String finalFilePath = resolvedFilePath;
      if (resolvedItem.category != category || newTitle != null) {
        await moveItemToColumn(resolvedItem, category);

        // Find actual moved path (may have _N suffix)
        final newColumnDir = await getColumnDirectory(category);
        final dirName = p.basename(resolvedFilePath);
        final candidatePath = '${newColumnDir.path}/$dirName';
        if (await Directory(candidatePath).exists()) {
          finalFilePath = candidatePath;
        } else {
          // 检查是否带后缀
          bool found = false;
          for (var suffix = 1; suffix <= 10; suffix++) {
            final searchPath = '${newColumnDir.path}/${dirName}_$suffix';
            if (await Directory(searchPath).exists()) {
              finalFilePath = searchPath;
              found = true;
              break;
            }
          }
          // 如果找不到，可能源文件不存在或已在目标位置，保留当前路径
          if (!found) {
            // 再次检查原始路径是否仍然存在
            if (await Directory(resolvedFilePath).exists()) {
              finalFilePath = resolvedFilePath;
            }
            print('[SortLog] 警告: 文件移动后未在目标目录找到，使用路径: $finalFilePath');
          }
        }
        print('[SortLog] 文件路径: $finalFilePath');
      }

      // Build updated item with latest data
      final updatedItem = item.copyWith(
        title: newTitle ?? item.title,
        category: category,
        filePath: finalFilePath,
        status: '已处理',
        content: content ?? item.content,
      );

      // Persist to inbox_items table
      await updateItemInfo(updatedItem);

      // Write through to corresponding module table
      final moduleInserted = await _writeToModuleTable(updatedItem);

      // 验证目标栏目数据库是否成功插入记录
      if (!moduleInserted) {
        print('[SortLog] 警告: 目标栏目数据库记录插入失败，但分类已完成');
      } else {
        print('[SortLog] 目标栏目数据库记录已成功插入');
      }

      // Save full chat history to conversation database
      await _saveFullClassificationChat(
        item: item,
        category: category,
        reasoning: reasoning,
        newTitle: newTitle,
      );

      print('[SortLog] ========== 分类处理完成 (unified) ==========');

      return {'category': category, 'reasoning': reasoning};
    } catch (e) {
      print('[SortLog] 分类处理异常: $e');

      // 更新状态为整理失败
      final failedItem = item.copyWith(status: '整理失败');
      await updateItemInfo(failedItem);

      return {'category': '无法分类', 'reasoning': '处理失败: $e，请人工处理'};
    }
  }

  // 分类后写入对应模块表（通过 LLM 将 inbox item content 解析为目标数据结构）
  Future<bool> _writeToModuleTable(InboxItem item) async {
    final db = await _dbHelper.database;

    // 如果 content 为空或只有占位符，跳过智能解析，返回 false 表示未成功插入
    if (item.content.isEmpty || item.content == '正在处理中...') {
      _ParseLog.log(' 内容未就绪，跳过智能解析');
      return false;
    }

    try {
      // 对于错题本，先尝试直接解析内容为 JSON（支持数组和单对象）
      if (item.category == '错题本') {
        final directResult = await _tryDirectJsonInsert(db, item);
        if (directResult) {
          return true;
        }
        // 直接 JSON 解析失败，回退到 LLM 解析
        _ParseLog.log(' 直接JSON解析失败，尝试LLM解析');
      }

      // 调用 LLM 将 content 解析为目标模块的数据结构
      final parsedData = await parseContentForCategory(
        item.content,
        item.title,
        item.category,
      );

      switch (item.category) {
        case '错题本':
          await _insertErrorRecord(db, item, parsedData);
          return true;
        case '习题集':
          await _insertExercise(db, item, parsedData);
          return true;
        case '作品集':
          await _insertPortfolioItem(db, item, parsedData);
          return true;
        case '知识点':
          await _insertKnowledgePoint(db, item, parsedData);
          return true;
        default:
          _ParseLog.log(' 未知分类: ${item.category}');
          return false;
      }
    } catch (e) {
      _ParseLog.log(' LLM 解析失败: $e');
      // LLM 失败时降级为仅标题插入
      return await _fallbackInsertModuleTable(item);
    }
  }

  /// 尝试直接解析内容为 JSON 并批量插入错题记录
  /// 支持 JSON 数组（多条错题）和单个 JSON 对象
  /// 内容可能包含非 JSON 的网页文本（如标题、页脚），需要先提取 JSON 部分
  /// 当标准 JSON 解析失败时，自动启用高容错解析机制
  Future<bool> _tryDirectJsonInsert(Database db, InboxItem item) async {
    try {
      // 初始化文件日志
      await _ParseLog.init();
      final content = item.content.trim();
      _ParseLog.log(' ========== _tryDirectJsonInsert 开始 ==========');
      _ParseLog.log(' 日志文件路径: ${_ParseLog.logPath}');
      _ParseLog.log(' content 长度: ${content.length}');
      _ParseLog.log(' content 前200字符: ${content.length > 200 ? content.substring(0, 200) : content}');

      // Step 1: 尝试直接解析整个内容
      dynamic decoded;
      try {
        decoded = json.decode(content);
        _ParseLog.log(' 直接 json.decode 成功，类型: ${decoded.runtimeType}');
      } catch (e) {
        _ParseLog.log(' 直接 json.decode 失败: $e');
        // 直接解析失败，尝试从内容中提取 JSON 部分
        final jsonStr = _extractJsonFromContent(content);
        if (jsonStr == null) {
          _ParseLog.log(' 未找到可解析的JSON内容');
          return false;
        }
        _ParseLog.log(' 提取的 jsonStr 长度: ${jsonStr.length}');
        _ParseLog.log(' 提取的 jsonStr 前200字符: ${jsonStr.length > 200 ? jsonStr.substring(0, 200) : jsonStr}');
        try {
          decoded = json.decode(jsonStr);
          _ParseLog.log(' 提取后 json.decode 成功，类型: ${decoded.runtimeType}');
        } catch (e) {
          _ParseLog.log(' 提取后 json.decode 失败: $e');
          _ParseLog.log(' 标准JSON解析失败，尝试高容错解析');
          // 标准解析失败，进入高容错解析流程
          return await _tolerantJsonInsert(db, item, jsonStr);
        }
      }

      if (decoded is List) {
        // JSON 数组：批量插入多条错题
        _ParseLog.log(' 检测到JSON数组，共 ${decoded.length} 条记录');
        int successCount = 0;
        for (int i = 0; i < decoded.length; i++) {
          final entry = decoded[i];
          _ParseLog.log(' 处理数组第 $i 项，类型: ${entry.runtimeType}');
          if (entry is Map<String, dynamic>) {
            try {
              await _insertErrorRecord(db, item, entry);
              successCount++;
              _ParseLog.log(' 第 $i 项插入成功');
            } catch (e) {
              _ParseLog.log(' 第 $i 项插入失败: $e');
            }
          } else {
            _ParseLog.log(' 第 $i 项不是 Map，跳过');
          }
        }
        _ParseLog.log(' 成功插入 $successCount/${decoded.length} 条记录');
        _ParseLog.log(' ========== _tryDirectJsonInsert 结束 ==========');
        await _ParseLog.flush();
        return successCount > 0;
      } else if (decoded is Map<String, dynamic>) {
        // 单个 JSON 对象
        _ParseLog.log(' 检测到单个JSON对象');
        await _insertErrorRecord(db, item, decoded);
        _ParseLog.log(' ========== _tryDirectJsonInsert 结束 ==========');
        await _ParseLog.flush();
        return true;
      } else {
        _ParseLog.log(' 解析结果既不是List也不是Map，类型: ${decoded.runtimeType}');
      }
      _ParseLog.log(' ========== _tryDirectJsonInsert 结束 ==========');
      await _ParseLog.flush();
      return false;
    } catch (e) {
      _ParseLog.log(' _tryDirectJsonInsert 异常: $e');
      await _ParseLog.flush();
      return false;
    }
  }

  /// 高容错 JSON 解析与插入
  /// 当标准 json.decode 失败时使用：先分割 JSON 对象，再逐对象容错解析键值对
  Future<bool> _tolerantJsonInsert(Database db, InboxItem item, String jsonStr) async {
    try {
      _ParseLog.log(' ========== _tolerantJsonInsert 开始 ==========');
      final trimmed = jsonStr.trim();
      _ParseLog.log(' 容错解析输入长度: ${trimmed.length}');
      _ParseLog.log(' 容错解析输入前200字符: ${trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed}');
      if (trimmed.startsWith('[')) {
        // JSON 数组：分割成独立对象后逐个容错解析
        final rawObjects = _splitJsonArrayObjects(trimmed);
        _ParseLog.log(' 容错解析：初始分割出 ${rawObjects.length} 个JSON对象');

        // 检测并拆分被合并的对象（基于已知属性名重复）
        final objects = _detectAndSplitMergedObjects(rawObjects);
        if (objects.length != rawObjects.length) {
          _ParseLog.log(' 属性边界检测后共 ${objects.length} 个对象');
        }

        for (int idx = 0; idx < objects.length; idx++) {
          final preview = objects[idx].length > 100 ? objects[idx].substring(0, 100) : objects[idx];
          _ParseLog.log(' 对象[$idx] 长度:${objects[idx].length} 预览:$preview');
        }
        int successCount = 0;
        for (int idx = 0; idx < objects.length; idx++) {
          final objStr = objects[idx];
          _ParseLog.log(' 正在容错解析对象[$idx]，长度:${objStr.length}');
          final map = _tolerantParseObject(objStr);
          _ParseLog.log(' 对象[$idx] 解析出 ${map.length} 个键值对，键: ${map.keys.toList()}');
          if (map.isNotEmpty) {
            try {
              await _insertErrorRecord(db, item, map);
              successCount++;
              _ParseLog.log(' 对象[$idx] 插入成功');
            } catch (e) {
              _ParseLog.log(' 对象[$idx] 插入失败: $e');
            }
          } else {
            _ParseLog.log(' 对象[$idx] 解析结果为空，跳过插入');
          }
        }
        _ParseLog.log(' 容错解析成功插入 $successCount/${objects.length} 条记录');
        _ParseLog.log(' ========== _tolerantJsonInsert 结束 ==========');
        await _ParseLog.flush();
        return successCount > 0;
      } else if (trimmed.startsWith('{')) {
        // 单个 JSON 对象
        _ParseLog.log(' 容错解析：单个JSON对象');
        final map = _tolerantParseObject(trimmed);
        _ParseLog.log(' 解析出 ${map.length} 个键值对，键: ${map.keys.toList()}');
        if (map.isNotEmpty) {
          await _insertErrorRecord(db, item, map);
          _ParseLog.log(' ========== _tolerantJsonInsert 结束 ==========');
          await _ParseLog.flush();
          return true;
        }
      } else {
        _ParseLog.log(' 容错解析：既不是数组也不是对象，开头字符: ${trimmed.isNotEmpty ? trimmed[0] : "空"}');
      }
      _ParseLog.log(' ========== _tolerantJsonInsert 结束 ==========');
      await _ParseLog.flush();
      return false;
    } catch (e) {
      _ParseLog.log(' 容错JSON解析失败: $e');
      await _ParseLog.flush();
      return false;
    }
  }

  /// 从混合文本中智能提取 JSON 部分
  /// 策略（按优先级）：
  ///   1. 属性锚定法：找到第一个 `errorId": "数字"` 的位置，向前找 `[`，向后找最后一个 `}`
  ///   2. 括号匹配法：查找所有 `[`，尝试括号匹配，验证提取结果
  ///   3. 回退到 JSON 对象提取
  String? _extractJsonFromContent(String content) {
    _ParseLog.log(' _extractJsonFromContent 开始，content 长度:${content.length}');
    // 去掉首尾可能的引号
    var trimmed = content.trim();
    final hadQuotes = trimmed.startsWith('"') && trimmed.endsWith('"');
    if (hadQuotes) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      _ParseLog.log(' 去掉首尾引号，剩余长度:${trimmed.length}');
    }

    // 策略1：属性锚定法 — 最可靠
    final anchored = _extractByPropertyAnchor(trimmed);
    if (anchored != null) {
      _ParseLog.log(' 属性锚定法成功，长度:${anchored.length}');
      return anchored;
    }

    // 策略2：括号匹配法
    final bestJsonArray = _findBestJsonArray(trimmed);
    if (bestJsonArray != null) {
      _ParseLog.log(' 括号匹配法成功，长度:${bestJsonArray.length}');
      return bestJsonArray;
    }

    // 策略3：回退到 JSON 对象
    final bestJsonObject = _findBestJsonObject(trimmed);
    if (bestJsonObject != null) {
      _ParseLog.log(' 回退到JSON对象，长度:${bestJsonObject.length}');
      return bestJsonObject;
    }

    _ParseLog.log(' 未找到可解析的JSON内容');
    return null;
  }

  /// 属性锚定法：利用已知属性名定位真正的 JSON 数据区域
  /// 找到第一个 `"errorId": "数字"` 的位置，作为数据开始的标志
  /// 向前找到 `[`（数组开始），向后找到最后的 `}`（数组结束）
  String? _extractByPropertyAnchor(String text) {
    // 使用正则匹配 errorId": "纯数字" 模式（避免匹配模板中的 errorId": "错误编号"）
    final pattern = RegExp(r'"errorId"\s*:\s*"\d+"');
    final firstMatch = pattern.firstMatch(text);
    if (firstMatch == null) return null;

    final firstErrorIdPos = firstMatch.start;
    _ParseLog.log(' 属性锚定：第一个 errorId":数字 在位置 $firstErrorIdPos');

    // 向前找 [ — 从 firstErrorIdPos 往前搜索
    int arrayStart = text.lastIndexOf('[', firstErrorIdPos);
    if (arrayStart < 0) {
      // 如果前面没有 [，试试找第一个 {
      arrayStart = text.lastIndexOf('{', firstErrorIdPos);
      if (arrayStart < 0) return null;
    }
    _ParseLog.log(' 属性锚定：向前找到 [ 位置 $arrayStart');

    // 向后找最后一个 } 
    int lastBrace = text.lastIndexOf('}');
    if (lastBrace <= firstErrorIdPos) return null;
    _ParseLog.log(' 属性锚定：向后找到 } 位置 $lastBrace');

    String jsonStr;
    if (text[arrayStart] == '[') {
      jsonStr = text.substring(arrayStart, lastBrace + 1) + ']';
      _ParseLog.log(' 属性锚定：补上了 ]');
    } else {
      jsonStr = text.substring(arrayStart, lastBrace + 1);
    }

    // 验证：提取的内容应该包含多个 errorId（多个对象）
    final errorIdCount = pattern.allMatches(jsonStr).length;
    _ParseLog.log(' 属性锚定：提取内容包含 $errorIdCount 个 errorId');

    if (errorIdCount >= 1) {
      return jsonStr;
    }
    return null;
  }

  /// 在文本中查找最佳 JSON 数组
  /// 遍历所有 `[` 位置，验证后面是否为有效的 JSON 数组
  String? _findBestJsonArray(String text) {
    int searchFrom = 0;
    String? bestCandidate;
    int bestLength = 0;

    while (searchFrom < text.length) {
      final arrayStart = text.indexOf('[', searchFrom);
      if (arrayStart < 0) break;

      // 检查 [ 后面是否紧跟 JSON 对象特征：跳过空白后应该是 { 或 [
      int checkPos = arrayStart + 1;
      while (checkPos < text.length && ' \t\n\r'.contains(text[checkPos])) {
        checkPos++;
      }

      if (checkPos >= text.length) break;

      // 数组内第一个有效字符应该是 { 或 [ 或 "（字符串）或 数字/布尔/null
      final nextChar = text[checkPos];
      final isArrayLike = nextChar == '{' || nextChar == '[' || nextChar == '"';
      final isValueLike = nextChar == 't' || nextChar == 'f' || nextChar == 'n' ||
          (nextChar.codeUnitAt(0) >= 48 && nextChar.codeUnitAt(0) <= 57); // 数字

      if (!isArrayLike && !isValueLike) {
        searchFrom = arrayStart + 1;
        continue;
      }

      // 尝试括号匹配
      final arrayEnd = _findMatchingBracket(text, arrayStart, '[', ']');
      if (arrayEnd > arrayStart) {
        final candidate = text.substring(arrayStart, arrayEnd + 1);

        // 验证：提取的内容应该包含至少一个 {（JSON 对象特征）
        if (candidate.contains('{')) {
          // 检查括号是否大致平衡
          final inner = candidate.substring(1, candidate.length - 1);
          final braceCount = _countBraces(inner);
          _ParseLog.log(' 候选数组位置:$arrayStart, 长度:${candidate.length}, {计数:${braceCount}');

          if (braceCount > 0) {
            // 优先选择包含最多 JSON 对象的候选
            if (candidate.length > bestLength) {
              bestCandidate = candidate;
              bestLength = candidate.length;
            }
          }
        }
      }

      searchFrom = arrayStart + 1;
    }

    return bestCandidate;
  }

  /// 在文本中查找最佳 JSON 对象
  String? _findBestJsonObject(String text) {
    int searchFrom = 0;
    String? bestCandidate;
    int bestLength = 0;

    while (searchFrom < text.length) {
      final objectStart = text.indexOf('{', searchFrom);
      if (objectStart < 0) break;

      // 检查 { 后面是否紧跟 "（JSON 键名特征）
      int checkPos = objectStart + 1;
      while (checkPos < text.length && ' \t\n\r'.contains(text[checkPos])) {
        checkPos++;
      }

      if (checkPos >= text.length) break;

      final nextChar = text[checkPos];
      // JSON 对象的第一个字符应该是 "（键名）
      if (nextChar != '"') {
        searchFrom = objectStart + 1;
        continue;
      }

      final objectEnd = _findMatchingBracket(text, objectStart, '{', '}');
      if (objectEnd > objectStart) {
        final candidate = text.substring(objectStart, objectEnd + 1);
        // 检查是否包含 ":（键值对特征）
        if (candidate.contains('":') || candidate.contains('" :')) {
          if (candidate.length > bestLength) {
            bestCandidate = candidate;
            bestLength = candidate.length;
          }
        }
      }

      searchFrom = objectStart + 1;
    }

    return bestCandidate;
  }

  /// 简单计算字符串中未转义的 { 和 } 的数量差
  /// 返回 > 0 表示有未闭合的 {，< 0 表示有额外的 }
  int _countBraces(String text) {
    int count = 0;
    bool inString = false;
    for (int i = 0; i < text.length; i++) {
      if (inString) {
        if (text[i] == '\\' && i + 1 < text.length) {
          i++;
        } else if (text[i] == '"') {
          inString = false;
        }
      } else {
        if (text[i] == '"') {
          inString = true;
        } else if (text[i] == '{') {
          count++;
        } else if (text[i] == '}') {
          count--;
        }
      }
    }
    return count;
  }

  /// 找到匹配的括号位置（考虑字符串内的括号）
  int _findMatchingBracket(String text, int start, String open, String close) {
    int depth = 0;
    bool inString = false;
    for (int i = start; i < text.length; i++) {
      if (inString) {
        if (text[i] == '\\' && i + 1 < text.length) {
          i++; // 跳过转义字符
        } else if (text[i] == '"') {
          inString = false;
        }
      } else {
        if (text[i] == '"') {
          inString = true;
        } else if (text[i] == open[0]) {
          depth++;
        } else if (text[i] == close[0]) {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1; // 未找到匹配的括号
  }

  /// 将 JSON 数组内容分割成独立的 JSON 对象字符串
  /// 策略：找到每个顶层 } 的位置，从上一个分隔点到该 } 位置为一个对象
  /// 使用 depth 追踪，只在 depth==0 时的 } 才是顶层对象结束
  List<String> _splitJsonArrayObjects(String arrayStr) {
    _ParseLog.log(' _splitJsonArrayObjects 开始，输入长度:${arrayStr.length}');
    final result = <String>[];
    final trimmed = arrayStr.trim();

    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
      _ParseLog.log(' 输入不以 [ 开头或不以 ] 结尾，无法分割');
      return result;
    }

    // 去掉外层 []
    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    _ParseLog.log(' 去掉外层[]后 inner 长度:${inner.length}');
    if (inner.isEmpty) {
      _ParseLog.log(' inner 为空，无对象');
      return result;
    }

    // 策略：逐字符扫描，追踪 depth 和 inString
    // 只在 depth==0 且 inString==false 时遇到 } ，认为是一个对象的结束
    int depth = 0;
    bool inString = false;
    int lastSplit = 0; // 上一个分割点
    final current = StringBuffer();

    for (int i = 0; i < inner.length; i++) {
      final ch = inner[i];

      if (inString) {
        if (ch == '\\' && i + 1 < inner.length) {
          current.write(ch);
          current.write(inner[i + 1]);
          i++;
        } else if (ch == '"') {
          // 简单 toggle：遇到 " 就切换 inString
          // 这样做的原因：我们只关心对象边界（depth==0 时的逗号/大括号），
          // 不需要正确解析字符串值内容
          inString = false;
          current.write(ch);
        } else {
          current.write(ch);
        }
      } else {
        if (ch == '"') {
          inString = true;
          current.write(ch);
        } else if (ch == '{') {
          depth++;
          current.write(ch);
        } else if (ch == '}') {
          depth--;
          current.write(ch);
          // depth 回到 0 表示一个完整的顶层对象结束
          if (depth == 0) {
            final objStr = current.toString().trim();
            if (objStr.isNotEmpty) {
              result.add(objStr);
            }
            current.clear();
          }
        } else if (ch == ',' && depth == 0) {
          // depth==0 时的逗号是对象之间的分隔符，跳过即可
          // （对象已经在 } 处被收集了）
        } else {
          current.write(ch);
        }
      }
    }

    // 处理可能的尾部残余
    if (current.isNotEmpty) {
      final objStr = current.toString().trim();
      if (objStr.startsWith('{') && objStr.isNotEmpty) {
        result.add(objStr);
      }
    }

    _ParseLog.log(' _splitJsonArrayObjects 结束，共分割出 ${result.length} 个对象');
    return result;
  }

  /// 已知错误本对象的全部属性名（用于识别对象边界）
  static const List<String> _knownErrorRecordProperties = [
    'correctAnswer', 'errorId', 'eids', 'progress', 'question',
    'wrongAnswer', 'wrongWhere', 'whyWrong', 'howPrevent', 'notes',
    'images', 'tid', 'qid', 'gradeMemo', 'correction', 'kid',
    'unitNumber', 'lessonNumber', 'cid',
  ];

  /// 检测并拆分被合并的多个对象
  /// 当 _splitJsonArrayObjects 返回少量对象（尤其只有1个）时，
  /// 检查每个对象是否包含重复的已知属性名。若发现重复，
  /// 说明多个对象被错误合并，需要按属性重复位置重新拆分。
  List<String> _detectAndSplitMergedObjects(List<String> objects) {
    final result = <String>[];
    for (final objStr in objects) {
      final splitResults = _splitByPropertyBoundaries(objStr);
      if (splitResults.length > 1) {
        _ParseLog.log(' 检测到合并对象，拆分为 ${splitResults.length} 个');
        result.addAll(splitResults);
      } else {
        result.add(objStr);
      }
    }
    return result;
  }

  /// 基于已知属性名重复位置拆分合并的对象
  /// 策略：
  ///   1. 扫描文本中所有已知属性名的出现位置
  ///   2. 对出现多次的属性，其重复位置即为对象边界候选
  ///   3. 在候选边界附近寻找 `}","` 或 `},{"` 等分隔符
  ///   4. 若无显式分隔符，寻找前一个 `}` 到后一个 `{` 之间的范围作为边界
  List<String> _splitByPropertyBoundaries(String text) {
    // 步骤1：收集所有已知属性名的出现位置
    final occurrences = <String, List<int>>{};
    for (final prop in _knownErrorRecordProperties) {
      final pattern = '"$prop"';
      int pos = 0;
      while (true) {
        final idx = text.indexOf(pattern, pos);
        if (idx < 0) break;
        occurrences.putIfAbsent(prop, () => []).add(idx);
        pos = idx + 1;
      }
    }

    // 步骤2：找出出现次数 > 1 的属性（说明有多个对象）
    final duplicateProps = occurrences.entries
        .where((e) => e.value.length > 1)
        .toList();

    if (duplicateProps.isEmpty) {
      return [text]; // 无重复属性，无需拆分
    }

    // 步骤3：使用第一个出现多次的属性来确定边界
    // 优先使用 errorId（最稳定的对象标识符）
    var chosenProp = duplicateProps.firstWhere(
      (e) => e.key == 'errorId',
      orElse: () => duplicateProps.first,
    );

    final positions = chosenProp.value;
    _ParseLog.log(' 属性 "${chosenProp.key}" 出现 ${positions.length} 次，位置: $positions');

    // 步骤4：在相邻出现位置之间寻找对象边界
    final boundaries = <int>[]; // 每个边界是前一个对象结束的位置（不含）
    for (int i = 0; i < positions.length - 1; i++) {
      final startOfNextObj = positions[i + 1];
      // 在 [positions[i], startOfNextObj) 范围内找最合适的分隔点
      final splitPoint = _findObjectSeparator(text, positions[i], startOfNextObj);
      if (splitPoint > 0) {
        boundaries.add(splitPoint);
      }
    }

    if (boundaries.isEmpty) {
      return [text]; // 无法找到边界
    }

    // 步骤5：按边界拆分
    final results = <String>[];
    int start = 0;
    for (final end in boundaries) {
      final segment = text.substring(start, end).trim();
      if (segment.isNotEmpty && segment.startsWith('{')) {
        results.add(segment);
      }
      start = end;
    }
    // 最后一段
    final lastSegment = text.substring(start).trim();
    if (lastSegment.isNotEmpty && lastSegment.startsWith('{')) {
      results.add(lastSegment);
    }

    return results.isNotEmpty ? results : [text];
  }

  /// 在指定范围内寻找对象分隔符
  /// 优先找 `}","{` 或 `}, {` 或 `}{` 等模式
  /// 若无显式分隔符，找前一个 `}` 的位置
  int _findObjectSeparator(String text, int searchStart, int searchEnd) {
    // 在 searchStart+10（跳过第一个属性本身）到 searchEnd 之间搜索
    final from = searchStart + 10;
    final to = searchEnd;

    // 策略1：寻找 `}","{` 或 `},"{` 或 `}{` 模式
    for (int i = from; i < to - 2; i++) {
      // 检查 "},{ 模式
      if (i + 3 < to && text.substring(i, i + 3) == '},{') {
        return i + 1; // 在 } 后分割
      }
      // 检查 "}, { 模式
      if (i + 4 < to && text.substring(i, i + 4) == '}, {') {
        return i + 1; // 在 } 后分割
      }
      // 检查 "}{ 模式（无逗号分隔）
      if (i + 2 < to && text.substring(i, i + 2) == '}{') {
        return i + 1; // 在 } 后分割
      }
    }

    // 策略2：找 searchEnd 之前的最后一个 }
    for (int i = searchEnd - 1; i > from; i--) {
      if (text[i] == '}') {
        // 验证这个 } 后面紧跟逗号或 { 或 ] 或 文本结束
        int j = i + 1;
        while (j < text.length && ' \t\n\r'.contains(text[j])) j++;
        if (j >= text.length || ',]{'.contains(text[j])) {
          return i + 1;
        }
      }
    }

    return -1; // 未找到
  }

  /// 高容错 JSON 对象解析
  /// 逐字符扫描提取 "key": value 键值对
  /// 即使 JSON 格式不完整（缺少闭合符号、引号未转义等），也能尽可能提取属性
  Map<String, dynamic> _tolerantParseObject(String objStr) {
    _ParseLog.log(' _tolerantParseObject 开始，输入长度:${objStr.length}');
    final result = <String, dynamic>{};
    int i = 0;

    while (i < objStr.length) {
      // 跳过空白和分隔符
      while (i < objStr.length && ' \t\n\r,{}'.contains(objStr[i])) {
        i++;
      }
      if (i >= objStr.length) break;

      // 查找键名：必须以 " 开头
      if (objStr[i] != '"') {
        // 跳过非键名内容
        i++;
        continue;
      }

      // 读取键名
      final keyStart = i + 1;
      var keyEnd = keyStart;
      while (keyEnd < objStr.length && objStr[keyEnd] != '"') {
        keyEnd++;
      }
      if (keyEnd >= objStr.length) {
        _ParseLog.log(' 键名未闭合，终止解析');
        break;
      }

      final key = objStr.substring(keyStart, keyEnd);
      i = keyEnd + 1;

      // 跳过空白和冒号
      while (i < objStr.length && ' \t\n\r'.contains(objStr[i])) {
        i++;
      }
      if (i >= objStr.length || objStr[i] != ':') {
        _ParseLog.log(' 键 "$key" 后未找到冒号，跳过');
        continue;
      }
      i++; // 跳过冒号

      // 跳过空白
      while (i < objStr.length && ' \t\n\r'.contains(objStr[i])) {
        i++;
      }
      if (i >= objStr.length) {
        _ParseLog.log(' 键 "$key" 后无值，终止解析');
        break;
      }

      // 读取值
      dynamic value;
      final valueStartPos = i;

      if (objStr[i] == '"') {
        // 字符串值
        i++;
        final sb = StringBuffer();
        while (i < objStr.length) {
          if (objStr[i] == '\\' && i + 1 < objStr.length) {
            // 转义字符
            final next = objStr[i + 1];
            if (next == '"') {
              sb.write('"');
            } else if (next == '\\') {
              sb.write('\\');
            } else if (next == 'n') {
              sb.write('\n');
            } else if (next == 't') {
              sb.write('\t');
            } else if (next == 'r') {
              sb.write('\r');
            } else if (next == 'b') {
              sb.write('\b');
            } else if (next == 'f') {
              sb.write('\f');
            } else {
              sb.write(next);
            }
            i += 2;
          } else if (objStr[i] == '"') {
            // 智能判断：是字符串结束还是未转义的内部双引号
            int j = i + 1;
            while (j < objStr.length && ' \t\n\r'.contains(objStr[j])) {
              j++;
            }
            if (j >= objStr.length || ',}]'.contains(objStr[j])) {
              // 后面跟着分隔符或结束符，确认为字符串结束
              i++;
              break;
            } else {
              // 未转义的双引号（如 "我"），当作字符串内容保留
              sb.write('"');
              i++;
            }
          } else {
            sb.write(objStr[i]);
            i++;
          }
        }
        value = sb.toString();
        final valPreview = value.length > 50 ? '${value.substring(0, 50)}...' : value;
        _ParseLog.log(' 键 "$key" = 字符串(长度${value.length}): $valPreview');
      } else if (objStr[i] == '[') {
        // 数组值
        final valueStartLocal = i;
        var depth = 1;
        i++;
        while (i < objStr.length && depth > 0) {
          if (objStr[i] == '\\' && i + 1 < objStr.length) {
            i += 2;
            continue;
          }
          if (objStr[i] == '"') {
            // 跳过字符串
            i++;
            while (i < objStr.length) {
              if (objStr[i] == '\\' && i + 1 < objStr.length) {
                i += 2;
              } else if (objStr[i] == '"') {
                i++;
                break;
              } else {
                i++;
              }
            }
            continue;
          }
          if (objStr[i] == '[') depth++;
          else if (objStr[i] == ']') depth--;
          if (depth > 0) i++;
        }
        if (i < objStr.length) i++; // 跳过 ]

        final arrayStr = objStr.substring(valueStartLocal, i);
        try {
          value = json.decode(arrayStr);
          _ParseLog.log(' 键 "$key" = 数组(长度${(value as List).length})');
        } catch (_) {
          // 简单分割数组元素
          final inner = arrayStr.substring(1, arrayStr.length - 1);
          value = _splitArrayElements(inner)
              .map((s) {
                final trimmed = s.trim();
                if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
                  return trimmed.substring(1, trimmed.length - 1);
                }
                return trimmed;
              })
              .where((s) => s.isNotEmpty)
              .toList();
          _ParseLog.log(' 键 "$key" = 数组(简单分割，长度${(value as List).length})');
        }
      } else if (objStr[i] == '{') {
        // 嵌套对象（简单处理：作为字符串保留）
        final valueStartLocal = i;
        var depth = 1;
        i++;
        while (i < objStr.length && depth > 0) {
          if (objStr[i] == '\\' && i + 1 < objStr.length) {
            i += 2;
            continue;
          }
          if (objStr[i] == '"') {
            i++;
            while (i < objStr.length) {
              if (objStr[i] == '\\' && i + 1 < objStr.length) {
                i += 2;
              } else if (objStr[i] == '"') {
                i++;
                break;
              } else {
                i++;
              }
            }
            continue;
          }
          if (objStr[i] == '{') depth++;
          else if (objStr[i] == '}') depth--;
          if (depth > 0) i++;
        }
        if (i < objStr.length) i++; // 跳过 }
        value = objStr.substring(valueStartLocal, i);
        _ParseLog.log(' 键 "$key" = 嵌套对象(长度${value.toString().length})');
      } else {
        // 数字、布尔、null
        final valueStartLocal = i;
        while (i < objStr.length && !' \t\n\r,}'.contains(objStr[i])) {
          i++;
        }
        final raw = objStr.substring(valueStartLocal, i);
        if (raw == 'true') {
          value = true;
        } else if (raw == 'false') {
          value = false;
        } else if (raw == 'null') {
          value = null;
        } else {
          final numValue = num.tryParse(raw);
          value = numValue ?? raw;
        }
        _ParseLog.log(' 键 "$key" = $value');
      }

      result[key] = value;
    }

    _ParseLog.log(' _tolerantParseObject 结束，共解析 ${result.length} 个键值对: ${result.keys.toList()}');
    return result;
  }

  /// 简单分割数组元素（考虑嵌套和字符串）
  List<String> _splitArrayElements(String inner) {
    final result = <String>[];
    int depth = 0;
    bool inString = false;
    final current = StringBuffer();

    for (int i = 0; i < inner.length; i++) {
      final ch = inner[i];
      if (ch == '\\' && i + 1 < inner.length) {
        current.write(ch);
        current.write(inner[i + 1]);
        i++;
        continue;
      }
      if (inString) {
        if (ch == '"') inString = false;
        current.write(ch);
      } else {
        if (ch == '"') {
          inString = true;
          current.write(ch);
        } else if (ch == '[' || ch == '{') {
          depth++;
          current.write(ch);
        } else if (ch == ']' || ch == '}') {
          depth--;
          current.write(ch);
        } else if (ch == ',' && depth == 0) {
          result.add(current.toString());
          current.clear();
        } else {
          current.write(ch);
        }
      }
    }

    if (current.isNotEmpty) {
      result.add(current.toString());
    }

    return result;
  }

  // ========== 核心方法：通过 LLM 将 inbox item 内容解析为目标模块数据结构 ==========

  /// 根据目标分类，调用 LLM 解析 content 为结构化数据
  Future<Map<String, dynamic>> parseContentForCategory(
    String content,
    String title,
    String category,
  ) async {
    final schemaPrompt = _getSchemaPrompt(category);

    final systemPrompt =
        '''你是一位教育数据解析专家。请将用户收藏的文档内容解析为结构化的学习目标数据。

=== 分类定义 ===
$_getCategoryDefinition(category)

=== 目标数据结构 ===
$schemaPrompt

=== 待解析内容 ===
标题：$title
正文：
$content

=== 解析要求 ===
1. 仔细阅读全部内容，提取所有可能的结构化信息
2. 严格按照 JSON 格式返回，不要添加任何其他文字
3. 无法确定的字段返回 null 或空字符串 ""
4. 保留原文中的关键信息（如公式、代码、特殊符号等）
5. 对于选择题，必须识别出 A/B/C/D 选项
6. 对于错题，必须区分"题目"、"我的答案"、"正确答案"、"错误分析"
7. 对于知识点，要提炼核心概念、关键定义、示例说明
8. content 字段的值用双引号包裹，注意转义换行符和引号

请只回复 JSON 对象，格式如下：
{
  "field1": "value1",
  "field2": "value2",
  ...
}''';

    final response = await _llmService.generateResponse(systemPrompt);

    if (response['success'] != true || response['response'] == null) {
      throw Exception('LLM parsing failed');
    }

    // 从 LLM 响应中提取 JSON
    final jsonStr = response['response']!;
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);

    if (jsonMatch == null) {
      throw Exception('No JSON found in response');
    }

    try {
      return json.decode(jsonMatch.group(0)!);
    } catch (e) {
      print('[ParseContent] JSON 解析失败: $e');
      print('[ParseContent] 原始响应: $jsonStr');
      throw Exception('Invalid JSON from LLM');
    }
  }

  /// 获取目标分类的 JSON schema 提示词
  String _getSchemaPrompt(String category) {
    switch (category) {
      case '错题本':
        return '''【错题本数据结构】
{
  "content": "错题核心描述（综合题干和错误背景）",
  "correctAnswer": "正确答案/标准答案",
  "subject": "科目（如'语文''文言文'）",
  "lesson": "课程/课次信息",
  "errorType": "错误类型（如'计算错误''概念混淆''审题不清'）",
  "exerciseTag": "关联的习题编号或标签",
  "knowledgeTag": "关联的知识点",
  "progress": "待订正",
  "question": "完整题目内容",
  "wrongAnswer": "用户的错误答案",
  "wrongWhere": "错在哪一步或哪个位置",
  "whyWrong": "错因分析（为什么错了）",
  "howPrevent": "预防建议/改进措施",
  "notes": "备注或解题技巧总结"
}''';

      case '习题集':
        return '''【习题集数据结构】
注意：一篇文档可能包含多道题目，请将所有题目放入 exercises 数组中。

{
  "exercises": [
    {
      "question": "习题题目（不含选项）",
      "options": "选项内容（如有选择题，格式为'A. 选项A\\nB. 选项B\\nC. 选项C\\nD. 选项D'）",
      "correctAnswer": "正确答案",
      "explanation": "详细解析/解题思路",
      "category": "分类（如'文言文''古诗词''现代文阅读'）",
      "difficulty": 1,
      "lessonUnit": "课时单元标识",
      "knowledgeTag": "关联知识点标签",
      "examPaper": "所属试卷名称或编号",
      "answerKey": "参考答案"
    },
    ...
  ]
}

对于每道题目：
- question 字段是完整的题目描述
- options 字段对于选择题是 A/B/C/D 选项数组，填空题为 null
- 如果文档只有1道题，exercises 数组只包含1个对象
- 如果有多个题目，每个题目都要完整提取
''';

      case '作品集':
        return '''【作品集数据结构】
{
  "title": "作品标题",
  "type": "作品类型（如'作文''翻译''演讲稿''诗歌''散文'）",
  "isOriginal": false,
  "knowledgeTag": "关联知识点",
  "lessonUnit": "课时单元",
  "aiReview": "AI 评语/分析报告"
}
注：作品正文保留在 filePath 指向的 HTML 文件中，数据库只存元数据。''';

      case '知识点':
        return '''【知识点数据结构】
{
  "title": "知识点的核心概念名称",
  "content": "知识点的详细内容（定义、规则、方法论，可适当精简但保留核心）",
  "category": "知识类别（如'语法''文化''历史''学习方法'）",
  "lessonUnit": "所属课时单元",
  "difficulty": 1,
  "knowledgeTag": "关键词/标签"
}''';

      default:
        throw Exception('Unknown category: $category');
    }
  }

  /// 获取分类的定义说明（用于 LLM prompt）
  String _getCategoryDefinition(String category) {
    switch (category) {
      case '错题本':
        return '''错题本：在习题的基础上，额外包含答卷/批改痕迹/错误分析/技巧总结等订正信息。核心特征是"有错且有分析与修正"。需要识别题目、错误答案、正确答案、错因分析等内容。''';
      case '习题集':
        return '''习题集：仅包含题目和答案，没有答卷、批阅记录、错误分析等内容。通常是原始练习题、试卷、思考题。需要识别题目、选项（如有）、参考答案等。''';
      case '作品集':
        return '''作品集：范文、作文、原创文章、名人名篇等作品性文本。不是练习题，也不是学习笔记。需要识别作品类型、标题、是否原创等。''';
      case '知识点':
        return '''知识点：文化知识、历史地理知识介绍、语言规则讲解、学习方法心得、笔记摘要等知识类内容。需要提炼核心概念、定义、示例等。''';
      default:
        return '未知分类';
    }
  }

  // ========== 各模块的具体插入方法 ==========

  /// 判断该 JSON 对象是否表示一个"无错误"的题目
  /// 特征：
  ///   1. correctAnswer 与 wrongAnswer 相同（答案与答题一致）
  ///   2. wrongWhere / whyWrong 为 "无" 或空
  ///   3. wrongAnswer 为空
  bool _isNoErrorRecord(Map<String, dynamic> data) {
    final correctAnswer = data['correctAnswer']?.toString().trim() ?? '';
    final wrongAnswer = data['wrongAnswer']?.toString().trim() ?? '';
    final wrongWhere = data['wrongWhere']?.toString().trim() ?? '';
    final whyWrong = data['whyWrong']?.toString().trim() ?? '';
    final notes = data['notes']?.toString().trim() ?? '';

    // 条件1：答案与答题一致（无错误）
    if (correctAnswer.isNotEmpty &&
        wrongAnswer.isNotEmpty &&
        correctAnswer == wrongAnswer) {
      return true;
    }

    // 条件2：wrongWhere 或 whyWrong 为 "无"
    if (wrongWhere == '无' || whyWrong == '无') {
      return true;
    }

    // 条件3：wrongWhere / whyWrong / wrongAnswer 全为空
    if (wrongWhere.isEmpty && whyWrong.isEmpty && wrongAnswer.isEmpty) {
      return true;
    }

    // 条件4：notes 字段标记为"情感辨析正确"或"文本常识理解正确"等无错提示
    if (notes.contains('正确') || notes.contains('无错') || notes.contains('无误')) {
      return true;
    }

    return false;
  }

  Future<void> _insertErrorRecord(
    Database db,
    InboxItem item,
    Map<String, dynamic> data,
  ) async {
    // 过滤无错误的题目
    if (_isNoErrorRecord(data)) {
      _ParseLog.log(' 跳过无错误题目: correctAnswer=${data['correctAnswer']}, wrongAnswer=${data['wrongAnswer']}, wrongWhere=${data['wrongWhere']}, whyWrong=${data['whyWrong']}, notes=${data['notes']}');
      return;
    }

    final dao = ErrorRecordDao(db);
    final nextNum = await dao.nextErrorIdNumber();

    // 解析 eids 字段：支持 List<String> 格式（如 ["2.2", "1.1"]）
    List<String> eids = [];
    final eidsData = data['eids'];
    if (eidsData is List) {
      eids = eidsData.map((e) => e.toString()).toList();
    } else if (eidsData is String && eidsData.isNotEmpty) {
      eids = [eidsData];
    }
    // 兼容旧格式：如果 eids 为空但有 errorType，使用 errorType
    if (eids.isEmpty && data['errorType'] is String) {
      eids = [data['errorType'] as String];
    }

    // 解析 images 字段：支持 List<String> 格式
    String? images;
    final imagesData = data['images'];
    if (imagesData is List) {
      images = json.encode(imagesData);
    } else if (imagesData is String) {
      images = imagesData;
    }

    final record = ErrorRecord(
      errorId: 'T$nextNum',
      correctAnswer: data['correctAnswer'] as String?,
      eids: eids,
      progress: data['progress'] ?? '待订正',
      question: data['question'] as String?,
      wrongAnswer: data['wrongAnswer'] as String?,
      wrongWhere: data['wrongWhere'] as String?,
      whyWrong: data['whyWrong'] as String?,
      howPrevent: data['howPrevent'] as String?,
      notes: data['notes'] as String?,
      images: images,
      createdAt: item.createdAt,
      lang: 'cn',
      tid: data['tid'] as String?,
      qid: data['qid'] as String?,
      gradeMemo: data['gradeMemo'] as String?,
      correction: data['correction'] as String?,
      kid: data['kid'] as String?,
      unitNumber: data['unitNumber'] as String?,
      lessonNumber: data['lessonNumber'] as String?,
      cid: data['cid'] as String?,
    );

    await dao.insert(record);
    _ParseLog.log(' 错题本条目已创建: T$nextNum');
  }

  Future<void> _insertExercise(
    Database db,
    InboxItem item,
    Map<String, dynamic> data,
  ) async {
    final testDao = TestDao(db);
    final questionDao = QuestionDao(db);
    final nextNum = await testDao.nextTidNumber();
    final tid = 'T$nextNum';

    // 获取文档中的图片路径
    List<String> images = [];
    if (item.filePath.isNotEmpty) {
      final dir = Directory(item.filePath);
      if (await dir.exists()) {
        final files = await dir
            .list()
            .where(
              (entity) =>
                  entity.path.endsWith('.jpg') ||
                  entity.path.endsWith('.jpeg') ||
                  entity.path.endsWith('.png'),
            )
            .toList();
        images = files.map((f) => f.path).toList();
      }
    }

    // 先插入 Test 记录
    await testDao.insert(
      Test(
        tid: tid,
        title: data['title'] ?? item.title ?? '收件箱导入',
        lessonUnitList: [],
        kids: [],
        images: images,
        status: '未开始',
        createdAt: item.createdAt,
        lang: 'cn',
      ),
    );

    // 再插入对应的 Question 记录
    await questionDao.insert(
      Question(
        tid: tid,
        question: data['question'] ?? '',
        correctAnswer: data['correctAnswer'] as String?,
        explanation: data['explanation'] as String?,
        progress: '未答题',
        kid: null,
        unitNumber: null,
        lessonNumber: null,
        createdAt: item.createdAt,
        lang: 'cn',
        contentPath: item.filePath.isNotEmpty ? item.filePath : null,
      ),
    );

    _ParseLog.log(' 习题集条目已创建: $tid');
  }

  Future<void> _insertPortfolioItem(
    Database db,
    InboxItem item,
    Map<String, dynamic> data,
  ) async {
    final dao = PortfolioDao(db);

    final portfolio = PortfolioItem(
      title: data['title'] ?? item.title,
      contentPath: item.filePath,
      isOriginal: data['isOriginal'] as bool? ?? false,
      aiReview: data['aiReview'] as String?,
      createdAt: item.createdAt,
      lang: 'cn',
      brief: data['brief'] as String?,
      kid: data['kid'] as String?,
      unitNumber: data['unitNumber'] as String?,
      lessonNumber: data['lessonNumber'] as String?,
    );

    await dao.insert(portfolio);
    _ParseLog.log(' 作品集条目已创建');
  }

  Future<void> _insertKnowledgePoint(
    Database db,
    InboxItem item,
    Map<String, dynamic> data,
  ) async {
    final dao = KnowledgePointDao(db);

    final point = KnowledgePoint(
      title: data['title'] ?? item.title,
      contentPath: item.filePath,
      createdAt: item.createdAt,
      lang: 'cn',
      cid: data['cid'] as String? ?? '',
      unitNumber: data['unitNumber'] as String?,
      lessonNumber: data['lessonNumber'] as String?,
      brief: data['brief'] as String?,
      knowledgeTag: data['knowledgeTag'] as String?,
    );

    await dao.insert(point);
    _ParseLog.log(' 知识点条目已创建');
  }

  // ========== 降级策略：LLM 失败时的简单插入 ==========

  Future<bool> _fallbackInsertModuleTable(InboxItem item) async {
    final db = await _dbHelper.database;

    switch (item.category) {
      case '错题本':
        final dao = ErrorRecordDao(db);
        final nextNum = await dao.nextErrorIdNumber();
        await dao.insert(
          ErrorRecord(
            errorId: 'T$nextNum',
            wrongWhere: item.title,
            progress: '待订正',
            createdAt: item.createdAt,
            lang: 'cn',
          ),
        );
        print('[Fallback] 错题本条目已创建（仅标题）: T$nextNum');
        return true;

      case '习题集':
        final testDao = TestDao(db);
        final questionDao = QuestionDao(db);
        final nextNum = await testDao.nextTidNumber();
        final tid = 'T$nextNum';

        // 获取文档中的图片路径
        List<String> images = [];
        if (item.filePath.isNotEmpty) {
          final dir = Directory(item.filePath);
          if (await dir.exists()) {
            final files = await dir
                .list()
                .where(
                  (entity) =>
                      entity.path.endsWith('.jpg') ||
                      entity.path.endsWith('.jpeg') ||
                      entity.path.endsWith('.png'),
                )
                .toList();
            images = files.map((f) => f.path).toList();
          }
        }

        await testDao.insert(
          Test(
            tid: tid,
            title: item.title,
            lessonUnitList: [],
            kids: [],
            images: images,
            status: '未开始',
            createdAt: item.createdAt,
            lang: 'cn',
          ),
        );

        await questionDao.insert(
          Question(
            tid: tid,
            question: item.title,
            correctAnswer: null,
            explanation: null,
            progress: '未答题',
            kid: null,
            unitNumber: null,
            lessonNumber: null,
            createdAt: item.createdAt,
            lang: 'cn',
            contentPath: item.filePath.isNotEmpty ? item.filePath : null,
          ),
        );
        print('[Fallback] 习题集条目已创建（仅标题）');
        return true;

      case '作品集':
        final dao = PortfolioDao(db);
        await dao.insert(
          PortfolioItem(
            title: item.title,
            contentPath: item.filePath,
            isOriginal: false,
            createdAt: item.createdAt,
            lang: 'cn',
          ),
        );
        print('[Fallback] 作品集条目已创建（仅标题）');
        return true;

      case '知识点':
        final dao = KnowledgePointDao(db);
        await dao.insert(
          KnowledgePoint(
            title: item.title,
            contentPath: item.filePath,
            createdAt: item.createdAt,
            lang: 'cn',
            cid: '',
          ),
        );
        print('[Fallback] 知识点条目已创建');
        return true;

      default:
        print('[Fallback] 未知分类: ${item.category}');
        return false;
    }
  }

  // 创建处理中的剪贴板条目
  Future<InboxItem> createPendingClipboardItem(String url) async {
    final source = _identifySource(url);

    final allItems = await getAllInboxItems();
    int clipboardCount = 1;
    for (final item in allItems) {
      if (item.title.startsWith('来自粘贴板')) {
        clipboardCount++;
      }
    }
    final title = '来自粘贴板$clipboardCount';

    // 先创建最终保存目录
    final appDocDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomString = _generateRandomString(8);
    final directoryName = '$timestamp-$randomString';
    final inboxDir = Directory('${appDocDir.path}/inbox/$directoryName');
    await inboxDir.create(recursive: true);

    // 保存到数据库（标记处理中），包含真实的 filePath
    final tempItem = InboxItem(
      title: title,
      source: source,
      url: url,
      filePath: inboxDir.path,
      content: '正在处理中...',
      category: '未知归类',
      status: '处理中',
      createdAt: DateTime.now(),
    );

    final id = await _dbHelper.insertInboxItem(tempItem);
    return tempItem.copyWith(id: id);
  }

  // 更新剪贴板条目
  Future<void> updateClipboardItemWithContent(int id, String jsonResult) async {
    try {
      final result = jsonDecode(jsonResult) as Map<String, dynamic>;

      final title = result['title'] as String? ?? '未命名';
      final filePath = result['filePath'] as String?;
      final textContent = result['textContent'] as String? ?? '';
      final url = result['url'] as String? ?? '';

      final existingItem = await _dbHelper.getInboxItemById(id);
      if (existingItem == null) {
        print('[UpdateError] 条目不存在: $id');
        return;
      }

      final updatedItem = existingItem.copyWith(
        title: title,
        content: textContent,
        filePath: filePath,
        url: url,
        status: '未整理',
      );

      await _dbHelper.updateInboxItem(updatedItem);
      print('[UpdateSuccess] 条目更新完成');
    } catch (e) {
      print('[UpdateError] 更新条目失败: $e');
      await updateItemStatus(id, 'error');
    }
  }

  Future<void> updateItemStatus(int id, String status) async {
    try {
      final item = await _dbHelper.getInboxItemById(id);
      if (item != null) {
        final updatedItem = item.copyWith(status: status);
        await _dbHelper.updateInboxItem(updatedItem);
      }
    } catch (e) {
      print('[UpdateStatusError] 更新状态失败: $e');
    }
  }

  // 更新状态（失败时保留目录和文件）
  Future<void> updateItemStatusWithCleanup(int id, String status) async {
    try {
      final item = await _dbHelper.getInboxItemById(id);
      if (item != null) {
        // 只更新状态为 error，保留目录和文件（包括空文件）
        // 让用户决定是否手动删除
        final updatedItem = item.copyWith(status: status);
        await _dbHelper.updateInboxItem(updatedItem);
        print('[StatusUpdate] 状态更新为: $status');
      }
    } catch (e) {
      print('[UpdateStatusError] 更新状态失败: $e');
    }
  }

  // 识别来源
  String _identifySource(String url) {
    final Map<String, String> sourceDomains = {
      'doubao.com': '豆包',
      'ark.cn-beijing.volces.com': '豆包API',
      'qianwen.aliyun.com': '通义千问',
      'qwen.ai': '通义千问',
      'yiyan.baidu.com': '文心一言',
      'tongyi.aliyun.com': '通义千问',
      'tiangong.kaiwu.baidu.com': '天工AI',
      'kimi.moonshot.cn': 'Kimi',
      'chatglm.cn': '智谱清言',
      'hunyuan.tencent.com': '混元',
      'yb.tencent.com': '元宝',
      'xinghuo.xfyun.cn': '讯飞星火',
      'copilot.microsoft.com': 'Copilot',
      'chat.openai.com': 'ChatGPT',
      'claude.ai': 'Claude',
      'gemini.google.com': 'Gemini',
      'mistral.ai': 'Mistral',
      'poe.com': 'Poe',
      'perplexity.ai': 'Perplexity',
      'you.com': 'You',
      'phind.com': 'Phind',
      'phind.ai': 'Phind',
      'wenda.ai': '闻达',
    };

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      String mainDomain = host;
      if (mainDomain.startsWith('www.')) {
        mainDomain = mainDomain.substring(4);
      }

      for (final entry in sourceDomains.entries) {
        if (mainDomain.contains(entry.key) || host.contains(entry.key)) {
          return entry.value;
        }
      }

      final parts = mainDomain.split('.');
      if (parts.length >= 2) {
        final topDomain =
            '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
        for (final entry in sourceDomains.entries) {
          if (topDomain == entry.key || topDomain.endsWith('.${entry.key}')) {
            return entry.value;
          }
        }
      }

      return '未知';
    } catch (e) {
      return '未知';
    }
  }

  // 添加测试数据
  Future<void> addTestData() async {}

  // 归档条目
  Future<void> archiveItems(List<InboxItem> items) async {
    for (final item in items) {
      await deleteItem(item);
    }
  }

  // 删除条目
  Future<void> deleteInboxItem(int id) async {
    final item = await _dbHelper.getInboxItemById(id);
    if (item != null) {
      await deleteItem(item);
    }
  }

  // 更新条目
  Future<void> updateInboxItem(InboxItem item) async {
    await updateItemInfo(item);
  }
}
