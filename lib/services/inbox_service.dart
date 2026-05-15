import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/models/inbox_item.dart' hide DatabaseHelper;
import 'llm_service.dart';
import 'app_service.dart';
import '../database/db_helper.dart' show DatabaseHelper;

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
    String content = '',
  }) async {
    final inboxDir = await getInboxDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final itemDir = Directory('${inboxDir.path}/$timestamp');
    await itemDir.create(recursive: true);

    if (content.isEmpty) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          content = response.body;
        }
      } catch (e) {
        content = '获取内容失败: $e';
      }
    }

    final htmlFile = File('${itemDir.path}/index.html');
    await htmlFile.writeAsString(content);

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
    
    // 归档到对应栏目
    await _archiveToColumn(item, category);
    
    final updatedItem = item.copyWith(
      category: category,
      status: '已处理',
    );
    await _dbHelper.updateInboxItem(updatedItem);
    
    return result;
  }

  Future<void> _archiveToColumn(InboxItem item, String category) async {
    try {
      final appService = AppService();
      await appService.init();
      
      switch (category) {
        case '知识点':
          await appService.createKnowledgePoint(
            item.title,
            content: item.content,
            category: '自动归类',
            lang: 'cn',
          );
          break;
        case '错题本':
          await appService.createErrorRecord(
            item.content,
            correctAnswer: '',
            subject: '语文',
            lesson: item.title,
            lang: 'cn',
          );
          break;
        case '习题':
          await appService.createExercise(
            item.content,
            category: '自动归类',
            lang: 'cn',
          );
          break;
        case '作品集':
          await appService.createPortfolioItem(
            item.title,
            type: '文章',
            contentPath: item.filePath,
            lang: 'cn',
          );
          break;
      }
    } catch (e) {
      print('归档失败: $e');
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
      content: '开心、快乐、愉悦是三个意思相近的词语。开心：心情舒畅，快乐：感到幸福或满意，愉悦：喜悦愉快的心情。这三个词都表达快乐的情绪，但在程度和用法上有所不同。',
    );

    await fetchAndSaveContent(
      title: '文化：故宫的变迁',
      source: '元宝',
      url: 'https://example.com',
      content: '故宫是中国明清两代的皇家宫殿，位于北京市中心。始建于明朝永乐年间，历经多次修缮和扩建。故宫是世界上现存规模最大、保存最为完整的木质结构古建筑群。',
    );

    await fetchAndSaveContent(
      title: '老舍《猫》全文',
      source: '豆包',
      url: 'https://example.com',
      content: '猫\n老舍\n猫的性格实在有些古怪。说它老实吧，它的确有时候很乖。它会找个暖和的地方，成天睡大觉，无忧无虑，什么事也不过问。可是，它决定要出去玩玩，就会出走一天一夜，任凭谁怎么呼唤，它也不肯回来。说它贪玩吧，的确是呀，要不怎么会一天一夜不回家呢？可是，它听到老鼠的一点响动，又多么尽职。它屏息凝视，一连就是几个钟头，非把老鼠等出来不可！',
    );

    await fetchAndSaveContent(
      title: '数学错题：应用题',
      source: '豆包',
      url: 'https://example.com',
      content: '题目：小明有10个苹果，分给小红3个，又买了5个，现在小明有几个苹果？\n我的答案：10-3=7（个）\n正确答案：10-3+5=12（个）\n解析：先算分给小红后剩下的苹果数，再加上新买的苹果数。',
    );

    await fetchAndSaveContent(
      title: '作文：我的妈妈',
      source: '豆包',
      url: 'https://example.com',
      content: '我的妈妈\n我的妈妈是一位普通的家庭主妇，但在我心中她是最伟大的人。每天早上，妈妈总是第一个起床，为我们准备早餐。她的手虽然粗糙，但非常温暖。妈妈不仅照顾我们的生活，还关心我们的学习。她常常陪我做作业，鼓励我努力学习。我爱我的妈妈！',
    );

    await fetchAndSaveContent(
      title: '阅读理解练习题',
      source: '元宝',
      url: 'https://example.com',
      content: '阅读短文，回答问题。\n\n春天来了，小草绿了，花儿开了。小鸟在树上唱歌，蝴蝶在花丛中飞舞。小朋友们脱下厚厚的棉衣，来到公园里玩耍。\n\n问题1：春天来了，小草和花儿有什么变化？\n问题2：小朋友们在公园里做什么？',
    );
  }

  // 解析intent数据
  Future<IntentData> parseIntentJson(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return IntentData.fromJson(json);
    } catch (e) {
      throw FormatException('Invalid intent JSON format: $e');
    }
  }

  // 从subject识别来源标签
  String extractSourceFromSubject(String subject) {
    final patterns = [
      '豆包',
      '元宝',
      '文心一言',
      'ChatGPT',
      'GPT',
      'Claude',
      'Gemini',
    ];

    for (final pattern in patterns) {
      if (subject.contains(pattern)) {
        return pattern;
      }
    }

    // 如果找不到特定来源，尝试匹配"来自XX"
    final regExp = RegExp(r'来自(\S+)');
    final match = regExp.firstMatch(subject);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }

    return '未知来源';
  }

  // 使用LLM生成标题
  Future<String> generateTitleWithLlm(String content) async {
    final prompt = '''请为以下内容生成一个简洁明了的标题（不超过20个字）：

$content

请只返回标题，不要其他内容。''';

    try {
      final response = await _llmService.generateResponse(prompt);
      var title = (response['response'] as String).trim();
      
      // 清理标题（移除引号、换行符等）
      title = title.replaceAll(RegExp(r'["\n\r]'), '').trim();
      
      // 如果标题太长，截取
      if (title.length > 20) {
        title = title.substring(0, 20);
      }
      
      return title.isNotEmpty ? title : '未命名文档';
    } catch (e) {
      print('生成标题失败: $e');
      return '未命名文档';
    }
  }

  // 简单的HTML到Markdown转换
  String convertHtmlToMarkdown(String html) {
    var markdown = html;

    // 移除script和style标签
    markdown = markdown.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    markdown = markdown.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    // 处理标题
    markdown = markdown.replaceAllMapped(RegExp(r'<h(\d)[^>]*>(.*?)</h\1>'), (match) {
      final level = match.group(1)!;
      final text = _stripHtmlTags(match.group(2)!);
      return '\n${'#' * int.parse(level)} $text\n';
    });

    // 处理段落
    markdown = markdown.replaceAllMapped(RegExp(r'<p[^>]*>(.*?)</p>'), (match) {
      final text = _stripHtmlTags(match.group(1)!);
      return '\n$text\n';
    });

    // 处理链接
    markdown = markdown.replaceAllMapped(RegExp(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>'), (match) {
      final url = match.group(1)!;
      final text = _stripHtmlTags(match.group(2)!);
      return '[$text]($url)';
    });

    // 处理图片
    markdown = markdown.replaceAllMapped(RegExp(r'<img[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*>'), (match) {
      final url = match.group(1)!;
      final alt = match.group(2)!;
      return '![$alt]($url)';
    });

    markdown = markdown.replaceAllMapped(RegExp(r'<img[^>]*src="([^"]*)"[^>]*>'), (match) {
      final url = match.group(1)!;
      return '![图片]($url)';
    });

    // 处理列表
    markdown = markdown.replaceAllMapped(RegExp(r'<li[^>]*>(.*?)</li>'), (match) {
      final text = _stripHtmlTags(match.group(1)!);
      return '- $text\n';
    });

    // 处理粗体和斜体
    markdown = markdown.replaceAllMapped(RegExp(r'<(strong|b)[^>]*>(.*?)</\1>'), (match) {
      final text = _stripHtmlTags(match.group(2)!);
      return '**$text**';
    });

    markdown = markdown.replaceAllMapped(RegExp(r'<(em|i)[^>]*>(.*?)</\1>'), (match) {
      final text = _stripHtmlTags(match.group(2)!);
      return '*$text*';
    });

    // 处理br标签
    markdown = markdown.replaceAll(RegExp(r'<br\s*/?>'), '\n');

    // 清理多余的HTML标签
    markdown = _stripHtmlTags(markdown);

    // 清理多余的空白
    markdown = markdown.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    markdown = markdown.trim();

    return markdown;
  }

  // 清理HTML标签
  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // 处理intent数据的完整流程
  Future<InboxItem> processIntentData(String jsonString) async {
    // 1. 解析intent数据
    final intentData = await parseIntentJson(jsonString);
    
    // 2. 提取来源
    final source = extractSourceFromSubject(intentData.subject);
    
    // 3. 提取URL (从text字段)
    final url = _extractUrl(intentData.text);
    
    // 4. 下载HTML
    String htmlContent = '';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        htmlContent = response.body;
      } else {
        htmlContent = '下载失败: HTTP ${response.statusCode}';
      }
    } catch (e) {
      htmlContent = '下载失败: $e';
    }

    // 5. 转换HTML为Markdown
    final markdownContent = convertHtmlToMarkdown(htmlContent);
    
    // 6. 使用LLM生成标题
    final title = await generateTitleWithLlm(markdownContent);
    
    // 7. 创建目录和文件
    final inboxDir = await getInboxDirectory();
    final cleanTitle = _sanitizeFileName(title);
    final itemDir = Directory(p.join(inboxDir.path, cleanTitle));
    
    // 如果目录已存在，添加时间戳
    if (await itemDir.exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final itemDirWithTimestamp = Directory(p.join(inboxDir.path, '${cleanTitle}_$timestamp'));
      await itemDirWithTimestamp.create(recursive: true);
    } else {
      await itemDir.create(recursive: true);
    }

    // 保存HTML文件
    final htmlFile = File(p.join(itemDir.path, 'index.html'));
    await htmlFile.writeAsString(htmlContent);

    // 保存Markdown文件
    final mdFile = File(p.join(itemDir.path, 'content.md'));
    await mdFile.writeAsString(markdownContent);

    // 8. 创建InboxItem
    final item = InboxItem(
      title: title,
      source: source,
      url: url,
      filePath: itemDir.path,
      content: markdownContent,
      createdAt: DateTime.now(),
    );

    final id = await _dbHelper.insertInboxItem(item);
    return item.copyWith(id: id);
  }

  // 从文本中提取URL
  String _extractUrl(String text) {
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(text);
    return match?.group(0) ?? '';
  }

  // 清理文件名
  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  // 读取Markdown文件内容
  Future<String> readMarkdownFile(String filePath) async {
    final mdFile = File(p.join(filePath, 'content.md'));
    if (await mdFile.exists()) {
      return await mdFile.readAsString();
    }
    return '';
  }

  // 保存Markdown文件
  Future<void> saveMarkdownFile(String filePath, String content) async {
    final mdFile = File(p.join(filePath, 'content.md'));
    await mdFile.writeAsString(content);
  }
}
