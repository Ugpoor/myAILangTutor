import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';
import '../database/db_helper.dart';
import '../database/models/exercise.dart';
import '../database/models/error_record.dart';
import '../services/llm_service.dart';

class ExercisesPageSimple extends StatefulWidget {
  final String lang;
  final List<ChatMessage>? messages;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const ExercisesPageSimple({
    super.key,
    this.lang = 'cn',
    this.messages,
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
  String? _filterKnowledgeTag;
  bool _isGrading = false;
  bool _isCorrecting = false;
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
      if (_filterKnowledgeTag != null &&
          (e.knowledgeTag == null || !e.knowledgeTag!.contains(_filterKnowledgeTag!))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '批阅' : 'Grade')) {
      await _gradeSelected();
    } else if (tab == (widget.lang == 'cn' ? '订正' : 'Correct')) {
      await _correctSelected();
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
          exerciseTag: exercise.exerciseId,
          knowledgeTag: exercise.knowledgeTag,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '筛选习题' : 'Filter Exercises'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.lang == 'cn' ? '按进度筛选：' : 'By progress:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['未答题', '未批阅', '已批阅', '已订正'].map((p) {
                return ElevatedButton(
                  onPressed: () {
                    setState(() { _filterProgress = p; _applyFilter(); });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _filterProgress == p ? const Color(0xFFFF69B4) : null,
                  ),
                  child: Text(p, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterProgress = null;
                  _filterKnowledgeTag = null;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              child: Text(widget.lang == 'cn' ? '全部' : 'All'),
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
              messages: widget.messages ?? [],
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
              selectedTab: tabs[0],
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

  void _showExerciseDetail(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${exercise.exerciseId ?? ""} ${exercise.question}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.lang == 'cn' ? '考卷：' : 'Exam Paper:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(exercise.examPaper ?? (widget.lang == 'cn' ? '无' : 'None')),
              const Divider(),
              Text(widget.lang == 'cn' ? '答卷：' : 'Answer Sheet:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(exercise.answerSheet ?? (widget.lang == 'cn' ? '未作答' : 'Not answered')),
              const Divider(),
              Text(widget.lang == 'cn' ? '答案：' : 'Answer Key:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(exercise.answerKey ?? (widget.lang == 'cn' ? '无' : 'None')),
              if (exercise.grading != null) ...[
                const Divider(),
                Text(widget.lang == 'cn' ? '批阅：' : 'Grading:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(exercise.grading!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
          ),
        ],
      ),
    );
  }
}
