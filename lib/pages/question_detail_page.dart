import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/question.dart';
import '../database/db_helper.dart';

class QuestionDetailPage extends StatefulWidget {
  final String lang;
  final Question question;
  final VoidCallback onHomeTap;

  const QuestionDetailPage({
    super.key,
    this.lang = 'cn',
    required this.question,
    required this.onHomeTap,
  });

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  late Question _question;
  late TextEditingController _questionController;
  late TextEditingController _correctAnswerController;
  late TextEditingController _explanationController;
  late TextEditingController _gradingController;
  late TextEditingController _answerController;
  late TextEditingController _gradingResultController;

  String _progress = '未答题';
  String? _category;
  int _difficulty = 1;

  final List<String> _categories = ['填空题', '选择题', '判断题', '简答题', '作文题'];
  final List<String> _progressOptions = ['未答题', '已答题', '未批阅', '已批阅', '已订正'];
  final List<String> _gradingResultOptions = ['正确', '部分正确', '错误', '未评分'];

  @override
  void initState() {
    super.initState();
    _question = widget.question;

    _questionController = TextEditingController(text: _question.question);
    _correctAnswerController = TextEditingController(text: _question.correctAnswer ?? '');
    _explanationController = TextEditingController(text: _question.explanation ?? '');
    _gradingController = TextEditingController(text: _question.grading ?? '');
    _answerController = TextEditingController(text: _question.answer ?? '');
    _gradingResultController = TextEditingController(text: _question.gradingResult ?? '');

    _category = _categories.contains(_question.category) ? _question.category : null;
    _difficulty = _question.difficulty;
    _progress = _question.progress;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _correctAnswerController.dispose();
    _explanationController.dispose();
    _gradingController.dispose();
    _answerController.dispose();
    _gradingResultController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    final updated = _question.copyWith(
      question: _questionController.text.trim(),
      correctAnswer: _correctAnswerController.text.trim().isEmpty ? null : _correctAnswerController.text.trim(),
      explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
      grading: _gradingController.text.trim().isEmpty ? null : _gradingController.text.trim(),
      answer: _answerController.text.trim().isEmpty ? null : _answerController.text.trim(),
      gradingResult: _gradingResultController.text.trim().isEmpty ? null : _gradingResultController.text.trim(),
      category: _category,
      difficulty: _difficulty,
      progress: _progress,
    );

    final db = await DatabaseHelper().database;
    final questionDao = QuestionDao(db);
    await questionDao.update(updated);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(
          widget.lang == 'cn'
              ? '确定要删除这道题目吗？'
              : 'Delete this question?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(widget.lang == 'cn' ? '删除' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      final questionDao = QuestionDao(db);
      await questionDao.delete(_question.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '返回' : 'Back',
      widget.lang == 'cn' ? '保存' : 'Save',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: '${widget.lang == 'cn' ? '题目' : 'Question'} ${widget.question.exerciseId ?? widget.question.tid ?? ''}',
              onHomeTap: widget.onHomeTap,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildQuestionSection(),
                      const SizedBox(height: 16),
                      _buildAnswerSection(),
                      const SizedBox(height: 16),
                      _buildExplanationSection(),
                      const SizedBox(height: 16),
                      if (_question.grading != null && _question.grading!.isNotEmpty) ...[
                        _buildGradingSection(),
                        const SizedBox(height: 16),
                      ],
                      _buildPropertiesSection(),
                    ],
                  ),
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: (tab) {
                final cnBack = widget.lang == 'cn' ? '返回' : 'Back';
                final cnSave = widget.lang == 'cn' ? '保存' : 'Save';
                final cnDelete = widget.lang == 'cn' ? '删除' : 'Delete';

                if (tab == cnBack) {
                  Navigator.of(context).pop(false);
                } else if (tab == cnSave) {
                  _saveRecord();
                } else if (tab == cnDelete) {
                  _deleteRecord();
                }
              },
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          if (_question.tid != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _question.tid!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getProgressColor(_question.progress),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _question.progress,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const Spacer(),
          if (_question.kid != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '知识: ${_question.kid}',
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lang == 'cn' ? '【题目】' : 'Question',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _questionController,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lang == 'cn' ? '【正确答案】' : 'Correct Answer',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _correctAnswerController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.lang == 'cn' ? '【学生答案】' : 'Student Answer',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lang == 'cn' ? '【解析】' : 'Explanation',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9800),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _explanationController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lang == 'cn' ? '【批改结果】' : 'Grading Result',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9C27B0),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gradingResultController,
            maxLines: 1,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
              hintText: '正确 / 部分正确 / 错误',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.lang == 'cn' ? '【批阅意见】' : 'Grading Comment',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9C27B0),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gradingController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lang == 'cn' ? '【属性】' : 'Properties',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _progress,
            decoration: const InputDecoration(
              labelText: '进度 / Progress',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            items: _progressOptions
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _progress = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: widget.lang == 'cn' ? '分类 / Category' : 'Category',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
            items: _categories
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _difficulty,
            decoration: InputDecoration(
              labelText: widget.lang == 'cn' ? '难度 / Difficulty' : 'Difficulty',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
            items: List.generate(5, (index) => index + 1)
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text('${'★' * d}${'☆' * (5 - d)} ($d)'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _difficulty = v!),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(String status) {
    switch (status) {
      case '已批阅':
        return const Color(0xFFFF9800);
      case '已订正':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }
}
