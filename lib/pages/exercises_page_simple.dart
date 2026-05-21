import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/dynamic_tag_selector.dart';
import '../database/db_helper.dart';
import '../database/models/exercise.dart';
import '../database/models/error_record.dart';
import '../services/llm_service.dart';
import 'exercise_detail_page.dart';

class ExercisesPageSimple extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const ExercisesPageSimple({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<ExercisesPageSimple> createState() => _ExercisesPageSimpleState();
}

class _ExercisesPageSimpleState extends State<ExercisesPageSimple> {
  List<Exercise> _allExercises = [];
  List<Exercise> _displayExercises = [];
  final Set<int> _selectedIds = {};
  String? _filterProgress;
  Set<String> _filterKnowledgeTags = {};
  Set<String> _filterSources = {};
  String? _filterLessonUnitInput;
  bool _isGrading = false;
  bool _isCorrecting = false;
  bool _isCleaning = false;
  late ExerciseDao _exerciseDao;
  final LlmService _llmService = LlmService();

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _exerciseDao = ExerciseDao(db);
    await _llmService.init();
    await _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await _exerciseDao.getAll(lang: widget.lang);
    setState(() {
      _allExercises = exercises;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _displayExercises = _allExercises.where((e) {
      if (_filterProgress != null && e.progress != _filterProgress) return false;
      if (_filterKnowledgeTags.isNotEmpty && !_filterKnowledgeTags.any((tag) => e.knowledgeTag?.contains(tag) ?? false)) return false;
      if (_filterSources.isNotEmpty && !(_filterSources.contains(e.source) || (e.source == null && _filterSources.contains('未设置')))) return false;
      if (_filterLessonUnitInput?.isNotEmpty == true && !(e.lessonUnit?.contains(_filterLessonUnitInput!) ?? false)) return false;
      return true;
    }).toList();
  }

  /// 获取所有唯一的知识点标签
  Set<String> get _allKnowledgeTags => _allExercises.map((e) => e.knowledgeTag).whereType<String>().toSet();
  /// 获取所有唯一的来源
  Set<String> get _allSources => _allExercises.map((e) => e.source).where((s) => s != null).cast<String>().toSet();

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '批阅' : 'Grade')) {
      await _gradeSelected();
    } else if (tab == (widget.lang == 'cn' ? '订正' : 'Correct')) {
      await _correctSelected();
    }
  }

  /// 清空所有习题
  Future<void> _cleanExercises() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认清理' : 'Confirm Clean'),
        content: Text(widget.lang == 'cn' 
            ? '此操作将删除重复条目和无效数据。此操作不可撤销！' 
            : 'This will delete duplicate entries and invalid data. This cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF69B4)),
            child: Text(widget.lang == 'cn' ? '确认清理' : 'Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCleaning = true);

    try {
      final result = await _exerciseDao.cleanExercises();
      
      await _loadExercises();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' 
                  ? '清理完成：删除重复习题 ${result['duplicate_deleted']} 条'
                  : 'Clean complete: deleted ${result['duplicate_deleted']} duplicate entries',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lang == 'cn' ? '清理失败: $e' : 'Clean failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isCleaning = false);
    }
  }

  /// 清空所有习题
  Future<void> _clearAllExercises() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认清空' : 'Confirm Clear All'),
        content: Text(widget.lang == 'cn' 
            ? '此操作将删除所有习题（包括LLM生成的）。此操作不可撤销！' 
            : 'This will delete ALL exercises. This cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(widget.lang == 'cn' ? '确认清空' : 'Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCleaning = true);

    try {
      // 先保留3条习题
      final allExercises = await _exerciseDao.getAll(lang: widget.lang);
      if (allExercises.length <= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '习题数量已≤3条，无需清空' : 'Already ≤ 3 exercises')),
        );
        setState(() => _isCleaning = false);
        return;
      }

      // 删除所有习题中除了最早的3条
      final sorted = List.from(allExercises)..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2020);
        final bTime = b.createdAt ?? DateTime(2020);
        return aTime.compareTo(bTime);
      });
      int deletedCount = 0;
      for (int i = 3; i < sorted.length; i++) {
        await _exerciseDao.delete(sorted[i].id!);
        deletedCount++;
      }

      await _loadExercises();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' 
                  ? '已清空，保留3条习题，删除 $deletedCount 条'
                  : 'Cleared, kept 3 exercises, deleted $deletedCount',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '清空失败: $e' : 'Clear failed: $e')),
        );
      }
    } finally {
      setState(() => _isCleaning = false);
    }
  }

  Future<void> _gradeSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择习题' : 'Select exercises first')),
      );
      return;
    }

    if (_isGrading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '批阅正在进行中' : 'Grading in progress')),
      );
      return;
    }

    final toGrade = _allExercises.where((e) => _selectedIds.contains(e.id) && e.progress == '未批阅').toList();
    if (toGrade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '没有可批阅的习题（需要"未批阅"状态）' : 'No exercises to grade')),
      );
      return;
    }

    setState(() => _isGrading = true);

    try {
      for (final exercise in toGrade) {
        final prompt = '请批阅以下习题：\n题目：${exercise.question}\n答卷：${exercise.answerSheet ?? "未作答"}\n答案：${exercise.answerKey ?? ""}';
        final response = await _llmService.generateResponse(prompt);
        final gradingResult = response['response'] ?? '';

        await _exerciseDao.update(exercise.copyWith(
          grading: gradingResult,
          progress: '已批阅',
        ));

        // Batch update complete, continue to next exercise
      }

      await _loadExercises();
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '批阅完成' : 'Grading complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '批阅失败' : 'Grading failed')),
        );
      }
    } finally {
      setState(() => _isGrading = false);
    }
  }

  Future<void> _correctSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择习题' : 'Select exercises first')),
      );
      return;
    }

    if (_isCorrecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '订正正在进行中' : 'Correction in progress')),
      );
      return;
    }

    final toCorrect = _allExercises.where((e) => _selectedIds.contains(e.id) && e.progress == '已批阅').toList();
    if (toCorrect.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '没有可订正的习题（需要"已批阅"状态）' : 'No exercises to correct')),
      );
      return;
    }

    setState(() => _isCorrecting = true);

    try {
      final db = await DatabaseHelper().database;
      final errorRecordDao = ErrorRecordDao(db);

      for (final exercise in toCorrect) {
        // 生成错误本条目
        final nextNum = await errorRecordDao.nextErrorIdNumber();
        await errorRecordDao.insert(ErrorRecord(
          content: exercise.question,
          errorId: 'T$nextNum',
          question: exercise.examPaper,
          wrongAnswer: exercise.answerSheet,
          progress: '待订正',
          createdAt: DateTime.now(),
          lang: widget.lang,
        ));

        await _exerciseDao.update(exercise.copyWith(progress: '已订正'));

        // Batch update complete, continue to next exercise
      }

      await _loadExercises();
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '订正完成，错题已写入错误本' : 'Correction done, errors written')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '订正失败' : 'Correction failed')),
        );
      }
    } finally {
      setState(() => _isCorrecting = false);
    }
  }

  void _showFilterDialog() {
    // Deep copy current selections
    Set<String> selectedTags = Set<String>.from(_filterKnowledgeTags);
    Set<String> selectedSources = Set<String>.from(_filterSources);
    String? tempProgress = _filterProgress;
    String lessonUnitInput = _filterLessonUnitInput ?? '';

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(widget.lang == 'cn' ? '筛选习题' : 'Filter Exercises'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 进度筛选（下拉选择）
                  Text(widget.lang == 'cn' ? '按进度：' : 'By progress:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonFormField<String?>(
                      value: tempProgress,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部 / All'),
                        ),
                        ...['未答题', '未批阅', '已批阅', '已订正'].map((p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => tempProgress = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 知识点标签筛选（使用动态标签选择器）
                  DynamicTagSelector(
                    label: widget.lang == 'cn' ? '知识点标签' : 'Knowledge tags',
                    currentTags: selectedTags,
                    availableOptions: _allKnowledgeTags,
                    onTagsChanged: (newTags) {
                      setState(() => selectedTags = newTags);
                    },
                    accentColor: const Color(0xFF2196F3),
                  ),
                  const SizedBox(height: 16),
                  // 课内标签筛选（输入匹配）
                  Text(widget.lang == 'cn' ? '课内标签（输入关键词）：' : 'Lesson unit (keyword):',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    decoration: InputDecoration(
                      hintText: widget.lang == 'cn' ? '如：四年级上' : 'e.g. Grade 4',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      lessonUnitInput = v;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 来源筛选（使用动态标签选择器）
                  DynamicTagSelector(
                    label: widget.lang == 'cn' ? '来源' : 'Source',
                    currentTags: selectedSources,
                    availableOptions: _allSources,
                    onTagsChanged: (newTags) {
                      setState(() => selectedSources = newTags);
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
                  _filterProgress = null;
                  _filterKnowledgeTags.clear();
                  _filterSources.clear();
                  _filterLessonUnitInput = null;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              child: Text(widget.lang == 'cn' ? '清空' : 'Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterProgress = tempProgress;
                  _filterKnowledgeTags = selectedTags;
                  _filterSources = selectedSources;
                  _filterLessonUnitInput = lessonUnitInput.isNotEmpty ? lessonUnitInput : null;
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

  Color _getProgressColor(String progress) {
    switch (progress) {
      case '未答题':
        return const Color(0xFFD3D3D3);
      case '未批阅':
        return const Color(0xFFFFE4E9);
      case '已批阅':
        return const Color(0xFFFFA07A);
      case '已订正':
        return const Color(0xFF90EE90);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn' ? ['筛选', '批阅', '订正'] : ['Filter', 'Grade', 'Correct'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-习题集' : 'My AI Language Tutor - Exercises',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'exercise',
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
                child: _displayExercises.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无习题' : 'No exercises'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _displayExercises[index];
                          return _buildExerciseItem(exercise);
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

  Widget _buildExerciseItem(Exercise exercise) {
    final isSelected = _selectedIds.contains(exercise.id);
    final progressColor = _getProgressColor(exercise.progress);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          _showExerciseDetail(exercise);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(exercise.id!);
                    } else {
                      _selectedIds.remove(exercise.id!);
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
                          '${exercise.exerciseId ?? ""} ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF651FFF)),
                        ),
                        Expanded(
                          child: Text(
                            exercise.question,
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
                        if (exercise.source != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDDA0DD), borderRadius: BorderRadius.circular(4)),
                            child: Text('来源: ${exercise.source}', style: const TextStyle(fontSize: 11)),
                          ),
                        if (exercise.lessonUnit != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFE4E9), borderRadius: BorderRadius.circular(4)),
                            child: Text('课内: ${exercise.lessonUnit}', style: const TextStyle(fontSize: 11)),
                          ),
                        if (exercise.knowledgeTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF87CEEB), borderRadius: BorderRadius.circular(4)),
                            child: Text('知识: ${exercise.knowledgeTag}', style: const TextStyle(fontSize: 11)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: progressColor, borderRadius: BorderRadius.circular(4)),
                          child: Text(exercise.progress, style: const TextStyle(fontSize: 11)),
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

  Future<void> _showExerciseDetail(Exercise exercise) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailPage(
          lang: widget.lang,
          exercise: exercise,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
  }
}
