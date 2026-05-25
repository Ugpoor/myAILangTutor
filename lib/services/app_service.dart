
import '../database/db_helper.dart';
import '../database/models/document.dart';
import '../database/models/todo_item.dart';
import '../database/models/error_record.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/question.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/skill.dart';
import '../database/models/setting.dart';
import '../database/models/chat_message.dart';
import '../database/models/inbox_item.dart';
import '../services/document_manager.dart';
import '../services/llm_service.dart';

enum ViewType {
  home,
  chat,
  inbox,
  errorBook,
  knowledge,
  exercises,
  portfolio,
  skills,
  documentEditor,
  listView,
}

class AppService {
  static final AppService _instance = AppService._internal();
  factory AppService() => _instance;
  AppService._internal();

  DocumentDao? _documentDao;
  TodoDao? _todoDao;
  ErrorRecordDao? _errorRecordDao;
  KnowledgePointDao? _knowledgePointDao;
  QuestionDao? _exerciseDao;
  PortfolioDao? _portfolioDao;
  SkillDao? _skillDao;
  SettingsDao? _settingsDao;
  ChatMessageDao? _chatMessageDao;

  Future<void> init() async {
    final db = await DatabaseHelper().database;
    _documentDao = DocumentDao(db);
    _todoDao = TodoDao(db);
    _errorRecordDao = ErrorRecordDao(db);
    _knowledgePointDao = KnowledgePointDao(db);
    _exerciseDao = QuestionDao(db);
    _portfolioDao = PortfolioDao(db);
    _skillDao = SkillDao(db);
    _settingsDao = SettingsDao(db);
    _chatMessageDao = ChatMessageDao(db);
    try {
      await LlmService().init();
    } catch (e) {
      print('Warning: LlmService.init() failed: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_chatMessageDao == null) {
      await init();
    }
  }

  Future<String> getLanguage() async {
    await _ensureInitialized();
    return await _settingsDao!.get('language') ?? 'cn';
  }

  Future<void> setLanguage(String lang) async {
    await _ensureInitialized();
    await _settingsDao!.set('language', lang);
  }

  Future<List<Document>> getDocuments({String? lang}) async {
    await _ensureInitialized();
    return await _documentDao!.getAll(lang: lang);
  }

  Future<Document?> getDocument(int id) async {
    await _ensureInitialized();
    return await _documentDao!.getById(id);
  }

  Future<int> createDocument(String title, String htmlContent, {
    String? url,
    String? source,
    String lang = 'cn',
    String? category,
  }) async {
    await _ensureInitialized();
    final folderName = await DocumentManager.generateFolderName(title);
    await DocumentManager.saveHtmlContent(folderName, htmlContent);
    
    final document = Document(
      title: title,
      folderName: folderName,
      url: url,
      source: source,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lang: lang,
      category: category,
    );
    
    return await _documentDao!.insert(document);
  }

  Future<int> updateDocument(Document document) async {
    await _ensureInitialized();
    document = document.copyWith(updatedAt: DateTime.now());
    return await _documentDao!.update(document);
  }

  Future<int> deleteDocument(int id) async {
    await _ensureInitialized();
    final document = await _documentDao!.getById(id);
    if (document != null) {
      await DocumentManager.deleteDocumentFolder(document.folderName);
    }
    return await _documentDao!.delete(id);
  }

  Future<List<TodoItem>> getTodoItems({String? lang, bool? completed}) async {
    await _ensureInitialized();
    return await _todoDao!.getAll(lang: lang, completed: completed);
  }

  Future<int> createTodoItem(String title, {
    String? description,
    DateTime? dueDate,
    int priority = 1,
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final todo = TodoItem(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lang: lang,
    );
    return await _todoDao!.insert(todo);
  }

  Future<int> toggleTodoItem(int id) async {
    await _ensureInitialized();
    final todo = await _todoDao!.getById(id);
    if (todo != null) {
      return await _todoDao!.update(todo.copyWith(completed: !todo.completed));
    }
    return 0;
  }

  Future<int> deleteTodoItem(int id) async {
    await _ensureInitialized();
    return await _todoDao!.delete(id);
  }

  Future<List<ErrorRecord>> getErrorRecords({String? lang}) async {
    await _ensureInitialized();
    return await _errorRecordDao!.getAll(lang: lang);
  }

  Future<int> createErrorRecord(String content, {
    String? correctAnswer,
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final record = ErrorRecord(
      wrongWhere: content,
      correctAnswer: correctAnswer,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _errorRecordDao!.insert(record);
  }

  Future<int> markErrorReviewed(int id) async {
    await _ensureInitialized();
    final record = await _errorRecordDao!.getById(id);
    if (record != null) {
      return await _errorRecordDao!.update(record.copyWith(progress: '已订正'));
    }
    return 0;
  }

  Future<List<KnowledgePoint>> getKnowledgePoints({String? lang}) async {
    await _ensureInitialized();
    return await _knowledgePointDao!.getAll(lang: lang);
  }

  Future<int> createKnowledgePoint(String title, {
    String cid = '',
    String contentPath = '',
    String? brief,
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final point = KnowledgePoint(
      title: title,
      cid: cid,
      contentPath: contentPath,
      brief: brief,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _knowledgePointDao!.insert(point);
  }

  Future<int> toggleKnowledgeMastered(int id) async {
    await _ensureInitialized();
    final point = await _knowledgePointDao!.getById(id);
    if (point != null) {
      final newTestTimes = point.testTimes ?? 0;
      return await _knowledgePointDao!.update(point.copyWith(testTimes: newTestTimes + 1));
    }
    return 0;
  }

  Future<List<Question>> getExercises({String? lang, String? category, bool? completed}) async {
    await _ensureInitialized();
    return await _exerciseDao!.getAll(lang: lang, category: category, completed: completed);
  }

  Future<int> createExercise(String question, {
    String? correctAnswer,
    String? explanation,
    String? category,
    int difficulty = 1,
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final exercise = Question(
      question: question,
      correctAnswer: correctAnswer,
      explanation: explanation,
      category: category,
      difficulty: difficulty,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _exerciseDao!.insert(exercise);
  }

  Future<int> markExerciseCompleted(int id) async {
    await _ensureInitialized();
    final exercise = await _exerciseDao!.getById(id);
    if (exercise != null) {
      return await _exerciseDao!.update(exercise.copyWith(completed: true));
    }
    return 0;
  }

  Future<List<PortfolioItem>> getPortfolioItems({String? lang}) async {
    await _ensureInitialized();
    return await _portfolioDao!.getAll(lang: lang);
  }

  Future<int> createPortfolioItem(String title, {
    String? contentPath,
    bool isOriginal = false,
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final item = PortfolioItem(
      title: title,
      contentPath: contentPath,
      isOriginal: isOriginal,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _portfolioDao!.insert(item);
  }

  Future<List<Skill>> getSkills({String? lang}) async {
    await _ensureInitialized();
    return await _skillDao!.getAll(lang: lang);
  }

  Future<int> createSkill(String name, {
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final skill = Skill(
      name: name,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _skillDao!.insert(skill);
  }

  Future<int> updateSkillProgress(int id, double progress) async {
    await _ensureInitialized();
    final skill = await _skillDao!.getById(id);
    if (skill != null) {
      return await _skillDao!.update(skill);
    }
    return 0;
  }

  Future<List<ChatMessage>> getChatMessages({String? lang}) async {
    await _ensureInitialized();
    return await _chatMessageDao!.getAll(lang: lang);
  }

  Future<int> sendMessage(String content, {String lang = 'cn'}) async {
    await _ensureInitialized();
    final userMessage = ChatMessage(
      content: content,
      isUser: true,
      createdAt: DateTime.now(),
      lang: lang,
    );
    await _chatMessageDao!.insert(userMessage);

    final llmResponse = await LlmService().generateResponse(content);
    
    final aiMessage = ChatMessage(
      content: llmResponse['response'] ?? '',
      reasoning: llmResponse['reasoning'] ?? '',
      isUser: false,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _chatMessageDao!.insert(aiMessage);
  }

  Future<Map<String, dynamic>> sendMessageWithTools(String content, {String lang = 'cn'}) async {
    await _ensureInitialized();
    final tools = [
      {
        'type': 'function',
        'function': {
          'name': 'get_weather',
          'description': '获取指定城市的天气信息',
          'parameters': {
            'type': 'object',
            'properties': {
              'city': {
                'type': 'string',
                'description': '城市名称',
              },
            },
            'required': ['city'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_knowledge',
          'description': '获取语言学习知识点',
          'parameters': {
            'type': 'object',
            'properties': {
              'topic': {
                'type': 'string',
                'description': '知识点主题',
              },
              'lang': {
                'type': 'string',
                'description': '语言类型: cn 或 en',
              },
            },
            'required': ['topic'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'query_dictionary',
          'description': '查询字词释义、成语解释、古诗文翻译',
          'parameters': {
            'type': 'object',
            'properties': {
              'word': {
                'type': 'string',
                'description': '要查询的字词或成语',
              },
            },
            'required': ['word'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'navigate_to',
          'description': '导航到指定页面',
          'parameters': {
            'type': 'object',
            'properties': {
              'page': {
                'type': 'string',
                'description': '页面名称: home, chat, inbox, errorBook, knowledge, exercises, portfolio, skills',
              },
            },
            'required': ['page'],
          },
        },
      },
    ];

    final llmResponse = await LlmService().generateResponseWithTools(content, tools: tools, toolChoice: true);
    
    if (llmResponse['success'] == true) {
      final userMessage = ChatMessage(
        content: content,
        isUser: true,
        createdAt: DateTime.now(),
        lang: lang,
      );
      await _chatMessageDao!.insert(userMessage);

      final aiMessage = ChatMessage(
        content: llmResponse['response'] ?? '',
        reasoning: llmResponse['reasoning'] ?? '',
        isUser: false,
        createdAt: DateTime.now(),
        lang: lang,
      );
      await _chatMessageDao!.insert(aiMessage);
    }

    return llmResponse;
  }

  Future<int> clearChatMessages() async {
    await _ensureInitialized();
    await _chatMessageDao!.clear();
    return 0;
  }

  Future<int> insertChatMessage({
    required String content,
    required bool isUser,
    String lang = 'cn',
  }) async {
    await _ensureInitialized();
    final message = ChatMessage(
      content: content,
      isUser: isUser,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _chatMessageDao!.insert(message);
  }

  Future<Map<String, dynamic>> testLlmConnection() async {
    return await LlmService().generateResponse('hello');
  }

  Future<Map<String, dynamic>> testToolCall(String prompt) async {
    return await LlmService().testToolCall(prompt);
  }

  Future<String> _generateSummary(String content, String instruction) async {
    final prompt = '''$instruction

内容：
$content

请提供简洁的摘要，不超过200字。''';

    try {
      final response = await LlmService().generateResponse(prompt);
      return (response['response'] as String).trim();
    } catch (e) {
      print('生成摘要失败: $e');
      return content.length > 200 ? content.substring(0, 200) + '...' : content;
    }
  }

  Future<Map<String, dynamic>> convertInboxToErrorRecord(InboxItem inboxItem, {
    String? customSubject,
    String? customLesson,
  }) async {
    await _ensureInitialized();
    try {
      final summary = await _generateSummary(
        inboxItem.content,
        '请将以下内容作为错题进行简要总结，提取题目、答案和解析要点：',
      );

      final nextNum = await _errorRecordDao!.nextErrorIdNumber();
      final errorRecord = ErrorRecord(
        errorId: 'T$nextNum',
        wrongWhere: summary,
        correctAnswer: null,
        createdAt: inboxItem.createdAt,
        lang: 'cn',
      );

      final id = await _errorRecordDao!.insert(errorRecord);
      return {
        'success': true,
        'id': id,
        'message': '成功转换为错题本记录',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '转换失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> convertInboxToKnowledgePoint(InboxItem inboxItem, {
    String cid = '',
  }) async {
    await _ensureInitialized();
    try {
      final summary = await _generateSummary(
        inboxItem.content,
        '请将以下内容作为知识点进行简要总结：',
      );

      final knowledgePoint = KnowledgePoint(
        title: inboxItem.title,
        cid: cid,
        contentPath: inboxItem.filePath ?? '',
        brief: summary,
        createdAt: inboxItem.createdAt,
        lang: 'cn',
      );

      final id = await _knowledgePointDao!.insert(knowledgePoint);
      return {
        'success': true,
        'id': id,
        'message': '成功转换为知识点',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '转换失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> convertInboxToExercise(InboxItem inboxItem, {
    String? customCategory,
    int customDifficulty = 1,
  }) async {
    await _ensureInitialized();
    try {
      final summary = await _generateSummary(
        inboxItem.content,
        '请将以下内容作为练习题进行简要总结，提取题目和选项：',
      );

      final exercise = Question(
        question: summary,
        correctAnswer: null,
        explanation: null,
        category: customCategory,
        difficulty: customDifficulty,
        completed: false,
        contentPath: inboxItem.filePath,
        createdAt: inboxItem.createdAt,
      );

      final id = await _exerciseDao!.insert(exercise);
      return {
        'success': true,
        'id': id,
        'message': '成功转换为习题',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '转换失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> convertInboxToPortfolioItem(InboxItem inboxItem, {
    String? customType,
  }) async {
    await _ensureInitialized();
    try {
      final portfolioItem = PortfolioItem(
        title: inboxItem.title,
        contentPath: inboxItem.filePath,
        isOriginal: false,
        createdAt: inboxItem.createdAt,
        lang: 'cn',
      );

      final id = await _portfolioDao!.insert(portfolioItem);
      return {
        'success': true,
        'id': id,
        'message': '成功转换为作品集',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '转换失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> cleanExercises() async {
    await _ensureInitialized();
    try {
      final result = await _exerciseDao!.cleanQuestions();
      return {
        'success': true,
        'duplicate_deleted': result['duplicate_deleted'],
        'message': '清理完成：删除重复习题 ${result['duplicate_deleted']} 条',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '清理失败: $e',
      };
    }
  }

  Future<Map<String, dynamic>> autoConvertInboxItem(InboxItem inboxItem, {
    String? suggestedCategory,
  }) async {
    String targetCategory = suggestedCategory ?? '作品集';

    switch (targetCategory) {
      case '错题本':
        return await convertInboxToErrorRecord(inboxItem);
      case '知识点':
        return await convertInboxToKnowledgePoint(inboxItem);
      case '习题集':
        return await convertInboxToExercise(inboxItem);
      case '作品集':
      default:
        return await convertInboxToPortfolioItem(inboxItem);
    }
  }

  Future<void> deleteByContentPath(String contentPath) async {
    await _ensureInitialized();
    
    final knowledgePoints = await _knowledgePointDao!.getAll();
    for (final point in knowledgePoints) {
      if (point.contentPath == contentPath) {
        await _knowledgePointDao!.delete(point.id!);
        return;
      }
    }
    
    final exercises = await _exerciseDao!.getAll();
    for (final exercise in exercises) {
      if (exercise.contentPath == contentPath) {
        await _exerciseDao!.delete(exercise.id!);
        return;
      }
    }
    
    final portfolioItems = await _portfolioDao!.getAll();
    for (final item in portfolioItems) {
      if (item.contentPath == contentPath) {
        await _portfolioDao!.delete(item.id!);
        return;
      }
    }
  }
}
