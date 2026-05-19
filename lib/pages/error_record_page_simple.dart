import 'dart:convert';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../database/db_helper.dart';
import '../database/models/error_record.dart';
import '../database/models/exercise.dart';
import '../services/llm_service.dart';
import 'error_detail_page.dart';

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
  String? _filterKnowledgeTag;
  String? _filterProgress;
  
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
    setState(() {
      _allRecords = records;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<ErrorRecord> filtered = _allRecords.where((r) {
      if (_filterErrorType != null && r.errorType != _filterErrorType) return false;
      if (_filterKnowledgeTag != null &&
          (r.knowledgeTag == null || !r.knowledgeTag!.contains(_filterKnowledgeTag!))) {
        return false;
      }
      if (_filterProgress != null && r.progress != _filterProgress) return false;
      return true;
    }).toList();
    
    // Apply view mode sorting after filter
    switch (_viewMode) {
      case 0: // 按知识点大纲排列（errorType→knowledgeTag分组）
        filtered.sort((a, b) {
          final typeA = a.errorType ?? '';
          final typeB = b.errorType ?? '';
          if (typeA != typeB) return typeA.compareTo(typeB);
          final tagA = a.knowledgeTag ?? '';
          final tagB = b.knowledgeTag ?? '';
          return tagA.compareTo(tagB);
        });
        break;
      case 1: // 按习题标号排列（exerciseTag升序）
        filtered.sort((a, b) {
          final tagA = a.exerciseTag ?? '';
          final tagB = b.exerciseTag ?? '';
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
      _showViewDialog();
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      await _generateExercisesForSelectedWithLLM();
    } else if (tab == (widget.lang == 'cn' ? '错类' : 'Error Type')) {
      _showOutlineDialog();
    }
  }

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

    final db = await DatabaseHelper().database;
    final exerciseDao = ExerciseDao(db);
    final llmService = LlmService();
    await llmService.init();

    final selectedRecords = _allRecords.where((r) => _selectedIds.contains(r.id)).toList();
    final errorContent = selectedRecords.map((r) {
      return '${r.errorId} ${r.question ?? r.content}\n错因：${r.whyWrong ?? ''}\n预防：${r.howPrevent ?? ''}';
    }).join('\n\n');

    try {
      final prompt = '''你是一位教育专家。请根据以下错误记录内容，出一组针对性的练习题来帮助学生巩固薄弱知识点。

错误案例分析：
$errorContent

要求：
1. 出填空题2题（针对薄弱知识点）
2. 出选择题5题（每题A/B/C/D四个选项）
3. 题目要针对错误原因设计，帮助学生避免同类错误
4. 只出与当前错误记录相关的语文题目，不要涉及数学等其他学科

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
- question 字段是完整的题目描述
- options 字段对于选择题是 A/B/C/D 选项数组，填空题为 null
- correctAnswer 是简短的答案
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
          knowledgeTag: selectedRecords.first.knowledgeTag,
          progress: '未答题',
          source: '错误本',
          exerciseId: 'T$nextNum',
          contentPath: selectedRecords.first.contentPath,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );

        await exerciseDao.insert(exercise);
        createdCount++;
      }

      if (mounted) {
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
      if (mounted) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '筛选错误记录' : 'Filter Error Records'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.lang == 'cn' ? '按错类筛选：' : 'By error type:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ['审题不清', '概念混淆', '计算失误', '知识遗漏', '推理错误', '表达不当']
                    .map((t) => ChoiceChip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          selected: _filterErrorType == t,
                          onSelected: (_) {
                            setState(() {
                              _filterErrorType = _filterErrorType == t ? null : t;
                              _applyFilter();
                            });
                            Navigator.pop(context);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text(widget.lang == 'cn' ? '按进度筛选：' : 'By progress:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() { _filterProgress = '待订正'; _applyFilter(); });
                      Navigator.pop(context);
                    },
                    child: Text(widget.lang == 'cn' ? '待订正' : 'Pending'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() { _filterProgress = '已订正'; _applyFilter(); });
                      Navigator.pop(context);
                    },
                    child: Text(widget.lang == 'cn' ? '已订正' : 'Corrected'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterErrorType = null;
                        _filterKnowledgeTag = null;
                        _filterProgress = null;
                        _applyFilter();
                      });
                      Navigator.pop(context);
                    },
                    child: Text(widget.lang == 'cn' ? '全部' : 'All'),
                  ),
                ],
              ),
            ],
          ),
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
                        if (record.lesson != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                            child: Text('课内: ${record.lesson}', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                          ),
                        if (record.knowledgeTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF87CEEB), borderRadius: BorderRadius.circular(4)),
                            child: Text('知识: ${record.knowledgeTag}', style: const TextStyle(fontSize: 11)),
                          ),
                        if (record.errorType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFA07A), borderRadius: BorderRadius.circular(4)),
                            child: Text(record.errorType!, style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
                          ),
                        if (record.exerciseTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF98FB98), borderRadius: BorderRadius.circular(4)),
                            child: Text('习题: ${record.exerciseTag}', style: const TextStyle(fontSize: 11)),
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
