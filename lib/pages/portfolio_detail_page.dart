import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/db_helper.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/exercise.dart';
import '../services/llm_service.dart';

class PortfolioDetailPage extends StatefulWidget {
  final String lang;
  final PortfolioItem item;
  final PortfolioDao portfolioDao;
  final VoidCallback onHomeTap;

  const PortfolioDetailPage({
    super.key,
    this.lang = 'cn',
    required this.item,
    required this.portfolioDao,
    required this.onHomeTap,
  });

  @override
  State<PortfolioDetailPage> createState() => _PortfolioDetailPageState();
}

class _PortfolioDetailPageState extends State<PortfolioDetailPage> {
  late PortfolioItem _item;
  late TextEditingController _titleController;
  String? _knowledgeTag;
  String? _lessonUnit;
  bool _isOriginal = false;
  bool _isAiAnalyzing = false;
  String? _aiReview;
  final LlmService _llmService = LlmService();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _titleController = TextEditingController(text: _item.title);
    _knowledgeTag = _item.knowledgeTag;
    _lessonUnit = _item.lessonUnit;
    _isOriginal = _item.isOriginal;
    _aiReview = _item.aiReview;
    _llmService.init();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    final updated = _item.copyWith(
      title: _titleController.text.trim(),
      knowledgeTag: _knowledgeTag,
      lessonUnit: _lessonUnit,
      isOriginal: _isOriginal,
      aiReview: _aiReview,
    );
    await widget.portfolioDao.update(updated);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除作品 "${_item.title}" 吗？'
            : 'Are you sure you want to delete "${_item.title}"?'),
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
      await widget.portfolioDao.delete(_item.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _aiAnalyze() async {
    if (_isAiAnalyzing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '评析正在进行中' : 'Analysis in progress')),
      );
      return;
    }

    setState(() => _isAiAnalyzing = true);

    try {
      final prompt = _isOriginal
          ? '请对以下学生作文进行点评，从内容、结构、语言三个方面给出详细修改建议：\n标题：${_item.title}'
          : '请对以下作品进行赏析，包括写作手法、语言特色和情感表达：\n标题：${_item.title}';

      final response = await _llmService.generateResponse(prompt);
      final review = response['response'] ?? '';

      setState(() {
        _aiReview = review;
        _isAiAnalyzing = false;
      });

      // 自动保存评析结果
      final updated = _item.copyWith(aiReview: review);
      await widget.portfolioDao.update(updated);
      _item = updated;
    } catch (e) {
      setState(() => _isAiAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '评析失败' : 'Analysis failed')),
        );
      }
    }
  }

  Future<void> _generateExercise() async {
    final db = await DatabaseHelper().database;
    final exerciseDao = ExerciseDao(db);
    final nextNum = await exerciseDao.nextExerciseIdNumber();

    await exerciseDao.insert(Exercise(
      question: '${_item.title} - 专项测试',
      exerciseId: 'T$nextNum',
      knowledgeTag: _item.knowledgeTag,
      lessonUnit: _item.lessonUnit,
      progress: '未答题',
      category: '专项练习',
      createdAt: DateTime.now(),
      lang: widget.lang,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '习题已添加到习题集' : 'Exercise added')),
      );
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
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '作品详情' : 'Portfolio Detail',
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
                      // 作品ID + 标题
                      Row(
                        children: [
                          Text(
                            '${_item.portfolioId ?? ""} ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '文章标题' : 'Title',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 标签区域
                      Row(
                        children: [
                          Text(widget.lang == 'cn' ? '课内标签：' : 'Lesson: ',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _lessonUnit ?? ''),
                              decoration: InputDecoration(
                                hintText: widget.lang == 'cn' ? '如：四年级上' : 'e.g. Grade 4',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => _lessonUnit = v.isEmpty ? null : v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(widget.lang == 'cn' ? '知识标签：' : 'Knowledge: ',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _knowledgeTag ?? ''),
                              decoration: InputDecoration(
                                hintText: widget.lang == 'cn' ? '如：借物喻人' : 'e.g. Metaphor',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => _knowledgeTag = v.isEmpty ? null : v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 是否原创
                      Row(
                        children: [
                          Text(widget.lang == 'cn' ? '原创：' : 'Original: ',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Switch(
                            value: _isOriginal,
                            onChanged: (v) => setState(() => _isOriginal = v),
                          ),
                          if (_isOriginal)
                            Chip(
                              label: Text(widget.lang == 'cn' ? '原创' : 'Original'),
                              backgroundColor: const Color(0xFFDDA0DD),
                              labelStyle: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 内容预览区
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '内容区域' : 'Content Area',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.lang == 'cn' ? '（富媒体编辑器预留区域）' : '(Rich media editor placeholder)',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // AI评析区域
                      Row(
                        children: [
                          Text(
                            widget.lang == 'cn' ? 'AI评析' : 'AI Review',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _isAiAnalyzing ? null : _aiAnalyze,
                            icon: _isAiAnalyzing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(_isAiAnalyzing
                                ? (widget.lang == 'cn' ? '评析中...' : 'Analyzing...')
                                : (widget.lang == 'cn' ? '开始评析' : 'Analyze')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF651FFF),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _aiReview != null ? const Color(0xFFF0FFF0) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _aiReview != null ? Colors.green[200]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          _aiReview ?? (widget.lang == 'cn' ? '尚未进行评析，点击"开始评析"按钮' : 'No review yet. Click "Analyze"'),
                          style: TextStyle(
                            fontSize: 14,
                            color: _aiReview != null ? Colors.black87 : Colors.grey[500],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 生成练习按钮
                      if (!_isOriginal)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _generateExercise,
                            icon: const Icon(Icons.quiz),
                            label: Text(widget.lang == 'cn' ? '生成练习题' : 'Generate Exercise'),
                          ),
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
                  _saveItem();
                } else if (tab == cnDelete) {
                  _deleteItem();
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
}
