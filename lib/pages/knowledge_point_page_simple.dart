import 'dart:convert';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';
import '../components/dynamic_tag_selector.dart';
import '../components/tag_styles.dart';
import '../components/generic_filter_dialog.dart';
import '../database/db_helper.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/knowledge_outline.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
import '../database/models/error_record.dart';
import '../services/llm_service.dart';
import 'knowledge_outline_page.dart';
import 'knowledge_point_detail_page.dart';

class KnowledgePointPageSimple extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;
  
  /// 统一的消息发送回调（委托给 MainScreen）
  final void Function(ChatMessage)? onSendMessage;

  const KnowledgePointPageSimple({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
    this.onSendMessage,
  });

  @override
  State<KnowledgePointPageSimple> createState() => _KnowledgePointPageSimpleState();
}

class _KnowledgePointPageSimpleState extends State<KnowledgePointPageSimple> {
  List<KnowledgePoint> _allPoints = [];
  List<KnowledgePoint> _displayPoints = [];
  final Set<int> _selectedIds = {};
  
  // 筛选条件
  Set<String> _filterCategories = {};
  Set<String> _filterUnitNumbers = {};
  Set<String> _filterLessonNumbers = {};
  Set<String> _filterErrorTimes = {};
  Set<String> _filterTestTimes = {};
  
  // 匹配模式
  MatchMode _filterCategoryMatchMode = MatchMode.hierarchical;
  MatchMode _filterUnitMatchMode = MatchMode.contains;
  MatchMode _filterLessonMatchMode = MatchMode.contains;
  MatchMode _filterErrorTimesMatchMode = MatchMode.equals;
  MatchMode _filterTestTimesMatchMode = MatchMode.equals;
  late KnowledgePointDao _knowledgePointDao;
  late QuestionDao _exerciseDao;
  late TestDao _testDao;
  late ErrorRecordDao _errorRecordDao;
  final LlmService _llmService = LlmService();
  bool _isGenerating = false;
  bool _isCleaning = false;
  
