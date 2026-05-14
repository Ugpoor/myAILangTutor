import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../database/models/inbox_item.dart';
import 'llm_service.dart';

typedef ProcessProgressCallback = void Function(int current, int total, String reasoning);

class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LlmService _llmService = LlmService();

  Future<Directory> getInboxDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final inboxDir = Directory('${docDir.path}/inbox');
    if (!await inboxDir.exists()) {
      await inboxDir.create(recursive: true);
    }
    return inboxDir;
  }

  Future<Directory> getBackupDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docDir.path}/bkupInbox');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<Map<String, dynamic>> parseIntentMessage(String message) async {
    final RegExp sourceReg = RegExp(r'来自(\S+)的信息');
    final RegExp urlReg = RegExp(r'https?://[^\s]+');

    final sourceMatch = sourceReg.firstMatch(message);
    final urlMatch = urlReg.firstMatch(message);

    final source = sourceMatch?.group(1) ?? '未知来源';
    final url = urlMatch?.group(0) ?? '';

    final titleStart = message.indexOf('来自$source的信息');
    final titleEnd = url.isNotEmpty ? message.indexOf(url) : message.length;
    String title = message.substring(0, titleEnd).trim();
    if (title.length > 100) {
      title = title.substring(0, 100) + '...';
    }

    return {
      'title': title.isEmpty ? '未命名消息' : title,
      'source': source,
      'url': url,
    };
  }

  Future<InboxItem> fetchAndSaveContent({
    required String title,
    required String source,
    required String url,
  }) async {
    final inboxDir = await getInboxDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final itemDir = Directory('${inboxDir.path}/$timestamp');
    await itemDir.create(recursive: true);

    String content = '';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        content = response.body;
        final htmlFile = File('${itemDir.path}/index.html');
        await htmlFile.writeAsString(content);
      }
    } catch (e) {
      content = '获取内容失败: $e';
    }

    final item = InboxItem(
      title: title,
      source: source,
      url: url,
      filePath: itemDir.path,
      content: content,
      createdAt: DateTime.now(),
    );

    final id = await _dbHelper.insertInboxItem(item);
    return item.copyWith(id: id);
  }

  Future<Map<String, String>> classifyByLlm(String content) async {
    final prompt = '''以下内容分类：1，知识点；2，错题本（有批改的习题）；3，习题（无答案，无批改）；4，作品集（非问题无需解答，是一段文章或者句子）。

$content

请回答序号''';

    try {
      final response = await _llmService.generateResponse(prompt);
      final result = response['response'] as String;
      final reasoning = response['reasoning'] as String;
      
      String category = '未知归类';
      if (result.contains('1')) category = '知识点';
      else if (result.contains('2')) category = '错题本';
      else if (result.contains('3')) category = '习题';
      else if (result.contains('4')) category = '作品集';
      
      return {
        'category': category,
        'reasoning': reasoning
      };
    } catch (e) {
      print('LLM分类失败: $e');
      return {
        'category': '未知归类',
        'reasoning': '分类过程出错: $e'
      };
    }
  }

  Future<Map<String, String>> processAndClassifyItem(InboxItem item) async {
    final result = await classifyByLlm(item.content);
    final category = result['category']!;
    final reasoning = result['reasoning']!;
    
    final updatedItem = item.copyWith(
      category: category,
      status: '已处理',
    );
    await _dbHelper.updateInboxItem(updatedItem);
    
    return result;
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

  Future<void> processAllUnprocessedItems() async {
    final items = await _dbHelper.getInboxItemsByStatus('未处理');
    await processItems(items);
  }

  Future<List<InboxItem>> filterItems({
    String? keyword,
    String? source,
    String? category,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allItems = await _dbHelper.getAllInboxItems();
    
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

  Future<void> archiveItems(List<InboxItem> items) async {
    for (final item in items) {
      final itemDir = Directory(item.filePath);
      if (await itemDir.exists()) {
        await itemDir.delete(recursive: true);
      }
      await _dbHelper.deleteInboxItem(item.id!);
    }
  }

  Future<void> archiveAllProcessedItems() async {
    final processedItems = await _dbHelper.getInboxItemsByStatus('已处理');
    await archiveItems(processedItems);
  }

  Future<void> updateItemContent(InboxItem item, String newContent) async {
    final updatedItem = item.copyWith(content: newContent);
    await _dbHelper.updateInboxItem(updatedItem);
  }

  Future<void> updateInboxItem(InboxItem item) async {
    await _dbHelper.updateInboxItem(item);
  }

  Future<void> deleteInboxItem(int id) async {
    await _dbHelper.deleteInboxItem(id);
  }

  Future<List<InboxItem>> getAllInboxItems() async {
    return await _dbHelper.getAllInboxItems();
  }

  Future<void> addTestData() async {
    await fetchAndSaveContent(
      title: '三个近义词：开心、快乐、愉悦',
      source: '豆包',
      url: 'https://example.com',
    );

    await fetchAndSaveContent(
      title: '文化：故宫的变迁',
      source: '元宝',
      url: 'https://example.com',
    );
  }
}
