import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/tag_styles.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/knowledge_outline.dart';
import '../database/db_helper.dart';

class KnowledgePointDetailPage extends StatefulWidget {
  final String lang;
  final KnowledgePoint point;
  final VoidCallback onHomeTap;

  const KnowledgePointDetailPage({
    super.key,
    this.lang = 'cn',
    required this.point,
    required this.onHomeTap,
  });

  @override
  State<KnowledgePointDetailPage> createState() => _KnowledgePointDetailPageState();
}

class _KnowledgePointDetailPageState extends State<KnowledgePointDetailPage> {
  late KnowledgePoint _point;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _cidController;
  late TextEditingController _unitNumberController;
  late TextEditingController _lessonNumberController;
  
  String? _cidTitle;
  TextEditingController _cidSearchController = TextEditingController();
  String _cidSearchText = '';
  List<KnowledgeOutline> _cidOptions = [];

  @override
  void initState() {
    super.initState();
    _point = widget.point;
    _titleController = TextEditingController(text: _point.title);
    _cidController = TextEditingController(text: _point.cid);
    _contentController = TextEditingController(text: '');
    _unitNumberController = TextEditingController(text: _point.unitNumber ?? '');
    _lessonNumberController = TextEditingController(text: _point.lessonNumber ?? '');
    
    _loadCidOptions();
  }
  
  Future<void> _loadCidOptions() async {
    final db = await DatabaseHelper().database;
    final outlineDao = KnowledgeOutlineDao(db);
    final outlines = await outlineDao.getAll(lang: widget.lang);
    setState(() {
      _cidOptions = outlines;
      if (_point.cid.isNotEmpty) {
        final found = outlines.firstWhere(
          (o) => o.cid == _point.cid,
          orElse: () => KnowledgeOutline(cid: '', content: '', lang: widget.lang),
        );
        _cidTitle = found.content;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cidController.dispose();
    _contentController.dispose();
    _unitNumberController.dispose();
    _lessonNumberController.dispose();
    _cidSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    final updated = _point.copyWith(
      title: _titleController.text.trim(),
      cid: _cidController.text.trim(),
      unitNumber: _unitNumberController.text.trim().isEmpty ? null : _unitNumberController.text.trim(),
      lessonNumber: _lessonNumberController.text.trim().isEmpty ? null : _lessonNumberController.text.trim(),
    );

    final db = await DatabaseHelper().database;
    final kpDao = KnowledgePointDao(db);
    await kpDao.update(updated);

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
            ? '确定要删除知识点 "${_point.title}" 吗？'
            : 'Delete this knowledge point?'),
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
      final kpDao = KnowledgePointDao(db);
      await kpDao.delete(_point.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _selectCid(String cid, String content) {
    setState(() {
      _cidController.text = cid;
      _cidTitle = content;
      _cidSearchText = '';
      _cidSearchController.clear();
    });
    Navigator.pop(context);
  }

  List<KnowledgeOutline> _getFilteredCidOptions() {
    if (_cidSearchText.isEmpty) {
      return _cidOptions;
    }
    return _cidOptions.where((option) => 
      option.cid.contains(_cidSearchText) ||
      option.content.contains(_cidSearchText)
    ).toList();
  }

  void _showCidSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '选择类ID' : 'Select Class ID'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _cidSearchController,
                decoration: InputDecoration(
                  hintText: widget.lang == 'cn' ? '搜索类ID或名称...' : 'Search class ID or name...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: (value) {
                  setState(() {
                    _cidSearchText = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Column(
                    children: _getFilteredCidOptions().map((option) {
                      return InkWell(
                        onTap: () => _selectCid(option.cid, option.content),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              TagStyles.knowledgeTag(option.cid),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(option.content, style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '取消' : 'Cancel',
      widget.lang == 'cn' ? '保存' : 'Save',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    List<String> testRecsList = _point.testRecs != null && _point.testRecs!.isNotEmpty
        ? _point.testRecs!.split(',')
        : [];
    List<String> errorRecsList = _point.errorRecs != null && _point.errorRecs!.isNotEmpty
        ? _point.errorRecs!.split(',')
        : [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '知识点详情' : 'Knowledge Point Detail',
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
                          if (_point.id != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ID: ${_point.id}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【标题】' : 'Title',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【详细内容】' : 'Detailed Content',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 类ID（CID）- 一屏宽，样式比照课内标签
                      InkWell(
                        onTap: _showCidSelector,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: TagStyles.knowledgeBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: TagStyles.knowledgeText.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '【类ID】' : 'Class ID',
                                style: TextStyle(fontWeight: FontWeight.bold, color: TagStyles.knowledgeText),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _cidController.text.isNotEmpty 
                                    ? '${_cidController.text} - ${_cidTitle ?? ''}'
                                    : (widget.lang == 'cn' ? '点击选择类ID' : 'Tap to select'),
                                style: TextStyle(color: TagStyles.knowledgeText),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 课内标签（单元+课号）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TagStyles.lessonUnitBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: TagStyles.lessonUnitText.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【课内标签】' : 'Lesson Unit',
                              style: TextStyle(fontWeight: FontWeight.bold, color: TagStyles.lessonUnitText),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _unitNumberController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: widget.lang == 'cn' ? '单元号' : 'Unit No.',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('+'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _lessonNumberController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: widget.lang == 'cn' ? '课号' : 'Lesson No.',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_unitNumberController.text.isNotEmpty || _lessonNumberController.text.isNotEmpty)
                              Text(
                                '${_unitNumberController.text.isNotEmpty ? '${_unitNumberController.text}单元' : ''}'
                                '${_unitNumberController.text.isNotEmpty && _lessonNumberController.text.isNotEmpty ? ' ' : ''}'
                                '${_lessonNumberController.text.isNotEmpty ? '${_lessonNumberController.text}课' : ''}',
                                style: TextStyle(color: TagStyles.lessonUnitText),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 测试清单标签（只读）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TagStyles.exerciseBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: TagStyles.exerciseText.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【测试清单】' : 'Test Records',
                              style: TextStyle(fontWeight: FontWeight.bold, color: TagStyles.exerciseText),
                            ),
                            const SizedBox(height: 4),
                            if (testRecsList.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                children: testRecsList.map((rec) => TagStyles.exerciseTag(rec)).toList(),
                              )
                            else
                              Text(
                                widget.lang == 'cn' ? '暂无测试记录' : 'No test records',
                                style: TextStyle(color: TagStyles.exerciseText),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 错误清单标签（只读）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TagStyles.errorTypeBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: TagStyles.errorTypeText.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.lang == 'cn' ? '【错误清单】' : 'Error Records',
                              style: TextStyle(fontWeight: FontWeight.bold, color: TagStyles.errorTypeText),
                            ),
                            const SizedBox(height: 4),
                            if (errorRecsList.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                children: errorRecsList.map((rec) => TagStyles.errorTypeTag(rec)).toList(),
                              )
                            else
                              Text(
                                widget.lang == 'cn' ? '暂无错误记录' : 'No error records',
                                style: TextStyle(color: TagStyles.errorTypeText),
                              ),
                          ],
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