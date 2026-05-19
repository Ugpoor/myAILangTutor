import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/error_record.dart';

class ErrorDetailPage extends StatefulWidget {
  final String lang;
  final ErrorRecord record;
  final ErrorRecordDao errorRecordDao;
  final VoidCallback onHomeTap;

  const ErrorDetailPage({
    super.key,
    this.lang = 'cn',
    required this.record,
    required this.errorRecordDao,
    required this.onHomeTap,
  });

  @override
  State<ErrorDetailPage> createState() => _ErrorDetailPageState();
}

class _ErrorDetailPageState extends State<ErrorDetailPage> {
  late ErrorRecord _record;
  late TextEditingController _questionController;
  late TextEditingController _wrongAnswerController;
  late TextEditingController _wrongWhereController;
  late TextEditingController _whyWrongController;
  late TextEditingController _howPreventController;
  late TextEditingController _notesController;
  String? _errorType;
  String? _knowledgeTag;
  String _progress = '待订正';

  final List<String> _errorTypes = [
    '审题不清', '概念混淆', '计算失误', '知识遗漏', '推理错误', '表达不当',
  ];

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _questionController = TextEditingController(text: _record.question ?? '');
    _wrongAnswerController = TextEditingController(text: _record.wrongAnswer ?? '');
    _wrongWhereController = TextEditingController(text: _record.wrongWhere ?? '');
    _whyWrongController = TextEditingController(text: _record.whyWrong ?? '');
    _howPreventController = TextEditingController(text: _record.howPrevent ?? '');
    _notesController = TextEditingController(text: _record.notes ?? '');
    _errorType = _record.errorType;
    _knowledgeTag = _record.knowledgeTag;
    _progress = _record.progress;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _wrongAnswerController.dispose();
    _wrongWhereController.dispose();
    _whyWrongController.dispose();
    _howPreventController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    final updated = _record.copyWith(
      question: _questionController.text.trim(),
      wrongAnswer: _wrongAnswerController.text.trim(),
      wrongWhere: _wrongWhereController.text.trim(),
      whyWrong: _whyWrongController.text.trim(),
      howPrevent: _howPreventController.text.trim(),
      notes: _notesController.text.trim(),
      errorType: _errorType,
      knowledgeTag: _knowledgeTag,
      progress: _progress,
      reviewed: _progress == '已订正',
    );
    await widget.errorRecordDao.update(updated);
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
            ? '确定要删除错误记录 "${_record.errorId ?? _record.content}" 吗？'
            : 'Delete this error record?'),
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
      await widget.errorRecordDao.delete(_record.id!);
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
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '错误详情' : 'Error Detail',
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
                          Text(
                            '${_record.errorId ?? ""} ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF5252)),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _progress == '已订正' ? Colors.green[100] : Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _progress,
                              style: TextStyle(
                                color: _progress == '已订正' ? Colors.green[800] : Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 题目
                      TextField(
                        controller: _questionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【题目】' : 'Question',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 我的答案
                      TextField(
                        controller: _wrongAnswerController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【我的答案】' : 'My Answer',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 正确答案（只读）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【正确答案】' : 'Correct Answer',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _record.correctAnswer ?? (widget.lang == 'cn' ? '未填写' : 'Not filled'),
                              style: TextStyle(color: Colors.green[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 错在哪里
                      TextField(
                        controller: _wrongWhereController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【错在哪里】' : 'Where wrong',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 为什么错
                      TextField(
                        controller: _whyWrongController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【为什么错】' : 'Why wrong',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 如何避免
                      TextField(
                        controller: _howPreventController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【如何避免】' : 'How to prevent',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 错类标签
                      DropdownButtonFormField<String>(
                        initialValue: _errorType,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '错类' : 'Error Type',
                          border: const OutlineInputBorder(),
                        ),
                        items: _errorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _errorType = v),
                      ),
                      const SizedBox(height: 12),
                      // 知识标签
                      TextField(
                        controller: TextEditingController(text: _knowledgeTag ?? ''),
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '知识标签' : 'Knowledge Tag',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _knowledgeTag = v.isEmpty ? null : v,
                      ),
                      const SizedBox(height: 12),
                      // 备注
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '备注' : 'Notes',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: tabs[0],
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
}
