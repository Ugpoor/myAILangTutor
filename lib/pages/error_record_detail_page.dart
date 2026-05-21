import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/error_record.dart';

/// 错误本详情编辑页面 - 从分组视图或列表页进入
/// SubmenuTabs: 返回 / 保存 / 删除

class ErrorRecordDetailPage extends StatefulWidget {
  final String lang;
  final ErrorRecord record;
  final ErrorRecordDao dao;
  final VoidCallback onHomeTap;
  final bool fromGroupedView; // true表示从分组视图进入，需要"返回"按钮

  const ErrorRecordDetailPage({
    super.key,
    this.lang = 'cn',
    required this.record,
    required this.dao,
    required this.onHomeTap,
    this.fromGroupedView = false,
  });

  @override
  State<ErrorRecordDetailPage> createState() => _ErrorRecordDetailPageState();
}

class _ErrorRecordDetailPageState extends State<ErrorRecordDetailPage> {
  late TextEditingController _contentController;
  late TextEditingController _questionController;
  late TextEditingController _wrongAnswerController;
  late TextEditingController _correctAnswerController;
  late TextEditingController _whyWrongController;
  late TextEditingController _howPreventController;
  late TextEditingController _knowledgeTagController;
  late TextEditingController _errorTypeController;
  late TextEditingController _progressController;

  bool _isDirty = false;
  late String _lang;
  late String _progress;
  late String? _errorType;
  late String? _knowledgeTag;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _progress = widget.record.progress;
    _errorType = widget.record.errorType;
    _contentController = TextEditingController(text: widget.record.content);
    _questionController = TextEditingController(text: widget.record.question ?? '');
    _wrongAnswerController = TextEditingController(text: widget.record.wrongAnswer ?? '');
    _correctAnswerController = TextEditingController(text: widget.record.correctAnswer ?? '');
    _whyWrongController = TextEditingController(text: widget.record.whyWrong ?? '');
    _howPreventController = TextEditingController(text: widget.record.howPrevent ?? '');
    _errorTypeController = TextEditingController(text: widget.record.errorType ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _questionController.dispose();
    _wrongAnswerController.dispose();
    _correctAnswerController.dispose();
    _whyWrongController.dispose();
    _howPreventController.dispose();
    _errorTypeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.record.copyWith(
      content: _contentController.text.trim(),
      question: _questionController.text.isEmpty ? null : _questionController.text.trim(),
      wrongAnswer: _wrongAnswerController.text.isEmpty ? null : _wrongAnswerController.text.trim(),
      correctAnswer: _correctAnswerController.text.isEmpty ? null : _correctAnswerController.text.trim(),
      whyWrong: _whyWrongController.text.isEmpty ? null : _whyWrongController.text.trim(),
      howPrevent: _howPreventController.text.isEmpty ? null : _howPreventController.text.trim(),
      errorType: _errorTypeController.text.isEmpty ? null : _errorTypeController.text.trim(),
      progress: _progress,
    );
    await widget.dao.update(updated);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(_lang == 'cn'
            ? '确定要删除此错题记录吗？'
            : 'Are you sure you want to delete this error record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_lang == 'cn' ? '删除' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.dao.delete(widget.record.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '错题详情' : 'Error Record Detail',
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
                      // 基本信息行
                      Row(
                        children: [
                          Text(
                            '${widget.record.errorId ?? ""} ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '错题内容' : 'Content',
                                border: const OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              onChanged: (_) => setState(() => _isDirty = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Question + Wrong Answer
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _questionController,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '正确题目' : 'Question',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() => _isDirty = true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _wrongAnswerController,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '错答' : 'Wrong Answer',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() => _isDirty = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Correct Answer
                      TextField(
                        controller: _correctAnswerController,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '正确答案' : 'Correct Answer',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _isDirty = true),
                      ),
                      const SizedBox(height: 16),
                      // Why Wrong + How Prevent
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _whyWrongController,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '错因分析' : 'Why Wrong',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() => _isDirty = true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _howPreventController,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '预防策略' : 'How Prevent',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() => _isDirty = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tags row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _knowledgeTagController,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '知识标签' : 'Knowledge Tag',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                _knowledgeTag = v.isEmpty ? null : v;
                                setState(() => _isDirty = true);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _errorTypeController,
                              decoration: InputDecoration(
                                labelText: widget.lang == 'cn' ? '错误类别' : 'Error Type',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                _errorType = v.isEmpty ? null : v;
                                setState(() => _isDirty = true);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress dropdown
                      Row(
                        children: [
                          Text(widget.lang == 'cn' ? '进度：' : 'Progress: ',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _progress,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              items: ['待订正', '已订正'].map((p) {
                                return DropdownMenuItem<String>(value: p, child: Text(p));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _progress = v;
                                    _isDirty = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SubmenuTabs(
              tabs: [
                if (widget.fromGroupedView)
                  widget.lang == 'cn' ? '返回' : 'Back',
                widget.lang == 'cn' ? '保存' : 'Save',
                widget.lang == 'cn' ? '删除' : 'Delete',
              ],
              selectedTab: '',
              onTabSelected: (tab) {
                final cnBack = widget.lang == 'cn' ? '返回' : 'Back';
                final cnSave = widget.lang == 'cn' ? '保存' : 'Save';
                final cnDelete = widget.lang == 'cn' ? '删除' : 'Delete';

                if (tab == cnBack) {
                  Navigator.of(context).pop(true); // return true to trigger grouped view reload
                } else if (tab == cnSave) {
                  _save();
                } else if (tab == cnDelete) {
                  _delete();
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
