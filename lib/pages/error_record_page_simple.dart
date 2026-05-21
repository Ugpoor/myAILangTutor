import 'dart:convert';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/dynamic_tag_selector.dart';
import '../database/db_helper.dart';
import '../database/models/error_record.dart';
import '../database/models/exercise.dart';
import '../database/models/chat_message.dart';
import '../database/models/portfolio_item.dart';
import '../services/llm_service.dart';
import '../services/app_service.dart';
import 'error_detail_page.dart';
import 'error_record_grouped_view.dart';
import 'hierarchical_error_view.dart';

class ErrorRecordPageSimple extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const ErrorRecordPageSimple({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<ErrorRecordPageSimple> createState() => _ErrorRecordPageSimpleState();
}

class _ErrorRecordPageSimpleState extends State<ErrorRecordPageSimple> {
  List<ErrorRecord> _allRecords = [];
  List<ErrorRecord> _displayRecords = [];
  final Set<int> _selectedIds = {};
  String? _filterErrorType;
  Set<String> _filterKnowledgeTags = {};
  Set<String> _filterProgressSet = {};
  
  Set<String> get _allErrorTypes => {
        ..._allRecords.map((r) => r.errorType).whereType<String>(),
        '审题不清', '概念混淆', '计算失误', '知识遗漏', '推理错误', '表达不当',
      };
  
  String _errorTypeOutline = '''1. 审题
  1.1 关键词忽略
  1.2 会错题意
2. 计算
  2.1 粗心
  2.2 公式错误
3. 概念
  3.1 理解错误
  3.2 混淆概念
4. 表达
  4.1 语句不通
  4.2 用词不当''';
  
  // ===== 视图排序相关 =====
  int _viewMode = 0;
  bool _inGroupedView = false;
  late ErrorRecordDao _errorRecordDao;

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _errorRecordDao = ErrorRecordDao(db);
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _errorRecordDao.getAll(lang: widget.lang);
    
    // 自动标记已订正：除备注外，其他关键字段都有内容则标记为"已订正"
    for (final record in records) {
      if (record.progress == '待订正') {
        final hasAllContent = 
            (record.question != null && record.question!.isNotEmpty) &&
            (record.wrongAnswer != null && record.wrongAnswer!.isNotEmpty) &&
            (record.wrongWhere != null && record.wrongWhere!.isNotEmpty) &&
            (record.whyWrong != null && record.whyWrong!.isNotEmpty) &&
            (record.howPrevent != null && record.howPrevent!.isNotEmpty) &&
            (record.correctAnswer != null && record.correctAnswer!.isNotEmpty);
        
        if (hasAllContent) {
          final updated = record.copyWith(progress: '已订正');
          await _errorRecordDao.update(updated);
        }
      }
    }
    
    final updatedRecords = await _errorRecordDao.getAll(lang: widget.lang);
    setState(() {
      _allRecords = updatedRecords;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<ErrorRecord> filtered = _allRecords.where((r) {
      if (_filterErrorType != null && r.errorType != _filterErrorType) return false;
      if (_filterKnowledgeTags.isNotEmpty && !_filterKnowledgeTags.any((tag) => r.kid?.contains(tag) ?? false)) return false;
      if (_filterProgressSet.isNotEmpty && !_filterProgressSet.contains(r.progress)) return false;
      return true;
    }).toList();
    
    // Apply view mode sorting after filter
    switch (_viewMode) {
      case 0: // 按知识点大纲排列（errorType→kid分组）
        filtered.sort((a, b) {
          final typeA = a.errorType ?? '';
          final typeB = b.errorType ?? '';
          if (typeA != typeB) return typeA.compareTo(typeB);
          final tagA = a.kid ?? '';
          final tagB = b.kid ?? '';
          return tagA.compareTo(tagB);
        });
        break;
      case 1: // 按习题标号排列（qid升序）
        filtered.sort((a, b) {
          final tagA = a.qid ?? '';
          final tagB = b.qid ?? '';
          if (tagA.isEmpty && tagB.isEmpty) {
            return (a.id ?? 0).compareTo(b.id ?? 0);
          }
          if (tagA.isEmpty) return 1;
          if (tagB.isEmpty) return -1;
          final numA = _extractNumberFromTag(tagA);
          final numB = _extractNumberFromTag(tagB);
          if (numA != null && numB != null) return numA.compareTo(numB);
          return tagA.compareTo(tagB);
        });
        break;
      default: // 按错题标号排列（errorId升序）
        filtered.sort((a, b) {
          final idA = a.errorId ?? '';
          final idB = b.errorId ?? '';
          if (idA.isEmpty && idB.isEmpty) {
            return (a.id ?? 0).compareTo(b.id ?? 0);
          }
          if (idA.isEmpty) return 1;
          if (idB.isEmpty) return -1;
          final numA = _extractNumberFromTag(idA);
          final numB = _extractNumberFromTag(idB);
          if (numA != null && numB != null) return numA.compareTo(numB);
          return idA.compareTo(idB);
        });
    }
    _displayRecords = filtered;
  }

  int? _extractNumberFromTag(String tag) {
    final match = RegExp(r'(\d+)').firstMatch(tag);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '视图' : 'View')) {
      _showHierarchicalView();
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      await _generateExercisesForSelectedWithLLM();
    } else if (tab == (widget.lang == 'cn' ? '错类' : 'Error Type')) {
      _showOutlineDialog();
    }
  }
  /// 重置错误本：清空所有数据并重新插入6条语文学科示例数据
  Future<void> navigateToDetail(ErrorRecord record) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ErrorDetailPage(
          lang: widget.lang,
          record: record,
          errorRecordDao: _errorRecordDao,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
    if (result == true) {
      await _loadRecords();
    }
  }

  void _showHierarchicalView() {
    // 按错类和知识点分组
    Map<String, Map<String, List<ErrorRecord>>> grouped = {};
    for (final record in _allRecords) {
      final errorType = record.errorType ?? '未分类';
      final kid = record.kid ?? '未分类';
      
      grouped.putIfAbsent(errorType, () => {});
      grouped[errorType]![kid] = 
          (grouped[errorType]![kid] ?? []) + [record];
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HierarchicalErrorView(
          lang: widget.lang,
          groupedData: grouped,
          allRecords: _allRecords,
          dao: _errorRecordDao,
          onHomeTap: widget.onHomeTap,
          onUpdate: () => _loadRecords(),
        ),
      ),
    );
  }

  void _showViewDialog() {
    final labels = widget.lang == 'cn' 
        ? ['知识点大纲', '习题标号', '错题标号']
        : ['Knowledge Outline', 'Exercise No.', 'Error No.'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '错误本视图' : 'Error Record View'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lang == 'cn' ? '请选择排列方式：' : 'Select sorting mode:'),
            const SizedBox(height: 8),
            ...labels.asMap().entries.map((entry) {
              return RadioListTile<int>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: _viewMode,
                onChanged: (value) {
                  setState(() {
                    _viewMode = value!;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    ).then((_) {
      _applyFilter();
    });
  }

  /// 根据选中错误记录，使用LLM生成练习题
  Future<void> _generateExercisesForSelectedWithLLM() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择错误条目' : 'Select error records first')),
      );
      return;
    }

    // 显示加载弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('习题生成中...', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );

    final db = await DatabaseHelper().database;
    
    // 声明在外层，以便在 catch 块中也能访问
    late int loadingMsgId;
    
    try {
      // 插入"习题生成中"的AI消息（直接使用数据库，不依赖 AppService）
      final chatMsgDao = ChatMessageDao(db);
      loadingMsgId = await chatMsgDao.insert(ChatMessage(
        content: widget.lang == 'cn' ? '习题生成中...' : 'Generating exercises...',
        isUser: false,
        createdAt: DateTime.now(),
        lang: widget.lang,
      ));

      final exerciseDao = ExerciseDao(db);
      final llmService = LlmService();
      await llmService.init();

      final selectedRecords = _allRecords.where((r) => _selectedIds.contains(r.id)).toList();
      final errorContent = selectedRecords.map((r) {
        return '${r.errorId} ${r.question ?? r.content}\n错因：${r.whyWrong ?? ''}\n预防：${r.howPrevent ?? ''}';
      }).join('\n\n');

      final prompt = '''你是一位语文教育专家。请根据以下错误记录内容，出一组针对性的练习题来帮助学生巩固薄弱知识点。

错误案例分析：
$errorContent

要求：
1. 出填空题2题（针对薄弱知识点，如字词书写、成语使用、古诗文默写等）
2. 出选择题5题（每题A/B/C/D四个选项，考查语文基础知识）
3. 题目要针对错误原因设计，帮助学生避免同类错误
4. 只出语文学科题目，不要涉及数学、物理、化学等其他学科

请以如下JSON数组格式回复（只回复JSON，不要其他文字）：
[
  {
    "type": "fill_blank" 或 "multiple_choice",
    "question": "题目内容",
    "options": null 或 ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "correctAnswer": "答案",
    "explanation": "解析"
  },
  ...
]

注意：
- question 字段是完整的题目描述（如：填写正确的汉字、补充完整诗句、选择正确成语等）
- options 字段对于选择题是 A/B/C/D 选项数组，填空题为 null
- correctAnswer 是简短的答案（如：正确的字、成语、诗句等）
- explanation 是详细的解题思路
- 请严格按照格式输出7道题目的JSON数组
''';

      final response = await llmService.generateResponse(prompt);
      
      if (response['success'] != true || response['response'] == null) {
        throw Exception('LLM响应失败');
      }

      final jsonResponse = response['response'] as String;
      
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        throw Exception('未找到JSON数组');
      }

      final List<dynamic> exercisesJson = json.decode(jsonMatch.group(0)!);
      int createdCount = 0;

      for (final exData in exercisesJson) {
        final nextNum = await exerciseDao.nextExerciseIdNumber();
        
        final exercise = Exercise(
          question: exData['question'] ?? '',
          options: exData['options'] != null 
              ? (exData['options'] as List).join('\n') 
              : null,
          correctAnswer: exData['correctAnswer'] as String?,
          explanation: exData['explanation'] as String?,
          category: '错题',
          difficulty: 1,
          progress: '未答题',
          source: '错误本',
          contentPath: selectedRecords.first.contentPath,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );

        await exerciseDao.insert(exercise);
        createdCount++;
      }

      // 更新AI消息为"已完成习题生成"并关闭弹窗
      if (mounted) {
        // 关闭加载弹窗
        Navigator.of(context).pop();
        
        final chatMsgDao = ChatMessageDao(db);
        final completedMsg = ChatMessage(
          id: loadingMsgId,
          content: widget.lang == 'cn' 
              ? '已完成习题生成！已从${selectedRecords.length}条错误记录生成$createdCount道练习题并添加到习题集'
              : 'Exercise generation complete! Generated $createdCount exercises from ${selectedRecords.length} error records.',
          isUser: false,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );
        await chatMsgDao.update(completedMsg);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' 
                ? '已从${selectedRecords.length}条错误记录生成$createdCount道练习题并添加到习题集'
                : 'Generated $createdCount exercises from ${selectedRecords.length} error records',
          )),
        );
      }
    } catch (e) {
      print('[GenerateExercises] 生成失败: $e');
      // 关闭弹窗并显示错误信息
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        
        try {
          final errorChatMsgDao = ChatMessageDao(db);
          final errorMsg = ChatMessage(
            id: loadingMsgId,
            content: widget.lang == 'cn' 
                ? '生成练习失败: ${e.toString()}'
                : 'Failed to generate exercises: ${e.toString()}',
            isUser: false,
            createdAt: DateTime.now(),
            lang: widget.lang,
          );
          await errorChatMsgDao.update(errorMsg);
        } catch (_) {
          // 忽略更新失败（可能 loadingMsgId 无效）
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' ? '生成练习失败: ${e.toString()}' : 'Failed to generate exercises: ${e.toString()}',
          )),
        );
      }
    } finally {
      setState(() => _selectedIds.clear());
    }
  }

  void _showFilterDialog() {
    Set<String> selectedKnowledgeTags = Set<String>.from(_filterKnowledgeTags);
    Set<String> selectedProgresses = Set<String>.from(_filterProgressSet);
    String? tempErrorType = _filterErrorType;
    
    // 获取所有可用的知识点标签和进度选项
    final allKnowledgeTags = _allRecords.map((r) => r.kid).whereType<String>().toSet();
    final allProgresses = {'待订正', '已订正'};

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(widget.lang == 'cn' ? '筛选错误记录' : 'Filter Error Records'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 错类筛选（下拉选择）
                  Text(widget.lang == 'cn' ? '按错类：' : 'By error type:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonFormField<String?>(
                      value: tempErrorType,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部 / All'),
                        ),
                        ..._allErrorTypes.map((type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => tempErrorType = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 知识点标签筛选（使用动态标签选择器）
                  DynamicTagSelector(
                    label: widget.lang == 'cn' ? '知识点标签' : 'Knowledge tags',
                    currentTags: selectedKnowledgeTags,
                    availableOptions: allKnowledgeTags,
                    onTagsChanged: (newTags) {
                      setState(() => selectedKnowledgeTags = newTags);
                    },
                    accentColor: const Color(0xFF2196F3),
                  ),
                  const SizedBox(height: 16),
                  // 进度筛选（使用动态标签选择器）
                  DynamicTagSelector(
                    label: widget.lang == 'cn' ? '进度' : 'Progress',
                    currentTags: selectedProgresses,
                    availableOptions: allProgresses,
                    onTagsChanged: (newTags) {
                      setState(() => selectedProgresses = newTags);
                    },
                    accentColor: const Color(0xFFFF9800),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filterErrorType = null;
                  _filterKnowledgeTags.clear();
                  _filterProgressSet.clear();
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              child: Text(widget.lang == 'cn' ? '清空' : 'Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterErrorType = tempErrorType;
                  _filterKnowledgeTags = selectedKnowledgeTags;
                  _filterProgressSet = selectedProgresses;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF69B4)),
              child: Text(widget.lang == 'cn' ? '确定' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOutlineDialog() {
    final controller = TextEditingController(text: _errorTypeOutline);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '错类大纲' : 'Error Type Outline'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: (text) => _errorTypeOutline = text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _errorTypeOutline = controller.text;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.lang == 'cn' ? '大纲已保存' : 'Outline saved')),
              );
            },
            child: Text(widget.lang == 'cn' ? '保存' : 'Save'),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(String progress) {
    switch (progress) {
      case '待订正':
        return const Color(0xFFFFA07A);
      case '已订正':
        return const Color(0xFF90EE90);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果处于分组汇总视图模式，显示全屏分组视图（替换所有正常UI）
    if (_inGroupedView) {
      return ErrorRecordGroupedView(
        lang: widget.lang,
        allRecords: _displayRecords,
        dao: _errorRecordDao,
        onHomeTap: widget.onHomeTap,
        onCancel: () => setState(() => _inGroupedView = false),
      );
    }

    final tabs = widget.lang == 'cn'
        ? ['筛选', '视图', '练习', '错类']
        : ['Filter', 'View', 'Practice', 'Error Type'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-错误本' : 'My AI Language Tutor - Error Book',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'error',
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
                child: _displayRecords.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无错误记录' : 'No error records'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayRecords.length,
                        itemBuilder: (context, index) {
                          final record = _displayRecords[index];
                          return _buildErrorRecordItem(record);
                        },
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: _selectedIds.isNotEmpty 
                  ? (widget.lang == 'cn' ? '练习' : 'Practice')
                  : '',
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

  Widget _buildErrorRecordItem(ErrorRecord record) {
    final isSelected = _selectedIds.contains(record.id);
    final progressColor = _getProgressColor(record.progress);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => navigateToDetail(record),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(record.id!);
                    } else {
                      _selectedIds.remove(record.id!);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${record.errorId ?? ""} ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5252)),
                        ),
                        Expanded(
                          child: Text(
                            record.question ?? record.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (record.kid != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF87CEEB), borderRadius: BorderRadius.circular(4)),
                            child: Text('知识: ${record.kid}', style: const TextStyle(fontSize: 11)),
                          ),
                        if (record.errorType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFA07A), borderRadius: BorderRadius.circular(4)),
                            child: Text(record.errorType!, style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
                          ),
                        if (record.qid != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF98FB98), borderRadius: BorderRadius.circular(4)),
                            child: Text('习题: ${record.qid}', style: const TextStyle(fontSize: 11)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: progressColor, borderRadius: BorderRadius.circular(4)),
                          child: Text(record.progress, style: const TextStyle(fontSize: 11)),
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
}
