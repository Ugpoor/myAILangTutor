import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/tag_styles.dart';
import '../components/generic_filter_dialog.dart';
import '../database/db_helper.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
import '../services/llm_service.dart';
import 'paper_detail_page.dart';

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
  List<Test> _allTests = [];
  List<Test> _displayTests = [];
  final Set<int> _selectedIds = {};
  bool _isGrading = false;
  bool _isCorrecting = false;
  late TestDao _testDao;
  late QuestionDao _questionDao;
  final LlmService _llmService = LlmService();
  
  // 筛选状态
  Set<String> _filterUnitNumbers = {};
  Set<String> _filterLessonNumbers = {};
  Set<String> _filterStatus = {};
  Set<String> _filterKids = {};
  String _filterContentKeyword = '';

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _testDao = TestDao(db);
    _questionDao = QuestionDao(db);
    await _llmService.init();
    await _loadTests();
  }

  Future<void> _loadTests() async {
    final tests = await _testDao.getAll(lang: widget.lang);
    setState(() {
      _allTests = tests;
      _displayTests = tests;
    });
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '批阅' : 'Grade')) {
      await _gradeSelected();
    } else if (tab == (widget.lang == 'cn' ? '订正' : 'Correct')) {
      await _correctSelected();
    } else if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    }
  }

  void _showFilterDialog() async {
    final unitNumbers = _allTests
        .map((t) => t.lessonUnitList.firstWhere(
              (item) => item.startsWith('U'),
              orElse: () => '',
            ))
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceFirst('U', ''))
        .toSet();
    
    final lessonNumbers = _allTests
        .map((t) => t.lessonUnitList.firstWhere(
              (item) => item.startsWith('L'),
              orElse: () => '',
            ))
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceFirst('L', ''))
        .toSet();
    
    final statuses = _allTests.map((t) => t.status).toSet();
    final kids = _allTests.expand((t) => t.kids).where((s) => s.isNotEmpty).toSet();

    final config = FilterConfig(
      filterTypes: [
        'unit',
        'lesson',
        'status',
        'kid',
      ],
      typeConfigs: {
        'unit': FilterTypeConfig(
          options: unitNumbers.map((u) => FilterOption(value: u, label: u)).toList(),
          initialValues: _filterUnitNumbers,
          label: widget.lang == 'cn' ? '单元号' : 'Unit',
          hintText: widget.lang == 'cn' ? '输入单元号...' : 'Enter unit...',
        ),
        'lesson': FilterTypeConfig(
          options: lessonNumbers.map((l) => FilterOption(value: l, label: l)).toList(),
          initialValues: _filterLessonNumbers,
          label: widget.lang == 'cn' ? '课号' : 'Lesson',
          hintText: widget.lang == 'cn' ? '输入课号...' : 'Enter lesson...',
        ),
        'status': FilterTypeConfig(
          options: statuses.map((s) => FilterOption(value: s, label: s)).toList(),
          initialValues: _filterStatus,
          label: widget.lang == 'cn' ? '状态' : 'Status',
          hintText: widget.lang == 'cn' ? '输入状态...' : 'Enter status...',
        ),
        'kid': FilterTypeConfig(
          options: kids.map((k) => FilterOption(value: k, label: k)).toList(),
          initialValues: _filterKids,
          label: widget.lang == 'cn' ? '知识点' : 'Knowledge',
          hintText: widget.lang == 'cn' ? '输入知识点...' : 'Enter knowledge...',
        ),
      },
    );

    final result = await GenericFilterDialog.show(context, config: config, lang: widget.lang);

    if (result != null) {
      setState(() {
        _filterUnitNumbers = Set<String>.from((result['unit'] as Map?)?['values'] ?? {});
        _filterLessonNumbers = Set<String>.from((result['lesson'] as Map?)?['values'] ?? {});
        _filterStatus = Set<String>.from((result['status'] as Map?)?['values'] ?? {});
        _filterKids = Set<String>.from((result['kid'] as Map?)?['values'] ?? {});
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    List<Test> filtered = List.from(_allTests);

    if (_filterUnitNumbers.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.lessonUnitList.any((item) => 
          _filterUnitNumbers.any((unit) => item == 'U$unit')
        );
      }).toList();
    }

    if (_filterLessonNumbers.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.lessonUnitList.any((item) => 
          _filterLessonNumbers.any((lesson) => item == 'L$lesson')
        );
      }).toList();
    }

    if (_filterStatus.isNotEmpty) {
      filtered = filtered.where((t) => _filterStatus.contains(t.status)).toList();
    }

    if (_filterKids.isNotEmpty) {
      filtered = filtered.where((t) => 
        t.kids.any((kid) => _filterKids.contains(kid))
      ).toList();
    }

    if (_filterContentKeyword.isNotEmpty) {
      final keyword = _filterContentKeyword.toLowerCase();
      filtered = filtered.where((t) => 
        (t.content ?? '').toLowerCase().contains(keyword)
      ).toList();
    }

    setState(() {
      _displayTests = filtered;
    });
  }

  Future<void> _gradeSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择试卷' : 'Select test papers first')),
      );
      return;
    }

    if (_isGrading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '批阅正在进行中' : 'Grading in progress')),
      );
      return;
    }

    setState(() => _isGrading = true);

    try {
      final questions = await _questionDao.getAll(lang: widget.lang);
      final selectedTests = _allTests.where((t) => _selectedIds.contains(t.id)).toList();
      
      for (final test in selectedTests) {
        final testQuestions = questions.where((q) => q.tid == test.tid).toList();
        final toGrade = testQuestions.where((q) => q.progress == '未批阅').toList();
        
        for (final question in toGrade) {
          final prompt = '请批阅以下习题：\n题目：${question.question}\n答卷：${question.correctAnswer ?? "未作答"}';
          final response = await _llmService.generateResponse(prompt);
          final gradingResult = response['response'] ?? '';

          await _questionDao.update(question.copyWith(
            grading: gradingResult,
            progress: '已批阅',
          ));
        }
      }

      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '批阅完成' : 'Grading complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '批阅失败: $e' : 'Grading failed: $e')),
        );
      }
    } finally {
      setState(() => _isGrading = false);
    }
  }

  Future<void> _correctSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择试卷' : 'Select test papers first')),
      );
      return;
    }

    if (_isCorrecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '订正正在进行中' : 'Correction in progress')),
      );
      return;
    }

    setState(() => _isCorrecting = true);

    try {
      final questions = await _questionDao.getAll(lang: widget.lang);
      final selectedTests = _allTests.where((t) => _selectedIds.contains(t.id)).toList();
      
      for (final test in selectedTests) {
        final testQuestions = questions.where((q) => q.tid == test.tid).toList();
        final toCorrect = testQuestions.where((q) => q.progress == '已批阅').toList();
        
        for (final question in toCorrect) {
          await _questionDao.update(question.copyWith(
            progress: '已订正',
          ));
        }
      }

      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '订正完成' : 'Correction complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '订正失败: $e' : 'Correction failed: $e')),
        );
      }
    } finally {
      setState(() => _isCorrecting = false);
    }
  }

  void _openTestDetail(Test test) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaperDetailPage(
          lang: widget.lang,
          paper: test,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn' ? ['批阅', '订正', '筛选'] : ['Grade', 'Correct', 'Filter'];

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
                child: _displayTests.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无试卷' : 'No test papers'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayTests.length,
                        itemBuilder: (context, index) {
                          final test = _displayTests[index];
                          return _buildTestItem(test);
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

  Widget _buildTestItem(Test test) {
    final isSelected = _selectedIds.contains(test.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openTestDetail(test),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(test.id!);
                    } else {
                      _selectedIds.remove(test.id!);
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
                          '${test.tid} ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF651FFF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (test.lessonUnitList.isNotEmpty)
                          TagStyles.lessonUnitTag('${widget.lang == 'cn' ? '单元' : 'Unit'}: ${test.lessonUnitList.join(',')}'),
                        if (test.kids.isNotEmpty)
                          TagStyles.knowledgeTag('${widget.lang == 'cn' ? '知识' : 'Knowledge'}: ${test.kids.join(',')}'),
                        TagStyles.exerciseTag(test.tid),
                        TagStyles.statusTag(test.status, test.status),
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

  Future<int> _getQuestionCount(String tid) async {
    final questions = await _questionDao.getQuestionsByTid(tid);
    return questions.length;
  }
}
