import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/dynamic_tag_selector.dart';
import '../components/tag_styles.dart';
import '../components/generic_filter_dialog.dart';
import '../database/db_helper.dart';
import '../database/models/error_record.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
import '../database/models/chat_message.dart';
import '../database/models/portfolio_item.dart';
import '../services/llm_service.dart';
import '../services/app_service.dart';
import 'error_detail_page.dart';
import 'error_record_grouped_view.dart';
import 'hierarchical_error_view.dart';
import 'error_type_outline_page.dart';

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
  Set<String> _filterErrorTypes = {};
  Set<String> _filterKnowledgeTags = {};
  Set<String> _filterProgressSet = {};
  Set<String> _filterExerciseIds = {};
  
  MatchMode _filterErrorTypeMatchMode = MatchMode.hierarchical;
  MatchMode _filterKnowledgeMatchMode = MatchMode.hierarchical;
  MatchMode _filterExerciseMatchMode = MatchMode.contains;
  MatchMode _filterProgressMatchMode = MatchMode.equals;
  
  Set<String> get _allErrorTypes => {
        ..._allRecords.expand((r) => r.eids),
        '1', '1.1', '1.2', '2', '2.1', '2.2', '3', '4', '5', '6',
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
      _displayRecords = _applyFilter();
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

  List<ErrorRecord> _applyFilter() {
    print('[Filter] Applying filters:');
    print('[Filter] errorTypes: $_filterErrorTypes, mode: $_filterErrorTypeMatchMode');
    print('[Filter] knowledgeTags: $_filterKnowledgeTags, mode: $_filterKnowledgeMatchMode');
    print('[Filter] progressSet: $_filterProgressSet, mode: $_filterProgressMatchMode');
    print('[Filter] exerciseIds: $_filterExerciseIds, mode: $_filterExerciseMatchMode');
    print('[Filter] total records: ${_allRecords.length}');
    
    List<ErrorRecord> filtered = _allRecords.where((r) {
      if (_filterErrorTypes.isNotEmpty) {
        bool hasMatchingErrorType = false;
        for (final eid in r.eids) {
          if (_matches(eid, _filterErrorTypes, _filterErrorTypeMatchMode)) {
            hasMatchingErrorType = true;
            break;
          }
        }
        if (!hasMatchingErrorType) return false;
      }
      if (_filterKnowledgeTags.isNotEmpty) {
        if (r.kid != null) {
          if (!_matches(r.kid!, _filterKnowledgeTags, _filterKnowledgeMatchMode)) {
            return false;
          }
        } else {
          return false;
        }
      }
      if (_filterProgressSet.isNotEmpty) {
        final progress = r.progress ?? '';
        if (!_matches(progress, _filterProgressSet, _filterProgressMatchMode)) return false;
      }
      if (_filterExerciseIds.isNotEmpty) {
        final exerciseKey = '${r.tid ?? ''}${r.qid != null ? 'Q${r.qid}' : ''}';
        if (!_matches(exerciseKey, _filterExerciseIds, _filterExerciseMatchMode)) return false;
      }
      return true;
    }).toList();
    
    print('[Filter] filtered records: ${filtered.length}');
    
    // Apply view mode sorting after filter
    switch (_viewMode) {
      case 0: // 按知识点大纲排列（eids→kid分组）
        filtered.sort((a, b) {
          final typeA = a.eids.isNotEmpty ? a.eids[0] : '';
          final typeB = b.eids.isNotEmpty ? b.eids[0] : '';
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
    return filtered;
  }

  int? _extractNumberFromTag(String tag) {
    final match = RegExp(r'(\d+)').firstMatch(tag);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  Future<void> _handleTabSelected(String tab) async {
    final cnFilter = widget.lang == 'cn' ? '筛选' : 'Filter';
    final cnView = widget.lang == 'cn' ? '视图' : 'View';
    final cnPractice = widget.lang == 'cn' ? '练习' : 'Practice';
    final cnErrorType = widget.lang == 'cn' ? '错类' : 'Error Type';
    final cnDelete = widget.lang == 'cn' ? '删除' : 'Delete';
    final cnSelectAll = widget.lang == 'cn' ? '全选' : 'Select All';
    final cnDeselectAll = widget.lang == 'cn' ? '全不选' : 'Deselect All';

    if (tab == cnFilter) {
      _showFilterDialog();
    } else if (tab == cnView) {
      _showViewDialog();
    } else if (tab == cnPractice) {
      await _generateExercisesForSelectedWithLLM();
    } else if (tab == cnErrorType) {
      _showOutlineDialog();
    } else if (tab == cnDelete) {
      await _deleteSelectedRecords();
    } else if (tab == cnSelectAll) {
      setState(() {
        _selectedIds.addAll(_displayRecords.map((r) => r.id!));
      });
    } else if (tab == cnDeselectAll) {
      setState(() {
        _selectedIds.clear();
      });
    }
  }

  /// 批量删除选中的错误记录
  Future<void> _deleteSelectedRecords() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择要删除的条目' : 'Please select items to delete')),
      );
      return;
    }

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(
          widget.lang == 'cn'
              ? '确定要删除选中的 $count 条错误记录吗？此操作不可恢复！'
              : 'Are you sure you want to delete $count selected error records? This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              widget.lang == 'cn' ? '确定删除' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        int deletedCount = 0;
        for (final id in _selectedIds) {
          final result = await _errorRecordDao.delete(id);
          if (result > 0) deletedCount++;
        }
        await _loadRecords();
        setState(() {
          _selectedIds.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              widget.lang == 'cn' ? '已删除 $deletedCount 条记录' : 'Deleted $deletedCount records',
            )),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              widget.lang == 'cn' ? '删除失败: $e' : 'Delete failed: $e',
            )),
          );
        }
      }
    }
  }
  /// 重置错题本：清空所有数据并重新插入6条语文学科示例数据
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
    // 按错类和知识点分组（支持多错类）
    Map<String, Map<String, List<ErrorRecord>>> grouped = {};
    for (final record in _allRecords) {
      final eids = record.eids.isNotEmpty ? record.eids : ['未分类'];
      final kid = record.kid ?? '未分类';
      
      for (final eid in eids) {
        grouped.putIfAbsent(eid, () => {});
        grouped[eid]![kid] = 
            (grouped[eid]![kid] ?? []) + [record];
      }
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
    int? selectedOption;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(widget.lang == 'cn' ? '错题本视图' : 'Error Record View'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: Text(widget.lang == 'cn' ? '错类大纲视图' : 'Error Type Outline'),
                    subtitle: Text(widget.lang == 'cn' ? '按错类大纲分组的层次视图' : 'Hierarchical view grouped by error type'),
                    value: 10,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() => selectedOption = value);
                    },
                  ),
                  RadioListTile<int>(
                    title: Text(widget.lang == 'cn' ? '知识点大纲视图' : 'Knowledge Outline'),
                    subtitle: Text(widget.lang == 'cn' ? '按知识点分组的层次视图' : 'Hierarchical view grouped by knowledge'),
                    value: 11,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() => selectedOption = value);
                    },
                  ),
                  RadioListTile<int>(
                    title: Text(widget.lang == 'cn' ? '习题号汇总视图' : 'Exercise No. Grouped'),
                    subtitle: Text(widget.lang == 'cn' ? '按TnQm汇总的层次视图' : 'Hierarchical view grouped by TnQm'),
                    value: 12,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() => selectedOption = value);
                    },
                  ),
                  const Divider(),
                  RadioListTile<int>(
                    title: Text(widget.lang == 'cn' ? '列表-按错类排序' : 'List - Sort by error type'),
                    value: 0,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() => selectedOption = value);
                    },
                  ),
                  RadioListTile<int>(
                    title: Text(widget.lang == 'cn' ? '列表-按习题标号排序' : 'List - Sort by exercise No.'),
                    value: 1,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() => selectedOption = value);
                    },
                  ),
                  RadioListTile<int>(
                    title: Text(widget.lang == 'cn' ? '列表-按错题标号排序' : 'List - Sort by error No.'),
                    value: 2,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() => selectedOption = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (selectedOption != null) {
                  switch (selectedOption!) {
                    case 10:
                      _showHierarchicalViewByErrorType();
                      break;
                    case 11:
                      _showHierarchicalViewByKnowledge();
                      break;
                    case 12:
                      _showHierarchicalViewByExercise();
                      break;
                    case 0:
                    case 1:
                    case 2:
                      setState(() {
                        _viewMode = selectedOption!;
                        _displayRecords = _applyFilter();
                      });
                      break;
                  }
                }
              },
              child: Text(widget.lang == 'cn' ? '确定' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHierarchicalViewByErrorType() {
    Map<String, List<ErrorRecord>> grouped = {};
    for (final record in _displayRecords) {
      final eids = record.eids.isNotEmpty ? record.eids : ['未分类'];
      for (final eid in eids) {
        grouped.putIfAbsent(eid, () => []).add(record);
      }
    }
    
    List<String> sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '未分类') return 1;
        if (b == '未分类') return -1;
        return a.compareTo(b);
      });
    
    Map<String, Map<String, List<ErrorRecord>>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = {'': grouped[key]!};
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HierarchicalErrorView(
          lang: widget.lang,
          groupedData: sortedGrouped,
          allRecords: _displayRecords,
          dao: _errorRecordDao,
          onHomeTap: widget.onHomeTap,
          onUpdate: () => _loadRecords(),
          viewTitle: widget.lang == 'cn' ? '错类大纲视图' : 'Error Type Outline View',
        ),
      ),
    );
  }

  void _showHierarchicalViewByKnowledge() {
    Map<String, List<ErrorRecord>> grouped = {};
    for (final record in _displayRecords) {
      final kid = record.kid ?? '未分类';
      grouped.putIfAbsent(kid, () => []).add(record);
    }
    
    List<String> sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '未分类') return 1;
        if (b == '未分类') return -1;
        return a.compareTo(b);
      });
    
    Map<String, Map<String, List<ErrorRecord>>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = {'': grouped[key]!};
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HierarchicalErrorView(
          lang: widget.lang,
          groupedData: sortedGrouped,
          allRecords: _displayRecords,
          dao: _errorRecordDao,
          onHomeTap: widget.onHomeTap,
          onUpdate: () => _loadRecords(),
          viewTitle: widget.lang == 'cn' ? '知识点大纲视图' : 'Knowledge Outline View',
        ),
      ),
    );
  }

  void _showHierarchicalViewByExercise() {
    Map<String, List<ErrorRecord>> grouped = {};
    for (final record in _displayRecords) {
      String exerciseKey = '${record.tid ?? ''}${record.qid != null ? 'Q${record.qid}' : ''}';
      if (exerciseKey.isEmpty) exerciseKey = '未分类';
      grouped.putIfAbsent(exerciseKey, () => []).add(record);
    }
    
    List<String> sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '未分类') return 1;
        if (b == '未分类') return -1;
        final numA = _extractNumberFromTag(a);
        final numB = _extractNumberFromTag(b);
        if (numA != null && numB != null) return numA.compareTo(numB);
        return a.compareTo(b);
      });
    
    Map<String, Map<String, List<ErrorRecord>>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = {'': grouped[key]!};
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HierarchicalErrorView(
          lang: widget.lang,
          groupedData: sortedGrouped,
          allRecords: _displayRecords,
          dao: _errorRecordDao,
          onHomeTap: widget.onHomeTap,
          onUpdate: () => _loadRecords(),
          viewTitle: widget.lang == 'cn' ? '习题号汇总视图' : 'Exercise No. View',
        ),
      ),
    );
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

      final exerciseDao = QuestionDao(db);
      final llmService = LlmService();
      await llmService.init();

      final selectedRecords = _allRecords.where((r) => _selectedIds.contains(r.id)).toList();
      final errorContent = selectedRecords.map((r) {
        return '${r.errorId} ${r.question ?? r.wrongWhere ?? ''}\n错因：${r.whyWrong ?? ''}\n预防：${r.howPrevent ?? ''}';
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
      int skippedCount = 0;
      int expectedCount = 7;

      final testDao = TestDao(db);
      final nextNum = await testDao.nextTidNumber();
      final tid = 'T$nextNum';
      
      await testDao.insert(
        Test(
          tid: tid,
          title: widget.lang == 'cn' ? '错题本练习 - 第${nextNum}套' : 'Error Practice - Set $nextNum',
          lessonUnitList: [],
          kids: [],
          images: [],
          status: '未开始',
          createdAt: DateTime.now(),
          lang: widget.lang,
        ),
      );

      for (final exData in exercisesJson) {
        if (!_validateExerciseData(exData)) {
          skippedCount++;
          print('[GenerateExercises] 跳过无效题目: $exData');
          continue;
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
          question: questionText,
          tid: tid,
          exerciseId: tid,
          correctAnswer: exData['correctAnswer'] as String?,
          explanation: exData['explanation'] as String?,
          category: category,
          progress: '未答题',
          source: '错题本',
          createdAt: DateTime.now(),
          lang: widget.lang,
        );

        await exerciseDao.insert(question);
        createdCount++;
      }

      if (skippedCount > 0 && createdCount < expectedCount) {
        createdCount += await _generateSupplementalExercisesForErrors(
          selectedRecords, 
          expectedCount - createdCount,
          db,
          llmService,
          widget.lang,
          tid,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        
        final chatMsgDao = ChatMessageDao(db);
        String message = widget.lang == 'cn' 
            ? '已完成习题生成！已从${selectedRecords.length}条错误记录生成$createdCount道练习题并添加到习题集'
            : 'Exercise generation complete! Generated $createdCount exercises from ${selectedRecords.length} error records.';
        
        if (skippedCount > 0) {
          message += widget.lang == 'cn' 
              ? '（跳过无效题目$skippedCount道）'
              : ' (skipped $skippedCount invalid questions)';
        }
        
        final completedMsg = ChatMessage(
          id: loadingMsgId,
          content: message,
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

  bool _validateExerciseData(dynamic exData) {
    if (exData == null) return false;
    
    final question = exData['question'];
    final correctAnswer = exData['correctAnswer'];
    
    if (question == null || question.toString().trim().isEmpty) {
      return false;
    }
    
    if (correctAnswer == null || correctAnswer.toString().trim().isEmpty) {
      return false;
    }
    
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

  Future<int> _generateSupplementalExercisesForErrors(
    List<ErrorRecord> selectedRecords, 
    int count,
    Database db,
    LlmService llmService,
    String lang,
    String tid,
  ) async {
    if (count <= 0) return 0;
    
    print('[GenerateExercises] 尝试补充生成 $count 道题目');
    
    try {
      final errorContent = selectedRecords.map((r) {
        return '${r.errorId} ${r.question ?? r.wrongWhere ?? ''}\n错因：${r.whyWrong ?? ''}\n预防：${r.howPrevent ?? ''}';
      }).join('\n\n');

      final prompt = '''你是一位语文教育专家。请根据以下错误记录内容，出${count}道针对性的练习题。

错误案例分析：
$errorContent

要求：
1. 题目类型可以是填空题或选择题
2. 选择题需要包含A/B/C/D四个选项
3. 题目要针对错误原因设计
4. 只出语文学科题目

请以如下JSON数组格式回复（只回复JSON，不要其他文字）：
[
  {
    "type": "fill_blank" 或 "multiple_choice",
    "question": "题目内容",
    "options": null 或 ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "correctAnswer": "答案",
    "explanation": "解析"
  }
]
''';

      final response = await llmService.generateResponse(prompt);
      
      if (response['success'] != true || response['response'] == null) {
        return 0;
      }

      final jsonResponse = response['response'] as String;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        return 0;
      }

      final List<dynamic> exercisesJson = json.decode(jsonMatch.group(0)!);
      final exerciseDao = QuestionDao(db);
      int createdCount = 0;

      for (final exData in exercisesJson) {
        if (!_validateExerciseData(exData)) continue;
        
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
          source: '错题本',
          createdAt: DateTime.now(),
          lang: lang,
        );

        await exerciseDao.insert(question);
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

  void _showFilterDialog() async {
    final allErrorTypes = _allErrorTypes.toList()..sort();
    final allKnowledgeTags = _allRecords.map((r) => r.kid).whereType<String>().toList()..sort();
    final allProgresses = ['待订正', '已订正'];
    final allExerciseIds = _allRecords.map((r) {
      return '${r.tid ?? ''}${r.qid != null ? 'Q${r.qid}' : ''}';
    }).where((e) => e.isNotEmpty).toList()..sort();

    final config = FilterConfig(
      filterTypes: ['errorType', 'knowledge', 'exercise', 'progress'],
      typeConfigs: {
        'errorType': FilterTypeConfig(
          options: allErrorTypes.map((e) => FilterOption(value: e, label: e)).toList(),
          initialValues: _filterErrorTypes,
          label: widget.lang == 'cn' ? '错类' : 'Error Type',
          hintText: widget.lang == 'cn' ? '输入ID号（如1.1）或关键词...' : 'Enter ID (e.g., 1.1)...',
          defaultMatchMode: MatchMode.hierarchical,
        ),
        'knowledge': FilterTypeConfig(
          options: allKnowledgeTags.map((k) => FilterOption(value: k, label: k)).toList(),
          initialValues: _filterKnowledgeTags,
          label: widget.lang == 'cn' ? '知识点' : 'Knowledge',
          hintText: widget.lang == 'cn' ? '输入ID号（如K1）或关键词...' : 'Enter ID (e.g., K1)...',
          defaultMatchMode: MatchMode.hierarchical,
        ),
        'exercise': FilterTypeConfig(
          options: allExerciseIds.map((e) => FilterOption(value: e, label: e)).toList(),
          initialValues: _filterExerciseIds,
          label: widget.lang == 'cn' ? '习题号' : 'Exercise',
          hintText: widget.lang == 'cn' ? '输入TnQm格式（如T1Q1）或关键词...' : 'Enter TnQm format (e.g., T1Q1)...',
          defaultMatchMode: MatchMode.contains,
        ),
        'progress': FilterTypeConfig(
          options: allProgresses.map((p) => FilterOption(value: p, label: p)).toList(),
          initialValues: _filterProgressSet,
          label: widget.lang == 'cn' ? '进度' : 'Progress',
          hintText: widget.lang == 'cn' ? '输入关键词（待订正、已订正）...' : 'Enter keyword...',
          defaultMatchMode: MatchMode.equals,
        ),
      },
    );

    final result = await GenericFilterDialog.show(context, config: config, lang: widget.lang);

    if (result != null) {
      setState(() {
        _filterErrorTypes = Set<String>.from((result['errorType'] as Map?)?['values'] ?? {});
        _filterKnowledgeTags = Set<String>.from((result['knowledge'] as Map?)?['values'] ?? {});
        _filterProgressSet = Set<String>.from((result['progress'] as Map?)?['values'] ?? {});
        _filterExerciseIds = Set<String>.from((result['exercise'] as Map?)?['values'] ?? {});
        
        _filterErrorTypeMatchMode = MatchMode.values[(result['errorType'] as Map?)?['matchMode'] as int? ?? 0];
        _filterKnowledgeMatchMode = MatchMode.values[(result['knowledge'] as Map?)?['matchMode'] as int? ?? 0];
        _filterExerciseMatchMode = MatchMode.values[(result['exercise'] as Map?)?['matchMode'] as int? ?? 0];
        _filterProgressMatchMode = MatchMode.values[(result['progress'] as Map?)?['matchMode'] as int? ?? 0];
        
        _displayRecords = _applyFilter();
      });
    }
  }

  Widget _buildSelectedTagsPool(Set<String> errorTypes, Set<String> knowledgeTags,
      Set<String> exerciseIds, Set<String> progresses, Function(String, String) removeTag) {
    List<Widget> chips = [];
    
    chips.addAll(errorTypes.map((tag) => Chip(
      label: Text(tag),
      backgroundColor: const Color(0xFFFFCDD2),
      labelStyle: const TextStyle(color: Color(0xFFC62828)),
      onDeleted: () => removeTag(tag, 'errorType'),
      deleteIconColor: const Color(0xFFC62828),
    )));
    
    chips.addAll(knowledgeTags.map((tag) => Chip(
      label: Text(tag),
      backgroundColor: const Color(0xFFE3F2FD),
      labelStyle: const TextStyle(color: Color(0xFF1565C0)),
      onDeleted: () => removeTag(tag, 'knowledge'),
      deleteIconColor: const Color(0xFF1565C0),
    )));
    
    chips.addAll(exerciseIds.map((tag) => Chip(
      label: Text(tag),
      backgroundColor: const Color(0xFFE8F5E9),
      labelStyle: const TextStyle(color: Color(0xFF1B5E20)),
      onDeleted: () => removeTag(tag, 'exercise'),
      deleteIconColor: const Color(0xFF1B5E20),
    )));
    
    chips.addAll(progresses.map((tag) => Chip(
      label: Text(tag),
      backgroundColor: const Color(0xFFFFF3E0),
      labelStyle: const TextStyle(color: Color(0xFF8D6E63)),
      onDeleted: () => removeTag(tag, 'progress'),
      deleteIconColor: const Color(0xFF8D6E63),
    )));

    if (chips.isEmpty) {
      return Text(
        widget.lang == 'cn' ? '暂无选择' : 'No selection', 
        style: TextStyle(color: Colors.grey[500]),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildFilterTypeButton(String type, String label, String? selected, StateSetter setState) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => type == selected ? selected = null : selected = type),
        style: ElevatedButton.styleFrom(
          backgroundColor: selected == type ? const Color(0xFF2196F3) : Colors.grey[200],
          foregroundColor: selected == type ? Colors.white : Colors.black,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildSelectedTags(String type, Set<String> errorTypes, Set<String> knowledgeTags,
      Set<String> exerciseIds, Set<String> progresses, Function(String, String) removeTag) {
    Set<String> tags;
    Color color;
    switch (type) {
      case 'errorType':
        tags = errorTypes;
        color = const Color(0xFFFFCDD2);
        break;
      case 'knowledge':
        tags = knowledgeTags;
        color = const Color(0xFFE3F2FD);
        break;
      case 'exercise':
        tags = exerciseIds;
        color = const Color(0xFFE8F5E9);
        break;
      case 'progress':
        tags = progresses;
        color = const Color(0xFFFFF3E0);
        break;
      default:
        tags = {};
        color = Colors.grey;
    }

    if (tags.isEmpty) {
      return Text(widget.lang == 'cn' ? '暂无选择' : 'No selection', 
          style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 8,
      children: tags.map((tag) => Chip(
        label: Text(tag),
        backgroundColor: color,
        onDeleted: () => removeTag(tag, type),
      )).toList(),
    );
  }

  Widget _buildAllSelectedTags(Set<String> errorTypes, Set<String> knowledgeTags,
      Set<String> exerciseIds, Set<String> progresses, Function(String, String) removeTag) {
    List<Widget> chips = [];
    
    chips.addAll(errorTypes.map((tag) => Chip(
      label: Text('错类:$tag'),
      backgroundColor: const Color(0xFFFFCDD2),
      onDeleted: () => removeTag(tag, 'errorType'),
    )));
    
    chips.addAll(knowledgeTags.map((tag) => Chip(
      label: Text('知识:$tag'),
      backgroundColor: const Color(0xFFE3F2FD),
      onDeleted: () => removeTag(tag, 'knowledge'),
    )));
    
    chips.addAll(exerciseIds.map((tag) => Chip(
      label: Text('习题:$tag'),
      backgroundColor: const Color(0xFFE8F5E9),
      onDeleted: () => removeTag(tag, 'exercise'),
    )));
    
    chips.addAll(progresses.map((tag) => Chip(
      label: Text('进度:$tag'),
      backgroundColor: const Color(0xFFFFF3E0),
      onDeleted: () => removeTag(tag, 'progress'),
    )));

    if (chips.isEmpty) {
      return Text(widget.lang == 'cn' ? '暂无筛选条件' : 'No filters', 
          style: TextStyle(color: Colors.grey));
    }

    return Wrap(
      spacing: 8,
      children: chips,
    );
  }

  void _showOutlineDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ErrorTypeOutlinePage(
          lang: widget.lang,
        ),
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
    print('[Build] _inGroupedView: $_inGroupedView, _displayRecords length: ${_displayRecords.length}');
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

    final tabs = <String>[
      widget.lang == 'cn' ? '筛选' : 'Filter',
      widget.lang == 'cn' ? '视图' : 'View',
      widget.lang == 'cn' ? '练习' : 'Practice',
      widget.lang == 'cn' ? '错类' : 'Error Type',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    // 动态添加全选/全不选
    final hasUnselected = _displayRecords.any((r) => !_selectedIds.contains(r.id));
    final allSelected = _displayRecords.isNotEmpty && _displayRecords.every((r) => _selectedIds.contains(r.id));
    if (hasUnselected && _displayRecords.isNotEmpty) {
      tabs.add(widget.lang == 'cn' ? '全选' : 'Select All');
    }
    if (allSelected && _displayRecords.isNotEmpty) {
      tabs.add(widget.lang == 'cn' ? '全不选' : 'Deselect All');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-错题本' : 'My AI Language Tutor - Error Book',
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
                            record.wrongWhere ?? record.question ?? record.errorId ?? "",
                            softWrap: true,
                            overflow: TextOverflow.visible,
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
                          TagStyles.knowledgeTag('知识: ${record.kid}'),
                        if (record.eids.isNotEmpty)
                          TagStyles.errorTypeTag('错类: ${record.eids.join(',')}'),
                        if (record.tid != null && record.qid != null)
                          TagStyles.exerciseTag('${record.tid}Q${record.qid}'),
                        TagStyles.statusTag(record.progress, record.progress),
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
