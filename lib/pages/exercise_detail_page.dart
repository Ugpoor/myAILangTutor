import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/exercise.dart';
import '../database/db_helper.dart';

/// 习题详情页面（试题级 EnTm 格式，显示单题详情）
class ExerciseDetailPage extends StatefulWidget {
  final String lang;
  final Exercise exercise;
  final VoidCallback onHomeTap;

  const ExerciseDetailPage({
    super.key,
    this.lang = 'cn',
    required this.exercise,
    required this.onHomeTap,
  });

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  late Exercise _exercise;
  
  // 每个题目的控制器
  final List<TextEditingController> _questionControllers = [];
  final List<TextEditingController> _optionsControllers = [];
  final List<TextEditingController> _correctAnswerControllers = [];
  final List<TextEditingController> _explanationControllers = [];
  
  // 全局字段控制器
  late TextEditingController _answerKeyController;
  late TextEditingController _answerSheetController;
  late TextEditingController _gradingController;
  late TextEditingController _examPaperController;
  
  // 下拉选择状态
  String? _category;
  int _difficulty = 1;
  String _progress = '未答题';
  String? _knowledgeTag;
  String? _lessonUnit;
  String? _source;

  final List<String> _categories = [
    '填空题', '选择题', '判断题', '简答题', '作文题', '错题',
  ];

  final List<String> _progressOptions = [
    '未答题', '未批阅', '已批阅', '已订正',
  ];

  /// 解析 exam_paper 字段，提取独立题目列表
  List<Map<String, String>> _parseQuestions(String examPaper) {
    final questions = <Map<String, String>>[];
    
    if (examPaper.isEmpty) return questions;
    
    // 尝试按题号分割：1. 2. 3. 或 一、 二、 或 （1）（2）
    // 注意：Flutter 不支持 dotall 参数，使用 [\s\S] 代替 . 匹配任意字符包括换行符
    final patterns = [
      RegExp(r'(?:^|\n)\s*(\d+)\.\s+([\s\S]*?)(?=\n\s*\d+\.\s+|$)'),
      RegExp(r'(?:^|\n)\s*([一二三四五六七八九十])、\s+([\s\S]*?)(?=\n\s*[一二三四五六七八九十]+、\s+|$)'),
      RegExp(r'(?:^|\n)\s*（(\d+)）\s+([\s\S]*?)(?=\n\s*（\d+）\s+|$)'),
    ];
    
    for (final pattern in patterns) {
      final matches = pattern.allMatches(examPaper);
      if (matches.isNotEmpty) {
        for (final match in matches) {
          final title = match.group(0)?.trim() ?? '';
          questions.add({
            'title': title,
            'options': '',
            'answer': '',
            'explanation': '',
          });
        }
        if (questions.isNotEmpty) return questions;
      }
    }
    
    // 如果没有找到题号模式，将整个内容作为一道题
    if (examPaper.trim().isNotEmpty) {
      questions.add({
        'title': examPaper.trim(),
        'options': '',
        'answer': '',
        'explanation': '',
      });
    }
    
    return questions;
  }

  /// 从 answer_key 中提取对应题目的答案
  String _extractAnswerForQuestion(int index, String answerKey) {
    if (answerKey.isEmpty) return '';
    
    // 尝试按行分割
    final lines = answerKey.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (index < lines.length) {
      return lines[index];
    }
    
    // 如果只有一行答案，返回全部
    if (lines.length == 1) return lines.first;
    
    return '';
  }

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
    
    // 试题级：直接显示当前题目的信息
    _questionControllers.add(TextEditingController(text: _exercise.question));
    
    String optionText = _exercise.options ?? '';
    _optionsControllers.add(TextEditingController(text: optionText));
    
    String answer = _exercise.correctAnswer ?? '';
    if (answer.isEmpty && _exercise.answerKey != null) {
      answer = _exercise.answerKey!;
    }
    _correctAnswerControllers.add(TextEditingController(text: answer));
    
    _explanationControllers.add(TextEditingController(text: ''));
    
    // 全局字段（部分保留）
    _answerKeyController = TextEditingController(text: _exercise.answerKey ?? '');
    _answerSheetController = TextEditingController(text: _exercise.answerSheet ?? '');
    _gradingController = TextEditingController(text: _exercise.grading ?? '');
    _examPaperController = TextEditingController(text: '');
    
