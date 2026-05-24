import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/error_record.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/question.dart';
import '../database/db_helper.dart';

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
  List<String> _eids = [];
  String? _kid;
  String _progress = '待订正';
  
  TextEditingController _errorTypeSearchController = TextEditingController();
  String _errorTypeSearchText = '';
  
  // 新增：知识点信息
  String? _knowledgeTitle;
  String? _knowledgeContent;
  
  // 新增：习题信息
  String? _exerciseTitle;
  
  final List<Map<String, String>> _errorTypeOptions = [
    {'id': '1', 'name': '审题不清'},
    {'id': '1.1', 'name': '关键词忽略'},
    {'id': '1.2', 'name': '会错题意'},
    {'id': '2', 'name': '计算失误'},
    {'id': '2.1', 'name': '粗心大意'},
    {'id': '2.2', 'name': '公式错误'},
    {'id': '3', 'name': '概念混淆'},
    {'id': '3.1', 'name': '理解错误'},
    {'id': '3.2', 'name': '混淆概念'},
    {'id': '4', 'name': '知识遗漏'},
    {'id': '5', 'name': '推理错误'},
    {'id': '6', 'name': '表达不当'},
    {'id': '6.1', 'name': '语句不通'},
    {'id': '6.2', 'name': '用词不当'},
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
    _eids = _record.eids;
    _kid = _record.kid;
    _progress = _record.progress;
    
    _loadRelatedData();
  }
  
  Future<void> _loadRelatedData() async {
    final db = await DatabaseHelper().database;
    
    // 获取知识点信息
    if (_record.kid != null) {
      final kpDao = KnowledgePointDao(db);
      final points = await kpDao.getAll(lang: widget.lang);
      final found = points.firstWhere(
          (p) => p.kid == _record.kid,
          orElse: () => KnowledgePoint(id: 0, title: '', cid: '', lang: widget.lang),
        );
      if (mounted) {
        setState(() {
          _knowledgeTitle = found.title;
          _knowledgeContent = found.brief;
        });
      }
    }
    
    // 获取习题信息
    if (_record.tid != null && _record.qid != null) {
      final exDao = QuestionDao(db);
      final exercises = await exDao.getAll();
      final found = exercises.firstWhere(
        (e) => e.exerciseId == '${_record.tid}Q${_record.qid}',
        orElse: () => Question(id: 0, question: '', lang: widget.lang),
      );
      if (mounted) {
        setState(() {
          _exerciseTitle = found.question;
        });
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _wrongAnswerController.dispose();
    _wrongWhereController.dispose();
    _whyWrongController.dispose();
    _howPreventController.dispose();
    _notesController.dispose();
    _errorTypeSearchController.dispose();
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
      eids: _eids,
      kid: _kid,
      progress: _progress,
    );
    
    await widget.errorRecordDao.update(updated);
    
    final newRecord = await widget.errorRecordDao.getById(updated.id!);
    if (newRecord != null && newRecord.progress == '待订正') {
      final hasAllContent = 
          (updated.question?.isNotEmpty ?? false) &&
          (updated.wrongAnswer?.isNotEmpty ?? false) &&
          (updated.wrongWhere?.isNotEmpty ?? false) &&
          (updated.whyWrong?.isNotEmpty ?? false) &&
          (updated.howPrevent?.isNotEmpty ?? false) &&
          (newRecord.correctAnswer?.isNotEmpty ?? false);
      
      if (hasAllContent && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(widget.lang == 'cn' ? '自动标记为已订正' : 'Auto-Mark as Completed'),
            content: Text(widget.lang == 'cn' 
                ? '所有关键字段已填写完毕，是否将本题标为"已订正"？' 
                : 'All required fields are filled. Mark this record as "Completed"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(widget.lang == 'cn' ? '保持待订正' : 'Keep Pending'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(widget.lang == 'cn' ? '标记已订正' : 'Mark Completed'),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          final marked = updated.copyWith(progress: '已订正');
          await widget.errorRecordDao.update(marked);
          setState(() => _progress = '已订正');
        }
      }
    }
    
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
            ? '确定要删除错误记录 "${_record.errorId ?? _record.wrongWhere}" 吗？'
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

  void _toggleErrorType(String id) {
    setState(() {
      if (_eids.contains(id)) {
        _eids.remove(id);
      } else {
        _eids.add(id);
        _eids.sort();
      }
    });
  }

  List<Map<String, String>> _getFilteredErrorTypes() {
    if (_errorTypeSearchText.isEmpty) {
      return _errorTypeOptions;
    }
    return _errorTypeOptions.where((option) => 
      option['id']!.contains(_errorTypeSearchText) ||
      option['name']!.contains(_errorTypeSearchText)
    ).toList();
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
                      
                      // 练习标签（只读，显示习题title）
                      if (_record.tid != null && _record.qid != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【练习标签】' : 'Exercise Tag',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_record.tid}Q${_record.qid}',
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                            if (_exerciseTitle != null && _exerciseTitle!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _exerciseTitle!,
                                  style: TextStyle(color: Colors.blue[600], fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 课内标签（只读）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【课内标签】' : 'Lesson Unit',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _record.unitNumber != null || _record.lessonNumber != null
                                  ? '${_record.unitNumber != null ? '${_record.unitNumber}单元' : ''}${_record.lessonNumber != null ? '${_record.unitNumber != null ? ' ' : ''}${_record.lessonNumber}课' : ''}'
                                  : (widget.lang == 'cn' ? '未设置' : 'Not set'),
                              style: TextStyle(color: Colors.purple[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 知识点标签（只读，显示内容）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.cyan[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.cyan[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【知识点标签】' : 'Knowledge Tag',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan[800]),
                            ),
                            const SizedBox(height: 4),
                            if (_record.kid != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _record.kid!,
                                    style: TextStyle(color: Colors.cyan[700]),
                                  ),
                                  if (_knowledgeTitle != null && _knowledgeTitle!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        _knowledgeTitle!,
                                        style: TextStyle(color: Colors.cyan[600], fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  if (_knowledgeContent != null && _knowledgeContent!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _knowledgeContent!,
                                        style: TextStyle(color: Colors.cyan[600], fontSize: 13),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              )
                            else
                              Text(
                                widget.lang == 'cn' ? '未设置' : 'Not set',
                                style: TextStyle(color: Colors.cyan[700]),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _questionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【题目】' : 'Question',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: _wrongAnswerController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【我的答案】' : 'My Answer',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
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
                      
                      TextField(
                        controller: _wrongWhereController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【错在哪里】' : 'Where wrong',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: _whyWrongController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【为什么错】' : 'Why wrong',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: _howPreventController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【如何避免】' : 'How to prevent',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // 错类标签（下拉复选框，支持搜索）
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【错类ID】' : 'Error Types',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            
                            TextField(
                              controller: _errorTypeSearchController,
                              decoration: InputDecoration(
                                hintText: widget.lang == 'cn' ? '搜索错类ID或名称...' : 'Search error type...',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 18),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _errorTypeSearchText = value;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            
                            // 已选标签显示
                            if (_eids.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: _eids.map((eid) {
                                  final option = _errorTypeOptions.firstWhere(
                                    (o) => o['id'] == eid,
                                    orElse: () => {'id': eid, 'name': eid},
                                  );
                                  return Chip(
                                    label: Text('${option['id']} ${option['name']}'),
                                    onDeleted: () => _toggleErrorType(eid),
                                    backgroundColor: const Color(0xFFFFE4C4),
                                    labelStyle: TextStyle(color: Colors.orange[800]),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            
                            // 可选错类列表
                            SizedBox(
                              height: 150,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: _getFilteredErrorTypes().map((option) {
                                    return CheckboxListTile(
                                      value: _eids.contains(option['id']),
                                      title: Text('${option['id']} - ${option['name']}'),
                                      onChanged: (value) => _toggleErrorType(option['id']!),
                                      controlAffinity: ListTileControlAffinity.leading,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
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