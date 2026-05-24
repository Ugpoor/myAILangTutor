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
  
  final List<TextEditingController> _questionControllers = [];
  final List<TextEditingController> _correctAnswerControllers = [];
  final List<TextEditingController> _explanationControllers = [];
  
  late TextEditingController _gradingController;
  
  String? _category;
  int _difficulty = 1;
  String _progress = '未答题';
  String? _kid;
  int? _lessonNumber;
  int? _unitNumber;
  String? _source;

  final List<String> _categories = [
    '填空题', '选择题', '判断题', '简答题', '作文题',
  ];

  final List<String> _progressOptions = [
    '未答题', '未批阅', '已批阅', '已订正',
  ];

  @override
  void initState() {
    super.initState();
    _question = widget.question;
    
    _questionControllers.add(TextEditingController(text: _question.question));
    
    String answer = _question.correctAnswer ?? '';
    _correctAnswerControllers.add(TextEditingController(text: answer));
    
    _explanationControllers.add(TextEditingController(text: _question.explanation ?? ''));
    
    _gradingController = TextEditingController(text: _question.grading ?? '');
    
    _category = _categories.contains(_question.category) ? _question.category : null;
    _difficulty = _question.difficulty;
    _progress = _question.progress;
    _kid = _question.kid;
    _lessonNumber = _question.lessonNumber;
    _unitNumber = _question.unitNumber;
    _source = _question.source;
  }

  @override
  void dispose() {
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    for (var controller in _correctAnswerControllers) {
      controller.dispose();
    }
    for (var controller in _explanationControllers) {
      controller.dispose();
    }
    _gradingController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    final updated = _question.copyWith(
      question: _questionControllers.isNotEmpty 
          ? _questionControllers.map((c) => c.text.trim()).join('\n\n')
          : '',
      correctAnswer: _correctAnswerControllers.isNotEmpty 
          ? _correctAnswerControllers.map((c) => c.text.trim()).join('\n')
          : null,
      explanation: _explanationControllers.isNotEmpty 
          ? _explanationControllers.map((c) => c.text.trim()).join('\n')
          : null,
      grading: _gradingController.text.trim().isEmpty 
          ? null : _gradingController.text.trim(),
      category: _category,
      difficulty: _difficulty,
      progress: _progress,
      kid: _kid,
      lessonNumber: _lessonNumber,
      unitNumber: _unitNumber,
      source: _source,
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
        content: Text(widget.lang == 'cn'
            ? '确定要删除题目 "${_question.exerciseId ?? _question.question}" 吗？'
            : 'Delete this question record?'),
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
      widget.lang == 'cn' ? '取消' : 'Cancel',
      widget.lang == 'cn' ? '保存' : 'Save',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '题目详情' : 'Question Detail',
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
                      Row(
                        children: [
                          if (_question.exerciseId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _question.exerciseId!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          const Spacer(),
                          DropdownButtonFormField<String>(
                            initialValue: _progress,
                            decoration: const InputDecoration(
                              labelText: '进度 / Progress',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _progressOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (v) => setState(() => _progress = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.lang == 'cn' ? '【题目详情】' : 'Question Detail',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      ...List.generate(_questionControllers.length, (index) {
                        return _buildQuestionCard(index);
                      }),
                      
                      Text(
                        widget.lang == 'cn' ? '【属性设置】' : 'Properties',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '分类 / Category' : 'Category',
                          border: const OutlineInputBorder(),
                        ),
                        items: _categories.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _category = v),
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<int>(
                        initialValue: _difficulty,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '难度 / Difficulty' : 'Difficulty',
                          border: const OutlineInputBorder(),
                        ),
                        items: List.generate(5, (index) => index + 1)
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text('${'★' * d}${'☆' * (5 - d)} ($d)'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _difficulty = v!),
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: TextEditingController(text: _kid ?? ''),
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '知识点ID / Kid' : 'Knowledge ID',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _kid = v.isEmpty ? null : v,
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _lessonNumber?.toString() ?? ''),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '单元号' : 'Lesson Number',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) => _lessonNumber = v.isEmpty ? null : int.tryParse(v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _unitNumber?.toString() ?? ''),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '课号' : 'Unit Number',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) => _unitNumber = v.isEmpty ? null : int.tryParse(v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (_question.lessonUnit != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.yellow[50],
                            border: Border.all(color: Colors.yellow[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.lang == 'cn' ? '课内标签' : 'Lesson Unit'}: ${_question.lessonUnit}',
                            style: TextStyle(color: Colors.brown[700]),
                          ),
                        ),
                      if (_question.lessonUnit != null) const SizedBox(height: 12),
                      
                      TextField(
                        controller: TextEditingController(text: _source ?? ''),
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '来源 / Source' : 'Source',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _source = v.isEmpty ? null : v,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: (tab) {
                final cnCancel = widget.lang == 'cn' ? '取消' : 'Cancel';
                final cnSave = widget.lang == 'cn' ? '保存' : 'Save';
                final cnDelete = widget.lang == 'cn' ? '删除' : 'Delete';

                if (tab == cnCancel) {
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

  Widget _buildQuestionCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.lang == 'cn' ? '第${index + 1}题' : 'Question ${index + 1}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _questionControllers[index],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.lang == 'cn' ? '【题目】' : 'Question',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          
          TextField(
            controller: _correctAnswerControllers[index],
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.lang == 'cn' ? '【正确答案】' : 'Correct Answer',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: Colors.green[50],
            ),
          ),
          const SizedBox(height: 8),
          
          TextField(
            controller: _explanationControllers[index],
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.lang == 'cn' ? '【解析】' : 'Explanation',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}