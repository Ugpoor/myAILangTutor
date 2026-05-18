import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:html/parser.dart' as html_parser;
import '../database/models/inbox_item.dart' hide DatabaseHelper;
import '../database/models/chat_message.dart';
import '../database/db_helper.dart' show DatabaseHelper;
import 'llm_service.dart';
import 'app_service.dart';

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
    final systemPrompt = '''你是一位专业的文档分类助手，收到用户提供的文档后，需以结构化 JSON 格式输出分类结果。返回的json中应包含category和number字段。
分类规则：
1，习题（没有答卷和批改的练习题）
2，错题（有答卷和批改的错误题目）
3，作品集（名人名篇或者自己原创作文）
4，知识点（文化历史地理等知识介绍）
5，无法分类（不符合以上类别）''';

    final userPrompt = '''需要归类的文档内容：$content''';

    try {
      final response = await _llmService.generateJsonResponse(systemPrompt, userPrompt);
      
      String category = '无法分类';
      String reasoning = '';
      
      if (response['success'] == true && response['json'] != null) {
        final jsonResult = response['json'] as Map<String, dynamic>;
        
        if (jsonResult.containsKey('number')) {
          final number = jsonResult['number'] is int 
              ? jsonResult['number'] as int 
              : int.tryParse(jsonResult['number'].toString()) ?? 0;
          
          switch (number) {
            case 1:
              category = '习题';
              break;
            case 2:
              category = '错题本';
              break;
            case 3:
              category = '作品集';
              break;
            case 4:
              category = '知识点';
              break;
            case 5:
              category = '无法分类';
              break;
          }
        } else if (jsonResult.containsKey('category')) {
          category = jsonResult['category'] as String;
          if (!['习题', '错题本', '作品集', '知识点', '无法分类'].contains(category)) {
            category = '无法分类';
          }
        }
        
        reasoning = 'JSON格式分类完成';
      }
      
      final aiReply = '分类结果：$category（序号${_getCategoryNumber(category)}）\n\n分类依据：$reasoning';
      await _saveClassificationChat(userPrompt, aiReply);
      
      return {
        'category': category,
        'reasoning': reasoning
      };
    } catch (e) {
      print('LLM分类失败: $e');
      
      final aiReply = '分类结果：无法分类（LLM请求失败）';
      await _saveClassificationChat(userPrompt, aiReply);
      
      return {
        'category': '无法分类',
        'reasoning': 'LLM请求失败: $e'
      };
    }
  }

  int _getCategoryNumber(String category) {
    switch (category) {
      case '习题': return 1;
      case '错题本': return 2;
      case '作品集': return 3;
      case '知识点': return 4;
      default: return 5;
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

  Future<void> showReceivedIntentMessage(String jsonMessage) async {
    print('[IntentLog] ========== 收到转发信息 ==========');
    print('[IntentLog] 原始内容: $jsonMessage');
    
    final userMessage = '收到一条消息：$jsonMessage';
    await _saveChatMessage(userMessage, true);
    
    final aiReply = '已收到消息，正在处理...';
    await _saveChatMessage(aiReply, false);
  }

  Future<void> logProcessingStep(String step) async {
    print('[IntentLog] $step');
    await _saveChatMessage(step, false);
  }

  Future<Map<String, String>> processAndClassifyItem(InboxItem item) async {
    print('[SortLog] ========== 开始分类处理: ${item.title}');
    await logProcessingStep('正在分析内容...');
    
    final result = await classifyByLlm(item.content);
    final category = result['category']!;
    final reasoning = result['reasoning']!;
    print('[SortLog] 分类结果: $category');
    
    await logProcessingStep('分类完成：$category');
    
    // 归档到对应栏目
    await _archiveToColumn(item, category);
    
    final updatedItem = item.copyWith(
      category: category,
      status: '已处理',
    );
    await _dbHelper.updateInboxItem(updatedItem);
    
    await logProcessingStep('已归档到"$category"栏目');
    print('[SortLog] ========== 分类处理完成 ==========');
    
    return result;
  }

  Future<void> _archiveToColumn(InboxItem item, String category) async {
    try {
      print('[ArchiveLog] 开始归档: ${item.title} -> $category');
      await logProcessingStep('正在归档到"$category"...');
      
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
          print('[ArchiveLog] 已创建知识点');
          break;
        case '错题本':
          await appService.createErrorRecord(
            item.content,
            correctAnswer: '',
            subject: '语文',
            lesson: item.title,
            lang: 'cn',
          );
          print('[ArchiveLog] 已创建错题');
          break;
        case '习题':
          await appService.createExercise(
            item.content,
            category: '自动归类',
            lang: 'cn',
          );
          print('[ArchiveLog] 已创建习题');
          break;
        case '作品集':
          await appService.createPortfolioItem(
            item.title,
            type: '文章',
            contentPath: item.filePath,
            lang: 'cn',
          );
          print('[ArchiveLog] 已创建作品集');
          break;
      }
      print('[ArchiveLog] 归档完成');
    } catch (e) {
      print('[ArchiveLog] 归档失败: $e');
      await logProcessingStep('归档失败: $e');
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
    final appService = AppService();
    
    for (final item in items) {
      try {
        final result = await appService.autoConvertInboxItem(
          item,
          suggestedCategory: item.category,
        );
        
        if (result['success'] == true) {
          await _dbHelper.deleteInboxItem(item.id!);
          print('归档成功: ${item.title} -> ${item.category}');
        } else {
          print('归档失败: ${item.title} - ${result['message']}');
        }
      } catch (e) {
        print('归档异常: ${item.title} - $e');
      }
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
    final existingItem = await _dbHelper.getInboxItemById(item.id!);
    
    if (existingItem != null && existingItem.category != item.category) {
      final appService = AppService();
      await appService.init();
      
      final oldCategory = existingItem.category;
      final newCategory = item.category;
      
      if (oldCategory != '未知归类' && oldCategory != '无法分类') {
        await appService.deleteByContentPath(existingItem.filePath);
      }
      
      if (newCategory != '未知归类' && newCategory != '无法分类') {
        await _archiveToColumn(item, newCategory);
      }
    }
    
    await _dbHelper.updateInboxItem(item);
  }

  Future<void> deleteInboxItem(int id) async {
    await _dbHelper.deleteInboxItem(id);
  }

  Future<List<InboxItem>> getAllInboxItems() async {
    return await _dbHelper.getAllInboxItems();
  }

  Future<void> addTestData() async {
    final existingItems = await getAllInboxItems();
    
    final testTitles = [
      '三个近义词：开心、快乐、愉悦',
      '文化：故宫的变迁',
      '老舍《猫》全文',
      '作文：我的妈妈',
      '阅读理解练习题',
    ];
    
    final existingTitles = existingItems.map((item) => item.title).toSet();
    
    if (!existingTitles.contains('三个近义词：开心、快乐、愉悦')) {
      await fetchAndSaveContent(
        title: '三个近义词：开心、快乐、愉悦',
        source: '豆包',
        url: 'https://example.com',
        content: '开心、快乐、愉悦是三个意思相近的词语。开心：心情舒畅，快乐：感到幸福或满意，愉悦：喜悦愉快的心情。这三个词都表达快乐的情绪，但在程度和用法上有所不同。',
      );
    }

    if (!existingTitles.contains('文化：故宫的变迁')) {
      await fetchAndSaveContent(
        title: '文化：故宫的变迁',
        source: '元宝',
        url: 'https://example.com',
        content: '故宫是中国明清两代的皇家宫殿，位于北京市中心。始建于明朝永乐年间，历经多次修缮和扩建。故宫是世界上现存规模最大、保存最为完整的木质结构古建筑群。',
      );
    }

    if (!existingTitles.contains('作文：我的妈妈')) {
      await fetchAndSaveContent(
        title: '作文：我的妈妈',
        source: '豆包',
        url: 'https://example.com',
        content: '我的妈妈\n我的妈妈是一位普通的家庭主妇，但在我心中她是最伟大的人。每天早上，妈妈总是第一个起床，为我们准备早餐。她的手虽然粗糙，但非常温暖。妈妈不仅照顾我们的生活，还关心我们的学习。她常常陪我做作业，鼓励我努力学习。我爱我的妈妈！',
      );
    }

    if (!existingTitles.contains('阅读理解练习题')) {
      await fetchAndSaveContent(
        title: '阅读理解练习题',
        source: '元宝',
        url: 'https://example.com',
        content: '阅读短文，回答问题。\n\n春天来了，小草绿了，花儿开了。小鸟在树上唱歌，蝴蝶在花丛中飞舞。小朋友们脱下厚厚的棉衣，来到公园里玩耍。\n\n问题1：春天来了，小草和花儿有什么变化？\n问题2：小朋友们在公园里做什么？',
      );
    }
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

  // 简单处理共享文本内容的方法
  Future<InboxItem> processSimpleContent(String title, String content) async {
    // 1. 创建目录和文件
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

    // 保存Markdown文件
    final mdFile = File(p.join(itemDir.path, 'content.md'));
    await mdFile.writeAsString(content);

    // 2. 创建InboxItem
    final item = InboxItem(
      title: title,
      source: 'share_intent',
      url: '',
      filePath: itemDir.path,
      content: content,
      createdAt: DateTime.now(),
    );

    final id = await _dbHelper.insertInboxItem(item);
    return item.copyWith(id: id);
  }

  // 处理intent数据的完整流程
  Future<InboxItem> processIntentData(String jsonString) async {
    print('[IntentLog] ========== 开始处理 ==========');
    // 显示收到的消息
    await showReceivedIntentMessage(jsonString);
    
    try {
      // 1. 解析intent数据
      print('[IntentLog] 1/8 - 正在解析intent数据');
      await logProcessingStep('正在解析intent数据...');
      final intentData = await parseIntentJson(jsonString);
      print('[IntentLog]   Subject: ${intentData.subject}');
      print('[IntentLog]   Text: ${intentData.text}');
      
      // 2. 提取来源
      print('[IntentLog] 2/8 - 正在提取来源');
      final source = extractSourceFromSubject(intentData.subject);
      print('[IntentLog]   来源: $source');
      await logProcessingStep('来源识别: $source');
      
      // 3. 提取URL (从text字段)
      print('[IntentLog] 3/8 - 正在提取URL');
      final url = _extractUrl(intentData.text);
      print('[IntentLog]   URL: $url');
      await logProcessingStep(url.isNotEmpty ? '检测到URL链接' : '纯文本内容');
      
      // 如果有URL，尝试下载；否则直接保存文本
      if (url.isNotEmpty) {
        // 4. 下载HTML
        print('[IntentLog] 4/8 - 正在下载HTML');
        await logProcessingStep('正在下载网页内容...');
        String htmlContent = '';
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            htmlContent = response.body;
            print('[IntentLog]   下载成功，内容长度: ${htmlContent.length}');
            await logProcessingStep('网页下载成功');
          } else {
            htmlContent = '下载失败: HTTP ${response.statusCode}';
            print('[IntentLog]   下载失败: ${response.statusCode}');
            await logProcessingStep('下载失败: ${response.statusCode}');
          }
        } catch (e) {
          htmlContent = '下载失败: $e';
          print('[IntentLog]   下载异常: $e');
          await logProcessingStep('下载异常: $e');
        }

        // 5. 转换HTML为Markdown
        print('[IntentLog] 5/8 - 正在转换HTML为Markdown');
        await logProcessingStep('正在转换内容格式...');
        final markdownContent = convertHtmlToMarkdown(htmlContent);
        print('[IntentLog]   转换后长度: ${markdownContent.length}');
        
        // 6. 使用LLM生成标题（如果失败使用默认标题）
        print('[IntentLog] 6/8 - 正在生成标题');
        await logProcessingStep('正在生成标题...');
        String title = '分享内容';
        try {
          title = await generateTitleWithLlm(markdownContent);
          print('[IntentLog]   标题: $title');
          await logProcessingStep('标题生成: $title');
        } catch (e) {
          title = '分享内容 ${DateTime.now().toString().substring(0, 16)}';
          print('[IntentLog]   标题生成失败: $e，使用默认标题');
          await logProcessingStep('使用默认标题');
        }
        
        // 7. 创建目录和文件
        print('[IntentLog] 7/8 - 正在创建文件');
        await logProcessingStep('正在保存文件...');
        final inboxDir = await getInboxDirectory();
        final cleanTitle = _sanitizeFileName(title);
        final itemDir = Directory(p.join(inboxDir.path, cleanTitle));
        
        // 如果目录已存在，添加时间戳
        if (await itemDir.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final itemDirWithTimestamp = Directory(p.join(inboxDir.path, '${cleanTitle}_$timestamp'));
          await itemDirWithTimestamp.create(recursive: true);
          print('[IntentLog]   目录已存在，添加时间戳: $timestamp');
        } else {
          await itemDir.create(recursive: true);
          print('[IntentLog]   创建目录: ${itemDir.path}');
        }

        // 保存HTML文件
        final htmlFile = File(p.join(itemDir.path, 'index.html'));
        await htmlFile.writeAsString(htmlContent);
        print('[IntentLog]   保存HTML文件: ${htmlFile.path}');

        // 保存Markdown文件
        final mdFile = File(p.join(itemDir.path, 'content.md'));
        await mdFile.writeAsString(markdownContent);
        print('[IntentLog]   保存Markdown文件: ${mdFile.path}');

        // 8. 创建InboxItem
        print('[IntentLog] 8/8 - 正在保存到数据库');
        await logProcessingStep('正在保存到收件箱...');
        final item = InboxItem(
          title: title,
          source: source,
          url: url,
          filePath: itemDir.path,
          content: markdownContent,
          createdAt: DateTime.now(),
        );

        final id = await _dbHelper.insertInboxItem(item);
        print('[IntentLog] ========== 处理完成 ==========');
        await logProcessingStep('处理完成！内容已保存到收件箱');
        return item.copyWith(id: id);
      } else {
        // 没有URL，直接保存文本
        print('[IntentLog] 4/8 - 直接保存文本');
        await logProcessingStep('正在保存文本内容...');
        final title = '分享内容 ${DateTime.now().toString().substring(0, 16)}';
        print('[IntentLog]   标题: $title');
        final result = await processSimpleContent(title, intentData.text);
        print('[IntentLog] ========== 处理完成 ==========');
        await logProcessingStep('处理完成！文本已保存到收件箱');
        return result;
      }
    } catch (e, stackTrace) {
      // 如果intent解析失败，尝试直接从jsonString提取文本
      print('[IntentLog] ========== 处理异常 ==========');
      print('[IntentLog] 异常: $e');
      print('[IntentLog] 堆栈: $stackTrace');
      await logProcessingStep('处理异常: $e，使用简单模式保存');
      
      final title = '分享内容 ${DateTime.now().toString().substring(0, 16)}';
      final result = await processSimpleContent(title, jsonString);
      print('[IntentLog] ========== 简单模式保存完成 ==========');
      await logProcessingStep('已保存到收件箱（简单模式）');
      return result;
    }
  }

  // 从文本中提取URL
  String _extractUrl(String text) {
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(text);
    return match?.group(0) ?? '';
  }

  // 保存剪贴板内容 - 新方法
  Future<InboxItem> saveClipboardContent(String content) async {
    print('[ClipboardService] ========== 开始处理剪贴板内容 ==========');
    
    try {
      // 从内容中提取URL
      final url = _extractUrl(content);
      print('[ClipboardService] 提取URL: $url');
      
      // 根据URL识别来源
      String source = '未知';
      if (url.isNotEmpty) {
        source = _identifySource(url);
        print('[ClipboardService] 识别来源: $source');
      }
      
      // 生成标题
      print('[ClipboardService] 统计剪贴板条目数量...');
      int clipboardCount = 1;
      final existingItems = await _dbHelper.getAllInboxItems();
      for (final item in existingItems) {
        if (item.title.startsWith('来自粘贴板')) {
          clipboardCount++;
        }
      }
      final title = '来自粘贴板$clipboardCount';
      print('[ClipboardService] 生成标题: $title');
      
      // 创建目录
      print('[ClipboardService] 创建目录...');
      final inboxDir = await getInboxDirectory();
      final cleanTitle = _sanitizeFileName(title);
      final itemDir = Directory(p.join(inboxDir.path, cleanTitle));
      
      // 如果目录已存在，添加时间戳
      if (await itemDir.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newItemDir = Directory(p.join(inboxDir.path, '${cleanTitle}_$timestamp'));
        await newItemDir.create(recursive: true);
      } else {
        await itemDir.create(recursive: true);
      }
      
      // 先保存原始剪贴板内容为Markdown
      print('[ClipboardService] 保存原始剪贴板内容...');
      final mdFile = File(p.join(itemDir.path, 'content.md'));
      await mdFile.writeAsString(content);
      print('[ClipboardService] Markdown文件保存位置: ${mdFile.path}');
      
      // 保存HTML文件（初始为空）
      final htmlFile = File(p.join(itemDir.path, 'index.html'));
      await htmlFile.writeAsString('');
      print('[ClipboardService] HTML文件保存位置: ${htmlFile.path}');
      
      // 创建收件箱条目
      print('[ClipboardService] 创建收件箱条目...');
      InboxItem item = InboxItem(
        title: title,
        source: source,
        url: url,
        filePath: itemDir.path,
        content: content,
        createdAt: DateTime.now(),
      );
      
      final id = await _dbHelper.insertInboxItem(item);
      item = item.copyWith(id: id);
      print('[ClipboardService] 初始保存完成，来源: ${item.source}');
      
      // 尝试从内容中提取URL并下载网页
      if (url.isNotEmpty) {
        print('[ClipboardService] 开始下载网页内容...');
        
        try {
          // 尝试下载网页HTML
          final response = await http.get(Uri.parse(url));
          print('[ClipboardService] HTTP状态码: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final htmlContent = response.body;
            print('[ClipboardService] 网页下载成功，长度: ${htmlContent.length}');
            
            // 提取outerText（纯文本内容）
            final document = html_parser.parse(htmlContent);
            final outerText = document.body?.text ?? '';
            print('[ClipboardService] ==================== OuterText内容开始 ====================');
            
            // 打印前2000个字符
            final previewLength = outerText.length > 2000 ? 2000 : outerText.length;
            print('[ClipboardService] ${outerText.substring(0, previewLength)}');
            if (outerText.length > 2000) {
              print('[ClipboardService] ...(内容被截断，剩余 ${outerText.length - 2000} 字符)');
            }
            print('[ClipboardService] ==================== OuterText内容结束 ====================');
            
            // 检查outerText内容是否包含预期关键词
            final containsLaoShe = outerText.contains('老舍');
            final containsMao = outerText.contains('猫');
            print('[ClipboardService] 包含"老舍": $containsLaoShe, 包含"猫": $containsMao');
            
            // 保存HTML文件
            await htmlFile.writeAsString(htmlContent);
            print('[ClipboardService] HTML文件已保存');
            
            // 同时也保存到content.md，方便预览
            await mdFile.writeAsString(outerText);
            
            // 更新条目内容为outerText
            item = item.copyWith(
              content: outerText,
              url: url,
            );
            
            await _dbHelper.updateInboxItem(item);
            print('[ClipboardService] 条目已更新，包含outerText内容');
          } else {
            print('[ClipboardService] 下载失败，HTTP状态码: ${response.statusCode}');
          }
        } catch (e, stackTrace) {
          print('[ClipboardService] 下载网页出错: $e');
          print('[ClipboardService] 错误堆栈: $stackTrace');
        }
      } else {
        print('[ClipboardService] 未检测到URL');
      }
      
      print('[ClipboardService] ========== 处理完成 ==========');
      return item;
    } catch (e, stackTrace) {
      print('[ClipboardService] ❌ 处理剪贴板内容出错');
      print('[ClipboardService] 错误: $e');
      print('[ClipboardService] 堆栈: $stackTrace');
      rethrow;
    }
  }
  
  // 根据URL识别来源
  String _identifySource(String url) {
    print('[ClipboardService] 识别来源，URL: $url');
    
    // 定义AI应用域名映射
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
      print('[ClipboardService] 解析主机名: $host');
      
      // 提取一级域名（去掉www.前缀）
      String mainDomain = host;
      if (mainDomain.startsWith('www.')) {
        mainDomain = mainDomain.substring(4);
      }
      print('[ClipboardService] 一级域名: $mainDomain');
      
      // 查找匹配
      for (final entry in sourceDomains.entries) {
        if (mainDomain.contains(entry.key) || host.contains(entry.key)) {
          print('[ClipboardService] 匹配到来源: ${entry.value}');
          return entry.value;
        }
      }
      
      // 尝试提取一级域名进行匹配
      final parts = mainDomain.split('.');
      if (parts.length >= 2) {
        final topDomain = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
        print('[ClipboardService] 尝试顶级域名: $topDomain');
        
        for (final entry in sourceDomains.entries) {
          if (topDomain == entry.key || topDomain.endsWith('.${entry.key}')) {
            print('[ClipboardService] 匹配到来源: ${entry.value}');
            return entry.value;
          }
        }
      }
      
      print('[ClipboardService] 未匹配到已知来源');
      return '未知';
    } catch (e) {
      print('[ClipboardService] 解析域名出错: $e');
      return '未知';
    }
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

  // 创建处理中的剪贴板条目
  Future<InboxItem?> createPendingClipboardItem(String url) async {
    print('[ClipboardService] 创建处理中的剪贴板条目');
    
    try {
      // 识别来源
      final source = _identifySource(url);
      
      // 生成标题
      final existingItems = await _dbHelper.getAllInboxItems();
      int clipboardCount = 1;
      for (final item in existingItems) {
        if (item.title.startsWith('来自粘贴板')) {
          clipboardCount++;
        }
      }
      final title = '来自粘贴板$clipboardCount';
      
      // 创建收件箱条目（处理中状态）- 不先创建目录，让WebViewExtractor来创建）
      InboxItem item = InboxItem(
        title: title,
        source: source,
        url: url,
        filePath: '', // 先留空，WebViewExtractor会更新
        content: '正在处理中...',
        status: '处理中',
        createdAt: DateTime.now(),
      );
      
      final id = await _dbHelper.insertInboxItem(item);
      item = item.copyWith(id: id);
      print('[ClipboardService] 创建处理中条目完成: ${item.title}');
      
      return item;
    } catch (e) {
      print('[ClipboardService] 创建处理中条目失败: $e');
      return null;
    }
  }

  // 更新剪贴板条目内容
  Future<void> updateClipboardItemWithContent(int id, String jsonResult) async {
    print('[ClipboardService] ========== 更新剪贴板条目 ==========');
    print('[ClipboardService] 更新剪贴板条目内容，ID: $id');
    print('[ClipboardService] JSON长度: ${jsonResult.length}');
    
    try {
      print('[ClipboardService] 开始解析JSON');
      final result = jsonDecode(jsonResult) as Map<String, dynamic>;
      print('[ClipboardService] JSON解析成功');
      
      final title = result['title'] as String? ?? '未命名';
      final filePath = result['filePath'] as String?;
      final htmlFile = result['htmlFile'] as String?;
      final textContent = result['textContent'] as String? ?? '';
      final url = result['url'] as String? ?? '';
      
      print('[ClipboardService] 解析结果:');
      print('[ClipboardService]   标题: $title');
      print('[ClipboardService]   文件路径: $filePath');
      print('[ClipboardService]   URL: $url');
      print('[ClipboardService]   HTML长度: ${textContent.length}');
      
      // 获取现有条目
      print('[ClipboardService] 开始查询现有条目');
      final existingItem = await _dbHelper.getInboxItemById(id);
      if (existingItem == null) {
        print('[ClipboardService] ❌ 条目不存在: $id');
        return;
      }
      print('[ClipboardService] ✅ 找到现有条目: ${existingItem.title}');
      
      // 更新条目标题和内容
      print('[ClipboardService] 准备更新条目');
      final updatedItem = existingItem.copyWith(
        title: title,
        content: textContent,
        filePath: filePath,
        url: url,
        status: '未整理',
      );
      
      print('[ClipboardService] 执行数据库更新');
      await _dbHelper.updateInboxItem(updatedItem);
      print('[ClipboardService] ✅ 条目更新完成，状态: 未整理');
      print('[ClipboardService] ========== 更新完成 ==========');
    } catch (e) {
      print('[ClipboardService] ❌ 更新条目失败: $e');
      print('[ClipboardService] ========== 更新失败 ==========');
      // 更新为失败状态
      await updateItemStatus(id, 'error');
    }
  }

  // 更新条目状态
  Future<void> updateItemStatus(int id, String status) async {
    try {
      final item = await _dbHelper.getInboxItemById(id);
      if (item != null) {
        final updatedItem = item.copyWith(status: status);
        await _dbHelper.updateInboxItem(updatedItem);
        print('[ClipboardService] 条目状态更新: $status');
      }
    } catch (e) {
      print('[ClipboardService] 更新状态失败: $e');
    }
  }
}
