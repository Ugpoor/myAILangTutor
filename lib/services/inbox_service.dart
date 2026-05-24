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
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart' show DatabaseHelper;
import 'llm_service.dart';

typedef ProcessProgressCallback = void Function(int current, int total, String reasoning);

class IntentData {
  final String subject;
  final String text;

  IntentData({
    required this.subject,
    required this.text,
  });

  factory IntentData.fromJson(Map<String, dynamic> json) {
    return IntentData(
      subject: json['subject'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

// 栏目和目录映射
const Map<String, String> _columnDirectories = {
  '知识点': 'knowledge',
  '错题本': 'errors',
  '习题集': 'exercises',
  '作品集': 'portfolio',
  '无法分类': 'unknown',
  '未知归类': 'inbox',
};

/// Unified classification result returned by classifyItem()
class ClassificationResult {
  final String category;
  final String reasoning;
  final String? newTitle;

  ClassificationResult({
    required this.category,
    required this.reasoning,
    this.newTitle,
  });
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

  // 从目录创建条目
  Future<InboxItem?> _createItemFromDirectory(String columnName, Directory dir) async {
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

      return InboxItem(
        id: dbItem?.id,
        title: title,
        source: source,
        url: url,
        filePath: dir.path,
        content: dbItem?.content ?? '',
        category: columnName,
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
      return;
    }

    // 获取新栏目的目录
    final newColumnDir = await getColumnDirectory(newColumn);
    final dirName = p.basename(oldDir.path);
    
    // 确定最终目标路径
    String finalPath = '${newColumnDir.path}/$dirName';
    
    // 如果目标目录已存在，添加后缀
    if (await Directory(finalPath).exists()) {
      var suffix = 1;
      while (await Directory('${newColumnDir.path}/${dirName}_$suffix').exists()) {
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
      final id = await _dbHelper.insertInboxItem(updatedItem);
      updatedItem.copyWith(id: id);
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
      final id = await _dbHelper.insertInboxItem(item);
      item.copyWith(id: id);
    }
  }

  // 获取所有条目（优先从文件系统）
  Future<List<InboxItem>> getAllInboxItems() async {
    return await scanAllItemsFromFileSystem();
  }

  // 过滤条目
  Future<List<InboxItem>> filterItems({
    String? keyword,
    String? source,
    String? category,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allItems = await getAllInboxItems();

    return allItems.where((item) {
      bool match = true;

      if (keyword != null && keyword.isNotEmpty) {
        match = match && item.title.toLowerCase().contains(keyword.toLowerCase());
      }

      if (source != null && source.isNotEmpty) {
        match = match && item.source.toLowerCase().contains(source.toLowerCase());
      }

      if (category != null && category.isNotEmpty) {
        match = match && item.category == category;
      }

      if (status != null && status.isNotEmpty) {
        match = match && item.status == status;
      }

      if (startDate != null) {
        match = match && item.createdAt.isAfter(startDate);
      }

      if (endDate != null) {
        match = match && item.createdAt.isBefore(endDate);
      }

      return match;
    }).toList();
  }

  // Classify an inbox item: extract content, optionally optimize title, then classify via LLM
  /// Returns [ClassificationResult] with the final category and optional new title
  Future<ClassificationResult> classifyItem(InboxItem item) async {
    print('[SortLog] ========== 开始分类处理 (unified): ${item.title}');

    // Step 1: Extract headings and text content from HTML
    final htmlPath = '${item.filePath}/index.html';
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

    // Step 3: Classify using LLM
    final systemPrompt = '''你是一位专业的文档分类助手。请判断以下文档内容最属于哪个分类栏目（每篇文档只能归入一个类别，不可多选）。

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
$textContent

请只回复一个数字（1-5）。''';

    final categoryResponse = await _llmService.generateResponse(systemPrompt);
    String category = '无法分类';

    final numberMap = <String, String>{
      '1': '习题集',
      '2': '错题本',
      '3': '作品集',
      '4': '知识点',
      '5': '无法分类',
    };

    if (categoryResponse['success'] == true) {
      final response = categoryResponse['response'] as String;
      final match = RegExp(r'[1-5]').firstMatch(response);
      if (match != null) {
        final numStr = match.group(0)!;
        if (numberMap.containsKey(numStr)) {
          category = numberMap[numStr]!;
        }
      }
    }

    final reasoning = categoryResponse['success'] == true
        ? 'LLM分类完成'
        : 'LLM分类失败: ${categoryResponse['reasoning']}';

    print('[SortLog] 分类结果: $category (标题: $finalTitle)');
    print('[SortLog] ========== 分类处理完成 (unified) ==========');

    return ClassificationResult(
      category: category,
      reasoning: reasoning,
      newTitle: finalTitle != item.title ? finalTitle : null,
    );
  }

  // Extract heading tags from HTML content
  List<String> _extractHeadingsFromHtml(String html) {
    final List<String> headings = [];
    final regex = RegExp(r'<h([1-6])[^>]*>(.*?)</h[1-6]>', caseSensitive: false);
    
    for (final match in regex.allMatches(html)) {
      final text = match.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (text.isNotEmpty && text.length > 2) {
        headings.add(text);
      }
    }
    return headings;
  }

  // Extract clean text from HTML
  String _extractTextFromHtmlFile(String html) {
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length > 30000) {
      text = text.substring(0, 30000) + '\n...(truncated ${text.length - 30000} more chars)';
    }
    return text;
  }

  // Use LLM to select the best title from candidates
  Future<String> _selectBestTitle(List<String> titles, String content) async {
    final titlesList = titles.asMap().entries
        .map((entry) => '${entry.key + 1}、"${entry.value}"')
        .join('\n');

    final prompt = '''请选择最能反映以下内容的标题，只需回复序号（如：1、2、3等）。

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
    final systemPrompt = '''你是一位专业的文档分类助手。请判断以下文档内容最属于哪个分类栏目（每篇文档只能归入一个类别，不可多选）。

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

      return {
        'category': category,
        'reasoning': reasoning
      };
    } catch (e) {
      print('LLM分类失败: $e');
      final aiReply = '分类结果：无法分类（LLM请求失败）';
      await _saveClassificationChat(content, aiReply);
      return {
        'category': '无法分类',
        'reasoning': 'LLM请求失败: $e'
      };
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
      print('[ChatLog] [Classification] Saved full chat record for: ${item.title}');
    } catch (e) {
      print('[ChatLogError] 保存完整分类记录失败: $e');
    }
  }

  Future<void> processItems(List<InboxItem> items, {ProcessProgressCallback? onProgress}) async {
    for (int i = 0; i < items.length; i++) {
      final result = await processAndClassifyItem(items[i]);
      final reasoning = result['reasoning']!;

      if (onProgress != null) {
        onProgress(i + 1, items.length, reasoning);
      }
    }
  }

  /// Unified batch processing: use classifyItem (reads from file) for consistent behavior
  Future<Map<String, String>> processAndClassifyItem(InboxItem item) async {
    print('[SortLog] ========== 开始分类处理 (unified): ${item.title}');

    try {
      // Use unified classifyItem which handles: HTML reading → heading extraction → title optimization → LLM classification
      final result = await classifyItem(item);
      final category = result.category;
      final reasoning = result.reasoning;
      final newTitle = result.newTitle;
      print('[SortLog] 分类结果: $category (标题: $newTitle)');

      // Determine actual file path after potential move
      String finalFilePath = item.filePath;
      if (item.category != category || newTitle != null) {
        await moveItemToColumn(item, category);

        // Find actual moved path (may have _N suffix)
        final newColumnDir = await getColumnDirectory(category);
        final dirName = p.basename(item.filePath);
        var suffix = 1;
        final candidatePath = '${newColumnDir.path}/$dirName';
        if (await Directory(candidatePath).exists()) {
          finalFilePath = candidatePath;
        } else {
          while (suffix <= 10) {
            final searchPath = '${newColumnDir.path}/${dirName}_$suffix';
            if (await Directory(searchPath).exists()) {
              finalFilePath = searchPath;
              break;
            }
            suffix++;
          }
        }
      }

      // Build updated item with latest data
      final updatedItem = item.copyWith(
        title: newTitle ?? item.title,
        category: category,
        filePath: finalFilePath,
        status: '已处理',
      );

      // Persist to inbox_items table
      await updateItemInfo(updatedItem);

      // Write through to corresponding module table
      await _writeToModuleTable(updatedItem);

      // Save full chat history to conversation database
      await _saveFullClassificationChat(
        item: item,
        category: category,
        reasoning: reasoning,
        newTitle: newTitle,
      );

      print('[SortLog] ========== 分类处理完成 (unified) ==========');

      return {
        'category': category,
        'reasoning': reasoning,
      };
    } catch (e) {
      print('[SortLog] 分类处理异常: $e');
      return {
        'category': '无法分类',
        'reasoning': '处理失败: $e',
      };
    }
  }

  // 分类后写入对应模块表（通过 LLM 将 inbox item content 解析为目标数据结构）
  Future<void> _writeToModuleTable(InboxItem item) async {
    final db = await _dbHelper.database;

    // 如果 content 为空或只有占位符，跳过智能解析
    if (item.content.isEmpty || item.content == '正在处理中...') {
      print('[WriteThrough] 内容未就绪，跳过智能解析');
      return;
    }

    try {
      // 调用 LLM 将 content 解析为目标模块的数据结构
      final parsedData = await parseContentForCategory(item.content, item.title, item.category);

      switch (item.category) {
        case '错题本':
          await _insertErrorRecord(db, item, parsedData);
          break;
        case '习题集':
          await _insertExercise(db, item, parsedData);
          break;
        case '作品集':
          await _insertPortfolioItem(db, item, parsedData);
          break;
        case '知识点':
          await _insertKnowledgePoint(db, item, parsedData);
          break;
      }
    } catch (e) {
      print('[WriteThrough] LLM 解析失败: $e');
      // LLM 失败时降级为仅标题插入
      await _fallbackInsertModuleTable(item);
    }
  }

  // ========== 核心方法：通过 LLM 将 inbox item 内容解析为目标模块数据结构 ==========
  
  /// 根据目标分类，调用 LLM 解析 content 为结构化数据
  Future<Map<String, dynamic>> parseContentForCategory(
    String content,
    String title,
    String category,
  ) async {
    final schemaPrompt = _getSchemaPrompt(category);
    
    final systemPrompt = '''你是一位教育数据解析专家。请将用户收藏的文档内容解析为结构化的学习目标数据。

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
注：作品正文保留在 filePath 指向的 HTML 文件中，数据库只存元数据。''' ;
      
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

  Future<void> _insertErrorRecord(Database db, InboxItem item, Map<String, dynamic> data) async {
    final dao = ErrorRecordDao(db);
    final nextNum = await dao.nextErrorIdNumber();

    final record = ErrorRecord(
      errorId: 'T$nextNum',
      correctAnswer: data['correctAnswer'] as String?,
      eids: (data['errorType'] as String?) != null ? [data['errorType'] as String] : [],
      progress: data['progress'] ?? '待订正',
      question: data['question'] as String?,
      wrongAnswer: data['wrongAnswer'] as String?,
      wrongWhere: data['wrongWhere'] as String?,
      whyWrong: data['whyWrong'] as String?,
      howPrevent: data['howPrevent'] as String?,
      notes: data['notes'] as String?,
      contentPath: item.filePath,
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
    print('[WriteThrough] 错题本条目已创建: T$nextNum');
  }

  Future<void> _insertExercise(Database db, InboxItem item, Map<String, dynamic> data) async {
    final testDao = TestDao(db);
    final questionDao = QuestionDao(db);
    final nextNum = await testDao.nextTidNumber();
    final tid = 'T$nextNum';

    // 先插入 Test 记录
    await testDao.insert(Test(
      tid: tid,
      title: data['title'] ?? item.title ?? '收件箱导入',
      lessonUnitList: [],
      kids: [],
      images: [],
      status: '未开始',
      createdAt: item.createdAt,
      lang: 'cn',
    ));

    // 再插入对应的 Question 记录
    await questionDao.insert(Question(
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
    ));

    print('[WriteThrough] 习题集条目已创建: $tid');
  }

  Future<void> _insertPortfolioItem(Database db, InboxItem item, Map<String, dynamic> data) async {
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
    print('[WriteThrough] 作品集条目已创建');
  }

  Future<void> _insertKnowledgePoint(Database db, InboxItem item, Map<String, dynamic> data) async {
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
    print('[WriteThrough] 知识点条目已创建');
  }

  // ========== 降级策略：LLM 失败时的简单插入 ==========

  Future<void> _fallbackInsertModuleTable(InboxItem item) async {
    final db = await _dbHelper.database;

    switch (item.category) {
      case '错题本':
        final dao = ErrorRecordDao(db);
        final nextNum = await dao.nextErrorIdNumber();
        await dao.insert(ErrorRecord(
          errorId: 'T$nextNum',
          wrongWhere: item.title,
          contentPath: item.filePath,
          progress: '待订正',
          createdAt: item.createdAt,
          lang: 'cn',
        ));
        print('[Fallback] 错题本条目已创建（仅标题）: T$nextNum');
        break;

      case '习题集':
        final testDao = TestDao(db);
        final questionDao = QuestionDao(db);
        final nextNum = await testDao.nextTidNumber();
        final tid = 'T$nextNum';
        
        await testDao.insert(Test(
          tid: tid,
          title: item.title,
          lessonUnitList: [],
          kids: [],
          images: [],
          status: '未开始',
          createdAt: item.createdAt,
          lang: 'cn',
        ));
        
        await questionDao.insert(Question(
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
        ));
        print('[Fallback] 习题集条目已创建（仅标题）');
        break;

      case '作品集':
        final dao = PortfolioDao(db);
        await dao.insert(PortfolioItem(
          title: item.title,
          contentPath: item.filePath,
          isOriginal: false,
          createdAt: item.createdAt,
          lang: 'cn',
        ));
        print('[Fallback] 作品集条目已创建（仅标题）');
        break;

      case '知识点':
        final dao = KnowledgePointDao(db);
        await dao.insert(KnowledgePoint(
          title: item.title,
          contentPath: item.filePath,
          createdAt: item.createdAt,
          lang: 'cn',
          cid: '',
        ));
        print('[Fallback] 知识点条目已创建');
        break;
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
        final topDomain = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
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
  Future<void> addTestData() async {
  }

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