  // 统计数据缓存
  Map<String, int> _exerciseCountByCid = {};
  Map<String, int> _errorCountByCid = {};

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _knowledgePointDao = KnowledgePointDao(db);
    _exerciseDao = QuestionDao(db);
    _testDao = TestDao(db);
    _errorRecordDao = ErrorRecordDao(db);
    await _llmService.init();
    await _loadPoints();
    await _loadStatistics();
  }
  
  Future<void> _loadStatistics() async {
    final exercises = await _exerciseDao.getAll();
    final errorRecords = await _errorRecordDao.getAll();
    
    Map<String, int> exerciseCount = {};
    Map<String, int> errorCount = {};
    
    // 统计习题中各类别的出现次数
    for (final ex in exercises) {
      if (ex.category != null) {
        exerciseCount[ex.category!] = (exerciseCount[ex.category!] ?? 0) + 1;
      }
    }
    
    // 统计错题中各类别的出现次数
    for (final record in errorRecords) {
      if (record.eids.isNotEmpty) {
        // 每个错类都统计一次
        for (final eid in record.eids) {
          errorCount[eid] = (errorCount[eid] ?? 0) + 1;
        }
      }
    }
    
    setState(() {
      _exerciseCountByCid = exerciseCount;
      _errorCountByCid = errorCount;
    });
  }

  @override
  void dispose() {
    // LlmService is singleton and has no dispose method
    super.dispose();
  }

  Future<void> _loadPoints() async {
    final points = await _knowledgePointDao.getAll(lang: widget.lang);
    setState(() {
      _allPoints = points;
      _applyFilter();
    });
  }

  bool _matches(String value, Set<String> filters, MatchMode mode) {
    if (value.isEmpty || filters.isEmpty) return true;
    
    for (final filter in filters) {
      switch (mode) {
        case MatchMode.hierarchical:
          if (value == filter || value.startsWith('$filter.')) {
            return true;
          }
          break;
        case MatchMode.contains:
          if (value.contains(filter)) {
            return true;
          }
          break;
        case MatchMode.equals:
          if (value == filter) {
            return true;
          }
          break;
        case MatchMode.greaterThan: {
          final numValue = num.tryParse(value);
          final numFilter = num.tryParse(filter);
          if (numValue != null && numFilter != null && numValue > numFilter) {
            return true;
          }
          break;
        }
        case MatchMode.lessThan: {
          final numValue = num.tryParse(value);
          final numFilter = num.tryParse(filter);
          if (numValue != null && numFilter != null && numValue < numFilter) {
            return true;
          }
          break;
        }
        case MatchMode.greaterOrEqual: {
          final numValue = num.tryParse(value);
          final numFilter = num.tryParse(filter);
          if (numValue != null && numFilter != null && numValue >= numFilter) {
            return true;
          }
          break;
        }
        case MatchMode.lessOrEqual: {
          final numValue = num.tryParse(value);
          final numFilter = num.tryParse(filter);
          if (numValue != null && numFilter != null && numValue <= numFilter) {
            return true;
          }
          break;
        }
      }
    }
    return false;
  }

  void _applyFilter() {
    _displayPoints = _allPoints.where((p) {
      if (_filterCategories.isNotEmpty && p.cid != null) {
        if (!_matches(p.cid!, _filterCategories, _filterCategoryMatchMode)) return false;
      } else if (_filterCategories.isNotEmpty && p.cid == null) {
        return false;
      }
      
      if (_filterUnitNumbers.isNotEmpty && p.unitNumber != null) {
        if (!_matches(p.unitNumber!, _filterUnitNumbers, _filterUnitMatchMode)) return false;
      } else if (_filterUnitNumbers.isNotEmpty && p.unitNumber == null) {
        return false;
      }
      
      if (_filterLessonNumbers.isNotEmpty && p.lessonNumber != null) {
        if (!_matches(p.lessonNumber!, _filterLessonNumbers, _filterLessonMatchMode)) return false;
      } else if (_filterLessonNumbers.isNotEmpty && p.lessonNumber == null) {
        return false;
      }
      
      if (_filterErrorTimes.isNotEmpty) {
        if (!_matches(p.errorTimes.toString(), _filterErrorTimes, _filterErrorTimesMatchMode)) return false;
      }
      
      if (_filterTestTimes.isNotEmpty) {
        if (!_matches(p.testTimes.toString(), _filterTestTimes, _filterTestTimesMatchMode)) return false;
      }
      
      return true;
    }).toList();
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '知识谱' : 'Spectrum')) {
      _showSpectrumDialog();
    } else if (tab == (widget.lang == 'cn' ? '大纲' : 'Outline')) {
      // 直接导航到知识点大纲页面（替代原来的对话框方式）
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KnowledgeOutlinePage(
            lang: widget.lang,
          ),
        ),
      );
      // 从大纲页面返回后重新加载数据
      await _loadPoints();
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      await _generateExercisesFromKnowledgePoint();
    }
  }

  /// 根据选中的知识点条目，使用LLM生成练习题
  Future<void> _generateExercisesFromKnowledgePoint() async {
    // 获取所有选中的知识点
    List<KnowledgePoint> selectedPoints = [];
    
    if (_selectedIds.isNotEmpty) {
      selectedPoints = _displayPoints.where((p) => _selectedIds.contains(p.id)).toList();
    } else if (_displayPoints.isNotEmpty) {
      // 如果没有选中，使用第一条作为默认
      selectedPoints = [_displayPoints.first];
    }

    if (selectedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '暂无知识点，无法生成练习' : 'No knowledge points available')),
      );
      return;
    }

    if (_isGenerating) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习生成进行中...' : 'Exercise generation in progress')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 合并所有选中知识点的内容
      StringBuffer combinedContent = StringBuffer();
      for (final point in selectedPoints) {
        combinedContent.writeln('【${point.title}】');
        if (point.cid != null) combinedContent.writeln('分类：${point.cid}');
        if (point.unitNumber != null) combinedContent.writeln('单元：${point.unitNumber}');
        if (point.brief != null) combinedContent.writeln('简介：${point.brief}');
        combinedContent.writeln('');
      }

      final prompt = '''你是一位语文教育专家。请根据以下主题知识点内容，出一组综合练习题。

主题知识点（共${selectedPoints.length}个）：
${combinedContent.toString()}

要求：
1. 出填空题2题（针对核心概念，如字词、成语、古诗文等）
2. 出选择题5题（每题A/B/C/D四个选项，考查语文基础知识）
3. 题目要覆盖所有选中知识点的关键内容
4. 只出语文学科题目，不要涉及数学、物理、化学等其他学科

请以如下JSON数组格式回复（只回复JSON，不要其他文字）：
[
  {
    "type": "fill_blank" 或 "multiple_choice",
    "question": "题目内容",
    "options": null 或 ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "correctAnswer": "答案",
    "explanation": "解析",
    "knowledgeTag": "所属知识点标题"
  },
  ...
]

注意：
- question 字段是完整的题目描述（如：填写正确的汉字、补充完整诗句等）
- options 字段对于选择题是 A/B/C/D 选项数组，填空题为 null
- correctAnswer 是简短的答案（如：正确的字、成语、诗句等）
- explanation 是详细的解题思路
- knowledgeTag 标识该题目属于哪个知识点
- 请严格按照格式输出7道题目的JSON数组
''';

      final response = await _llmService.generateResponse(prompt);
      
      if (response['success'] != true || response['response'] == null) {
        throw Exception('LLM响应失败');
      }

      final jsonResponse = response['response'] as String;
      
      // 解析JSON
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        throw Exception('未找到JSON数组');
      }

      final List<dynamic> exercisesJson = json.decode(jsonMatch.group(0)!);

      // 批量插入习题集
      int createdCount = 0;
      int skippedCount = 0;
      int expectedCount = 7; // 期望生成7道题

      // 先创建一个 Test 记录
      final nextTidNum = await _testDao.nextTidNumber();
      final tid = 'T$nextTidNum';
      final testTitle = selectedPoints.map((p) => p.title).join(' + ');
      final kids = selectedPoints.map((p) => 'K${p.id}').where((k) => k != null).map((k) => k!).toList();
      
      await _testDao.insert(Test(
        tid: tid,
        title: widget.lang == 'cn' ? '$testTitle 练习' : '$testTitle Practice',
        lessonUnitList: selectedPoints.map((p) => p.unitNumber ?? '').where((u) => u.isNotEmpty).toList(),
        kids: kids,
        status: '未开始',
        createdAt: DateTime.now(),
        lang: widget.lang,
      ));

      for (final exData in exercisesJson) {
        // 验证题目数据是否有效
        if (!_validateExerciseData(exData)) {
          skippedCount++;
          print('[GenerateExercises] 跳过无效题目: $exData');
          continue;
        }
        
        KnowledgePoint pointForExercise = selectedPoints[0];
        if (exData['knowledgeTag'] != null) {
          final matched = selectedPoints.firstWhere(
            (p) => p.title == exData['knowledgeTag'],
            orElse: () => selectedPoints[0],
          );
          pointForExercise = matched;
        }
        
        String category = '';
        final type = exData['type']?.toString().toLowerCase();
        if (type == 'fill_blank') {
          category = '填空题';
        } else if (type == 'multiple_choice') {
          category = '选择题';
        } else {
          category = '填空题';
        }
        
        String questionText = exData['question'] ?? '';
        if (type == 'multiple_choice' && exData['options'] != null) {
          final options = exData['options'] as List;
          questionText = '${questionText}\n\n${options.join('\n')}';
        }

        final question = Question(
          tid: tid,
          question: questionText,
          correctAnswer: exData['correctAnswer'] as String?,
          explanation: exData['explanation'] as String?,
          category: category,
          progress: '未答题',
          source: '知识点',
          contentPath: pointForExercise.contentPath,
          createdAt: DateTime.now(),
          lang: widget.lang,
          kid: pointForExercise.id != null ? 'K${pointForExercise.id}' : null,
          unitNumber: pointForExercise.unitNumber != null ? int.tryParse(pointForExercise.unitNumber!) : null,
          lessonNumber: pointForExercise.lessonNumber != null ? int.tryParse(pointForExercise.lessonNumber!) : null,
        );

        await _exerciseDao.insert(question);
        createdCount++;
      }

      if (skippedCount > 0 && createdCount < expectedCount) {
        createdCount += await _generateSupplementalExercises(
          selectedPoints, 
          expectedCount - createdCount,
          tid
        );
      }

      final cnSubjectLabel = widget.lang == 'cn' ? '个知识点' : 'knowledge points';
      if (mounted) {
        String message = widget.lang == 'cn' 
            ? '已从${selectedPoints.length}$cnSubjectLabel生成$createdCount道练习题并添加到习题集'
            : 'Generated $createdCount exercises from ${selectedPoints.length}$cnSubjectLabel and added to exercise set';
        
        if (skippedCount > 0) {
          message += widget.lang == 'cn' 
              ? '（跳过无效题目$skippedCount道）' 
              : ' (skipped $skippedCount invalid questions)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      
      final now = DateTime.now();
      for (final point in selectedPoints) {
        if (point.id != null) {
          await _knowledgePointDao.updateLastPracticeTime(point.id!, now);
        }
      }
      
      await _loadPoints();
    } catch (e) {
      print('[GenerateExercises] 生成失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' ? '生成练习失败: ${e.toString()}' : 'Failed to generate exercises: ${e.toString()}',
          )),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  bool _validateExerciseData(dynamic exData) {
    if (exData == null) return false;
    
    // 检查必需字段
    final question = exData['question'];
    final correctAnswer = exData['correctAnswer'];
    
    if (question == null || question.toString().trim().isEmpty) {
      return false;
    }
    
    if (correctAnswer == null || correctAnswer.toString().trim().isEmpty) {
      return false;
    }
    
    // 检查选择题是否有选项
    final type = exData['type']?.toString().toLowerCase();
    if (type == 'multiple_choice') {
      final options = exData['options'];
      if (options == null || 
          options is! List || 
          options.length != 4) {
        return false;
      }
      
      for (final opt in options) {
        if (opt == null || opt.toString().trim().isEmpty) {
          return false;
        }
      }
    }
    
    return true;
  }

  Future<int> _generateSupplementalExercises(List<KnowledgePoint> selectedPoints, int count, String tid) async {
    if (count <= 0) return 0;
    
    print('[GenerateExercises] 尝试补充生成 $count 道题目');
    
    try {
      StringBuffer combinedContent = StringBuffer();
      for (final point in selectedPoints) {
        combinedContent.writeln('【${point.title}】');
        if (point.cid != null) combinedContent.writeln('分类：${point.cid}');
        if (point.brief != null) combinedContent.writeln('简介：${point.brief}');
        combinedContent.writeln('');
      }

      final prompt = '''你是一位语文教育专家。请根据以下主题知识点内容，出${count}道练习题。

主题知识点：
${combinedContent.toString()}

要求：
1. 题目类型可以是填空题或选择题
2. 选择题需要包含A/B/C/D四个选项
3. 题目要覆盖知识点的关键内容
4. 只出语文学科题目

请以如下JSON数组格式回复（只回复JSON，不要其他文字）：
[
  {
    "type": "fill_blank" 或 "multiple_choice",
    "question": "题目内容",
    "options": null 或 ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "correctAnswer": "答案",
    "explanation": "解析",
    "knowledgeTag": "所属知识点标题"
  }
]
''';

      final response = await _llmService.generateResponse(prompt);
      
      if (response['success'] != true || response['response'] == null) {
        return 0;
      }

      final jsonResponse = response['response'] as String;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        return 0;
      }

      final List<dynamic> exercisesJson = json.decode(jsonMatch.group(0)!);
      int createdCount = 0;

      for (final exData in exercisesJson) {
        if (!_validateExerciseData(exData)) continue;
        
        KnowledgePoint pointForExercise = selectedPoints[0];
        if (exData['knowledgeTag'] != null) {
          final matched = selectedPoints.firstWhere(
            (p) => p.title == exData['knowledgeTag'],
            orElse: () => selectedPoints[0],
          );
          pointForExercise = matched;
        }
        
        String category = '';
        final type = exData['type']?.toString().toLowerCase();
        if (type == 'fill_blank') {
          category = '填空题';
        } else if (type == 'multiple_choice') {
          category = '选择题';
        } else {
          category = '填空题';
        }
        
        String questionText = exData['question'] ?? '';
        if (type == 'multiple_choice' && exData['options'] != null) {
          final options = exData['options'] as List;
          questionText = '${questionText}\n\n${options.join('\n')}';
        }

        final question = Question(
          tid: tid,
          question: questionText,
          correctAnswer: exData['correctAnswer'] as String?,
          explanation: exData['explanation'] as String?,
          category: category,
          progress: '未答题',
          source: '知识点',
          contentPath: pointForExercise.contentPath,
          createdAt: DateTime.now(),
          lang: widget.lang,
          kid: pointForExercise.id != null ? 'K${pointForExercise.id}' : null,
          unitNumber: pointForExercise.unitNumber != null ? int.tryParse(pointForExercise.unitNumber!) : null,
          lessonNumber: pointForExercise.lessonNumber != null ? int.tryParse(pointForExercise.lessonNumber!) : null,
        );

        await _exerciseDao.insert(question);
        createdCount++;
        
        if (createdCount >= count) break;
      }

      print('[GenerateExercises] 成功补充生成 $createdCount 道题目');
      return createdCount;
    } catch (e) {
      print('[GenerateExercises] 补充生成失败: $e');
      return 0;
    }
  }

  Future<void> _toggleMastered(KnowledgePoint point) async {
    final newTestTimes = (point.testTimes ?? 0) + 1;
    final updated = point.copyWith(testTimes: newTestTimes);
    await _knowledgePointDao.update(updated);
    await _loadPoints();
  }

  List<KnowledgePoint> _rootPoints = [];
  KnowledgePoint? _currentParentPoint;
  List<KnowledgePoint> _childrenPoints = [];
  List<KnowledgePoint> _spectrumResults = []; // 知识谱筛选结果
  bool _showSpectrumMode = false; // 是否处于知识谱筛选模式

  Future<void> _loadRootNodes() async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    final allPoints = await dao.getAll(lang: widget.lang);
    setState(() {
      _rootPoints = allPoints;
      _currentParentPoint = null;
      _childrenPoints = [];
      _showSpectrumMode = false;
      _spectrumResults = [];
    });
  }

  Future<void> _loadChildrenOf(KnowledgePoint point) async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    final allPoints = await dao.getAll(lang: widget.lang);
    setState(() {
      _currentParentPoint = point;
      _childrenPoints = allPoints.where((p) => p.cid == point.cid).toList();
    });
  }

  /// 执行知识谱筛选：根据选中的知识点，获取同分类的知识点
  Future<void> _executeSpectrumFilter(KnowledgePoint selectedPoint) async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    
    final allPoints = await dao.getAll(lang: widget.lang);
    
    // 获取同分类的知识点
    final results = allPoints.where((p) => p.cid == selectedPoint.cid).toList();

    setState(() {
      _spectrumResults = results;
      _showSpectrumMode = true;
      _displayPoints = results;
    });

    Navigator.pop(context); // 关闭弹窗
  }

  void _showSpectrumDialog() {
    showDialog(
      context: context,
      builder: (context) => _SpectrumSearchDialog(
        lang: widget.lang,
        allPoints: _allPoints,
        onPointSelected: _executeSpectrumFilter,
      ),
    );
  }

  void _showFilterDialog() async {
    final categories = _allPoints.map((p) => p.cid).whereType<String>().toSet();
    final unitNumbers = _allPoints.map((p) => p.unitNumber).whereType<String>().toSet();
    final lessonNumbers = _allPoints.map((p) => p.lessonNumber).whereType<String>().toSet();
    final errorTimes = _allPoints.map((p) => p.errorTimes.toString()).toSet();
    final testTimes = _allPoints.map((p) => p.testTimes.toString()).toSet();

    final config = FilterConfig(
      filterTypes: ['cid', 'unit', 'lesson', 'errorTimes', 'testTimes'],
      typeConfigs: {
        'cid': FilterTypeConfig(
          options: categories.map((c) => FilterOption(value: c, label: c)).toList(),
          initialValues: _filterCategories,
          label: widget.lang == 'cn' ? '知识点分类' : 'Category',
          hintText: widget.lang == 'cn' ? '输入分类ID（如1.1）...' : 'Enter category ID...',
          defaultMatchMode: MatchMode.hierarchical,
        ),
        'unit': FilterTypeConfig(
          options: unitNumbers.map((u) => FilterOption(value: u, label: u)).toList(),
          initialValues: _filterUnitNumbers,
          label: widget.lang == 'cn' ? '单元号' : 'Unit Number',
          hintText: widget.lang == 'cn' ? '输入单元号...' : 'Enter unit number...',
          defaultMatchMode: MatchMode.contains,
        ),
        'lesson': FilterTypeConfig(
          options: lessonNumbers.map((l) => FilterOption(value: l, label: l)).toList(),
          initialValues: _filterLessonNumbers,
          label: widget.lang == 'cn' ? '课号' : 'Lesson Number',
          hintText: widget.lang == 'cn' ? '输入课号...' : 'Enter lesson number...',
          defaultMatchMode: MatchMode.contains,
        ),
        'errorTimes': FilterTypeConfig(
          options: errorTimes.map((e) => FilterOption(value: e, label: e)).toList(),
          initialValues: _filterErrorTimes,
          label: widget.lang == 'cn' ? '错误次数' : 'Error Count',
          hintText: widget.lang == 'cn' ? '输入错误次数...' : 'Enter error count...',
          defaultMatchMode: MatchMode.equals,
          isNumeric: true,
        ),
        'testTimes': FilterTypeConfig(
          options: testTimes.map((t) => FilterOption(value: t, label: t)).toList(),
          initialValues: _filterTestTimes,
          label: widget.lang == 'cn' ? '测试次数' : 'Test Count',
          hintText: widget.lang == 'cn' ? '输入测试次数...' : 'Enter test count...',
          defaultMatchMode: MatchMode.equals,
          isNumeric: true,
        ),
      },
    );

    final result = await GenericFilterDialog.show(context, config: config, lang: widget.lang);

    if (result != null) {
      setState(() {
        _filterCategories = Set<String>.from((result['cid'] as Map?)?['values'] ?? {});
        _filterUnitNumbers = Set<String>.from((result['unit'] as Map?)?['values'] ?? {});
        _filterLessonNumbers = Set<String>.from((result['lesson'] as Map?)?['values'] ?? {});
        _filterErrorTimes = Set<String>.from((result['errorTimes'] as Map?)?['values'] ?? {});
        _filterTestTimes = Set<String>.from((result['testTimes'] as Map?)?['values'] ?? {});
        
        _filterCategoryMatchMode = MatchMode.values[(result['cid'] as Map?)?['matchMode'] as int? ?? 0];
        _filterUnitMatchMode = MatchMode.values[(result['unit'] as Map?)?['matchMode'] as int? ?? 0];
        _filterLessonMatchMode = MatchMode.values[(result['lesson'] as Map?)?['matchMode'] as int? ?? 0];
        _filterErrorTimesMatchMode = MatchMode.values[(result['errorTimes'] as Map?)?['matchMode'] as int? ?? 0];
        _filterTestTimesMatchMode = MatchMode.values[(result['testTimes'] as Map?)?['matchMode'] as int? ?? 0];
        
        _applyFilter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '知识谱', '大纲', '练习']
        : ['Filter', 'Spectrum', 'Outline', 'Practice'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-知识点' : 'My AI Language Tutor - Knowledge',
            ),
            AIReplyBar(
              lang: widget.lang,
              messages: widget.onSendMessage != null ? [] : null,
              topic: 'knowledge',
              onPullDown: widget.onPullDown ?? () {},
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _displayPoints.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无知识点' : 'No knowledge points'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayPoints.length,
                        itemBuilder: (context, index) {
                          final point = _displayPoints[index];
                          return _buildKnowledgePointItem(point);
                        },
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: _handleTabSelected,
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
            InputArea(
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgePointItem(KnowledgePoint point) {
    final isSelected = _selectedIds.contains(point.id);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showPointDetail(point),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(point.id!);
                    } else {
                      _selectedIds.remove(point.id!);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.kid != null 
                          ? '${point.kid}.${point.title}' 
                          : point.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (point.unitNumber != null || point.lessonNumber != null)
                          TagStyles.lessonUnitTag(
                            '${point.unitNumber != null ? '${point.unitNumber}单元' : ''}'
                            '${point.unitNumber != null && point.lessonNumber != null ? ' ' : ''}'
                            '${point.lessonNumber != null ? '${point.lessonNumber}课' : ''}',
                          ),
                        if (point.cid != null)
                          TagStyles.knowledgeTag('分类: ${point.cid}'),
                        if (point.cid != null && _exerciseCountByCid[point.cid!] != null && _exerciseCountByCid[point.cid!]! > 0)
                          TagStyles.exerciseTag('同类考过${_exerciseCountByCid[point.cid!]}次'),
                        if (point.cid != null && _errorCountByCid[point.cid!] != null && _errorCountByCid[point.cid!]! > 0)
                          TagStyles.errorTypeTag('同类错${_errorCountByCid[point.cid!]}次'),
                        if ((point.testTimes ?? 0) > 0)
                          TagStyles.exerciseTag('测试${point.testTimes}次'),
                        if (point.lastPracticeTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              _formatTime(point.lastPracticeTime!),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPointDetail(KnowledgePoint point) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KnowledgePointDetailPage(
          lang: widget.lang,
          point: point,
          knowledgePointDao: _knowledgePointDao,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
  }
}

/// 知识谱搜索对话框 - 支持 cid/关键词模糊匹配
class _SpectrumSearchDialog extends StatefulWidget {
  final String lang;
  final List<KnowledgePoint> allPoints;
  final Future<void> Function(KnowledgePoint) onPointSelected;

  const _SpectrumSearchDialog({
    required this.lang,
    required this.allPoints,
    required this.onPointSelected,
  });

  @override
  State<_SpectrumSearchDialog> createState() => _SpectrumSearchDialogState();
}

class _SpectrumSearchDialogState extends State<_SpectrumSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<KnowledgePoint> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // 延迟执行搜索，避免频繁查询
    Future.delayed(const Duration(milliseconds: 300), () async {
      final db = await DatabaseHelper().database;
      final pointDao = KnowledgePointDao(db);
      
      // 根据 keyword 模糊匹配 title 或 brief
      List<KnowledgePoint> results = await pointDao.getAll(lang: widget.lang, keyword: query);
      
      // 搜索大纲表
      final outlineDao = KnowledgeOutlineDao(db);
      final outlines = await outlineDao.getAll(lang: widget.lang);
      
      // 1. 如果查询看起来像 cid（如 1.1, 2.3.1），查找匹配的 cid
      List<String> matchedCids = [];
      if (_looksLikeCid(query)) {
        matchedCids = outlines
            .where((o) => o.cid.startsWith(query) || o.cid == query)
            .map((o) => o.cid)
            .toList();
      } else {
        // 2. 如果不是 cid 格式，搜索大纲内容
        final matchedOutlines = outlines
            .where((o) => o.content.contains(query))
            .toList();
        
        // 获取匹配大纲的 cid，以及所有子级 cid
        for (final outline in matchedOutlines) {
          matchedCids.add(outline.cid);
          // 查找所有子级大纲
          final childCids = outlines
              .where((o) => o.cid.startsWith('${outline.cid}.') && o.cid != outline.cid)
              .map((o) => o.cid)
              .toList();
          matchedCids.addAll(childCids);
        }
      }
      
      // 如果找到匹配的大纲 cid，获取对应的知识点
      if (matchedCids.isNotEmpty) {
        for (final cid in matchedCids) {
          final pointsByCid = await pointDao.getByCid(cid, lang: widget.lang);
          results.addAll(pointsByCid);
        }
      }
      
      setState(() {
        _searchResults = results.toSet().toList(); // 去重
        _isSearching = false;
      });
    });
  }

  bool _looksLikeCid(String query) {
    // 检测是否看起来像 cid 格式（如 1, 1.1, 1.1.1 等）
    return RegExp(r'^\d+(\.\d+)*$').hasMatch(query);
  }

  @override
  Widget build(BuildContext context) {
    final confirmText = widget.lang == 'cn' ? '确定' : 'Confirm';
    final cancelText = widget.lang == 'cn' ? '取消' : 'Cancel';
    final placeholderText = widget.lang == 'cn' 
        ? '输入 CID（如 1.1）或关键词...' 
        : 'Enter CID (e.g., 1.1) or keyword...';

    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱搜索' : 'Knowledge Spectrum Search'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索输入框
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: placeholderText,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty && _searchResults.isNotEmpty) {
                  widget.onPointSelected(_searchResults.first);
                }
              },
            ),
            const SizedBox(height: 8),
            // 搜索结果下拉列表
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _searchResults.isEmpty
                    ? const Center(
                        child: Text('暂无结果', style: TextStyle(color: Colors.grey)),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _searchResults.map((point) {
                            return InkWell(
                              onTap: () {
                                widget.onPointSelected(point);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // CID 标签
                                    if (point.cid != null && point.cid!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          point.cid!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (point.cid != null && point.cid!.isNotEmpty)
                                      const SizedBox(width: 8),
                                    // 标题
                                    Expanded(
                                      child: Text(
                                        point.title,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: _searchResults.isNotEmpty
              ? () => widget.onPointSelected(_searchResults.first)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF69B4),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
