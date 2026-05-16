
import '../database/db_helper.dart';
import '../database/models/document.dart';
import '../database/models/todo_item.dart';
import '../database/models/error_record.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/exercise.dart';
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

  late DocumentDao _documentDao;
  late TodoDao _todoDao;
  late ErrorRecordDao _errorRecordDao;
  late KnowledgePointDao _knowledgePointDao;
  late ExerciseDao _exerciseDao;
  late PortfolioDao _portfolioDao;
  late SkillDao _skillDao;
  late SettingsDao _settingsDao;
  late ChatMessageDao _chatMessageDao;

  Future<void> init() async {
    final db = await DatabaseHelper().database;
    _documentDao = DocumentDao(db);
    _todoDao = TodoDao(db);
    _errorRecordDao = ErrorRecordDao(db);
    _knowledgePointDao = KnowledgePointDao(db);
    _exerciseDao = ExerciseDao(db);
    _portfolioDao = PortfolioDao(db);
    _skillDao = SkillDao(db);
    _settingsDao = SettingsDao(db);
    _chatMessageDao = ChatMessageDao(db);
    try {
      await LlmService().init();
    } catch (e) {
      print('Warning: LlmService.init() failed: $e');
      // 即使 LLM 初始化失败不影响其他功能
    }
  }

  Future<String> getLanguage() async {
    return await _settingsDao.get('language') ?? 'cn';
  }

  Future<void> setLanguage(String lang) async {
    await _settingsDao.set('language', lang);
  }

  Future<List<Document>> getDocuments({String? lang}) async {
    return await _documentDao.getAll(lang: lang);
  }

  Future<Document?> getDocument(int id) async {
    return await _documentDao.getById(id);
  }

  Future<int> createDocument(String title, String htmlContent, {
    String? url,
    String? source,
    String lang = 'cn',
    String? category,
  }) async {
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
    
    return await _documentDao.insert(document);
  }

  Future<int> updateDocument(Document document) async {
    document = document.copyWith(updatedAt: DateTime.now());
    return await _documentDao.update(document);
  }

  Future<int> deleteDocument(int id) async {
    final document = await _documentDao.getById(id);
    if (document != null) {
      await DocumentManager.deleteDocumentFolder(document.folderName);
    }
    return await _documentDao.delete(id);
  }

  Future<List<TodoItem>> getTodoItems({String? lang, bool? completed}) async {
    return await _todoDao.getAll(lang: lang, completed: completed);
  }

  Future<int> createTodoItem(String title, {
    String? description,
    DateTime? dueDate,
    int priority = 1,
    String lang = 'cn',
  }) async {
    final todo = TodoItem(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lang: lang,
    );
    return await _todoDao.insert(todo);
  }

  Future<int> toggleTodoItem(int id) async {
    final todo = await _todoDao.getById(id);
    if (todo != null) {
      return await _todoDao.update(todo.copyWith(completed: !todo.completed));
    }
    return 0;
  }

  Future<int> deleteTodoItem(int id) async {
    return await _todoDao.delete(id);
  }

  Future<List<ErrorRecord>> getErrorRecords({String? lang, bool? reviewed}) async {
    return await _errorRecordDao.getAll(lang: lang, reviewed: reviewed);
  }

  Future<int> createErrorRecord(String content, {
    String? correctAnswer,
    String? subject,
    String? lesson,
    String lang = 'cn',
  }) async {
    final record = ErrorRecord(
      content: content,
      correctAnswer: correctAnswer,
      subject: subject,
      lesson: lesson,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _errorRecordDao.insert(record);
  }

  Future<int> markErrorReviewed(int id) async {
    final record = await _errorRecordDao.getById(id);
    if (record != null) {
      return await _errorRecordDao.update(record.copyWith(reviewed: true));
    }
    return 0;
  }

  Future<List<KnowledgePoint>> getKnowledgePoints({String? lang, String? category}) async {
    return await _knowledgePointDao.getAll(lang: lang, category: category);
  }

  Future<int> createKnowledgePoint(String title, {
    String? content,
    String? category,
    int difficulty = 1,
    String lang = 'cn',
  }) async {
    final point = KnowledgePoint(
      title: title,
      content: content,
      category: category,
      difficulty: difficulty,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _knowledgePointDao.insert(point);
  }

  Future<int> toggleKnowledgeMastered(int id) async {
    final point = await _knowledgePointDao.getById(id);
    if (point != null) {
      return await _knowledgePointDao.update(point.copyWith(mastered: !point.mastered));
    }
    return 0;
  }

  Future<List<Exercise>> getExercises({String? lang, String? category, bool? completed}) async {
    return await _exerciseDao.getAll(lang: lang, category: category, completed: completed);
  }

  Future<int> createExercise(String question, {
    String? options,
    String? correctAnswer,
    String? explanation,
    String? category,
    int difficulty = 1,
    String lang = 'cn',
  }) async {
    final exercise = Exercise(
      question: question,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation,
      category: category,
      difficulty: difficulty,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _exerciseDao.insert(exercise);
  }

  Future<int> markExerciseCompleted(int id) async {
    final exercise = await _exerciseDao.getById(id);
    if (exercise != null) {
      return await _exerciseDao.update(exercise.copyWith(completed: true));
    }
    return 0;
  }

  Future<List<PortfolioItem>> getPortfolioItems({String? lang, String? type}) async {
    return await _portfolioDao.getAll(lang: lang, type: type);
  }

  Future<int> createPortfolioItem(String title, {
    String? type,
    String? contentPath,
    String? thumbnailPath,
    String lang = 'cn',
  }) async {
    final item = PortfolioItem(
      title: title,
      type: type,
      contentPath: contentPath,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _portfolioDao.insert(item);
  }

  Future<List<Skill>> getSkills({String? lang}) async {
    return await _skillDao.getAll(lang: lang);
  }

  Future<int> createSkill(String name, {
    int level = 1,
    double progress = 0,
    String lang = 'cn',
  }) async {
    final skill = Skill(
      name: name,
      level: level,
      progress: progress,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _skillDao.insert(skill);
  }

  Future<int> updateSkillProgress(int id, double progress) async {
    final skill = await _skillDao.getById(id);
    if (skill != null) {
      final updatedSkill = skill.copyWith(
        progress: progress.clamp(0, 100),
        lastPracticed: DateTime.now(),
      );
      if (updatedSkill.progress >= 100 && updatedSkill.level < 10) {
        updatedSkill.copyWith(level: updatedSkill.level + 1, progress: 0);
      }
      return await _skillDao.update(updatedSkill);
    }
    return 0;
  }

  Future<List<ChatMessage>> getChatMessages({String? lang}) async {
    return await _chatMessageDao.getAll(lang: lang);
  }

  Future<int> sendMessage(String content, {String lang = 'cn'}) async {
    final userMessage = ChatMessage(
      content: content,
      isUser: true,
      createdAt: DateTime.now(),
      lang: lang,
    );
    await _chatMessageDao.insert(userMessage);

    final llmResponse = await LlmService().generateResponse(content);
    
    final aiMessage = ChatMessage(
      content: llmResponse['response'] ?? '',
      reasoning: llmResponse['reasoning'] ?? '',
      isUser: false,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _chatMessageDao.insert(aiMessage);
  }

  Future<Map<String, dynamic>> sendMessageWithTools(String content, {String lang = 'cn'}) async {
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
          'name': 'calculate',
          'description': '进行数学计算',
          'parameters': {
            'type': 'object',
            'properties': {
              'expression': {
                'type': 'string',
                'description': '数学表达式',
              },
            },
            'required': ['expression'],
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
      await _chatMessageDao.insert(userMessage);

      final aiMessage = ChatMessage(
        content: llmResponse['response'] ?? '',
        reasoning: llmResponse['reasoning'] ?? '',
        isUser: false,
        createdAt: DateTime.now(),
        lang: lang,
      );
      await _chatMessageDao.insert(aiMessage);
    }

    return llmResponse;
  }

  Future<int> clearChatMessages() async {
    await _chatMessageDao.clear();
    return 0;
  }

  Future<int> insertChatMessage({
    required String content,
    required bool isUser,
    String lang = 'cn',
  }) async {
    final message = ChatMessage(
      content: content,
      isUser: isUser,
      createdAt: DateTime.now(),
      lang: lang,
    );
    return await _chatMessageDao.insert(message);
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
    try {
      final summary = await _generateSummary(
        inboxItem.content,
        '请将以下内容作为错题进行简要总结，提取题目、答案和解析要点：',
      );

      final errorRecord = ErrorRecord(
        content: summary,
        correctAnswer: null,
        subject: customSubject,
        lesson: customLesson,
        contentPath: inboxItem.filePath,
        createdAt: inboxItem.createdAt,
        reviewed: false,
      );

      final id = await _errorRecordDao.insert(errorRecord);
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
    String? customCategory,
    String? customLessonUnit,
    String? customErrorType,
    int customDifficulty = 1,
  }) async {
    try {
      final summary = await _generateSummary(
        inboxItem.content,
        '请将以下内容作为知识点进行简要总结：',
      );

      final knowledgePoint = KnowledgePoint(
        title: inboxItem.title,
        content: summary,
        category: customCategory,
        lessonUnit: customLessonUnit,
        errorType: customErrorType,
        difficulty: customDifficulty,
        mastered: false,
        contentPath: inboxItem.filePath,
        createdAt: inboxItem.createdAt,
      );

      final id = await _knowledgePointDao.insert(knowledgePoint);
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
    try {
      final summary = await _generateSummary(
        inboxItem.content,
        '请将以下内容作为练习题进行简要总结，提取题目和选项：',
      );

      final exercise = Exercise(
        question: summary,
        options: null,
        correctAnswer: null,
        explanation: null,
        category: customCategory,
        difficulty: customDifficulty,
        completed: false,
        contentPath: inboxItem.filePath,
        createdAt: inboxItem.createdAt,
      );

      final id = await _exerciseDao.insert(exercise);
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
    try {
      final portfolioItem = PortfolioItem(
        title: inboxItem.title,
        type: customType ?? '文章',
        contentPath: inboxItem.filePath,
        thumbnailPath: null,
        createdAt: inboxItem.createdAt,
      );

      final id = await _portfolioDao.insert(portfolioItem);
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
    final errorRecords = await _errorRecordDao.getAll();
    for (final record in errorRecords) {
      if (record.contentPath == contentPath) {
        await _errorRecordDao.delete(record.id!);
        return;
      }
    }
    
    final knowledgePoints = await _knowledgePointDao.getAll();
    for (final point in knowledgePoints) {
      if (point.contentPath == contentPath) {
        await _knowledgePointDao.delete(point.id!);
        return;
      }
    }
    
    final exercises = await _exerciseDao.getAll();
    for (final exercise in exercises) {
      if (exercise.contentPath == contentPath) {
        await _exerciseDao.delete(exercise.id!);
        return;
      }
    }
    
    final portfolioItems = await _portfolioDao.getAll();
    for (final item in portfolioItems) {
      if (item.contentPath == contentPath) {
        await _portfolioDao.delete(item.id!);
        return;
      }
    }
  }
}