    _category = _exercise.category;
    _difficulty = _exercise.difficulty;
    _progress = _exercise.progress;
    _knowledgeTag = _exercise.knowledgeTag;
    _lessonUnit = _exercise.lessonUnit;
    _source = _exercise.source;
  }

  @override
  void dispose() {
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    for (var controller in _optionsControllers) {
      controller.dispose();
    }
    for (var controller in _correctAnswerControllers) {
      controller.dispose();
    }
    for (var controller in _explanationControllers) {
      controller.dispose();
    }
    _answerKeyController.dispose();
    _answerSheetController.dispose();
    _gradingController.dispose();
    _examPaperController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    // 更新 exam_paper（题目列表合并）
    final updatedExamPaper = _questionControllers.map((c) => c.text.trim()).join('\n\n');
    
    final updated = _exercise.copyWith(
      question: _questionControllers.isNotEmpty 
          ? _questionControllers.map((c) => c.text.trim()).join('\n\n')
          : '',
      options: _optionsControllers.isNotEmpty && _optionsControllers.first.text.trim().isNotEmpty
          ? _optionsControllers.first.text.trim()
          : null,
      correctAnswer: _correctAnswerControllers.isNotEmpty 
          ? _correctAnswerControllers.map((c) => c.text.trim()).join('\n')
          : null,
      explanation: _explanationControllers.isNotEmpty 
          ? _explanationControllers.map((c) => c.text.trim()).join('\n')
          : null,
      answerKey: _answerKeyController.text.trim().isEmpty 
          ? null : _answerKeyController.text.trim(),
      answerSheet: _answerSheetController.text.trim().isEmpty 
          ? null : _answerSheetController.text.trim(),
      grading: _gradingController.text.trim().isEmpty 
          ? null : _gradingController.text.trim(),
      examPaper: updatedExamPaper.isEmpty ? null : updatedExamPaper,
      category: _category,
      difficulty: _difficulty,
      progress: _progress,
      knowledgeTag: _knowledgeTag,
      lessonUnit: _lessonUnit,
      source: _source,
    );

    final db = await DatabaseHelper().database;
    final exerciseDao = ExerciseDao(db);
    await exerciseDao.update(updated);

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
            ? '确定要删除习题 "${_exercise.exerciseId ?? _exercise.question}" 吗？'
            : 'Delete this exercise record?'),
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
      final exerciseDao = ExerciseDao(db);
      await exerciseDao.delete(_exercise.id!);
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
              title: widget.lang == 'cn' ? '习题详情' : 'Exercise Detail',
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
                      // ID + 进度
                      Row(
                        children: [
                          if (_exercise.exerciseId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _exercise.exerciseId!,
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
                      
                      // 试题详情标题
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
                            widget.lang == 'cn' ? '【试题详情】' : 'Question Detail',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // 试题卡片
                      ...List.generate(_questionControllers.length, (index) {
                        return _buildQuestionCard(index);
                      }),
                      
                      // 元数据区域
                      Text(
                        widget.lang == 'cn' ? '【属性设置】' : 'Properties',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 分类
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
                      
                      // 难度
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
                      
                      // 知识标签
                      TextField(
                        controller: TextEditingController(text: _knowledgeTag ?? ''),
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '知识标签 / Knowledge Tag' : 'Knowledge Tag',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _knowledgeTag = v.isEmpty ? null : v,
                      ),
                      const SizedBox(height: 12),
                      
                      // 课内单元
                      TextField(
                        controller: TextEditingController(text: _lessonUnit ?? ''),
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '课内单元 / Lesson Unit' : 'Lesson Unit',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _lessonUnit = v.isEmpty ? null : v,
                      ),
                      const SizedBox(height: 12),
                      
                      // 来源
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

  /// 构建单个题目的卡片
  Widget _buildQuestionCard(int index) {
    final isMultipleChoice = _optionsControllers[index].text.trim().isNotEmpty;
    
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
          // 题号标题
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
                isMultipleChoice 
                    ? (widget.lang == 'cn' ? '选择题' : 'Multiple Choice')
                    : (widget.lang == 'cn' ? '第${index + 1}题' : 'Question ${index + 1}'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 题目
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
          
          // 选项（如果有）
          if (isMultipleChoice)
            TextField(
              controller: _optionsControllers[index],
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.lang == 'cn' ? '【选项】' : 'Options',
                border: const OutlineInputBorder(),
                hintText: widget.lang == 'cn' ? '每行一个选项，如：A. 选项 1' : 'One option per line',
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          if (isMultipleChoice) const SizedBox(height: 8),
          
          // 正确答案
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
          
          // 解析
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
