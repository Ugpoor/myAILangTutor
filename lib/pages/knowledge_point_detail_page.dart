import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/knowledge_point.dart';
import '../database/db_helper.dart';

/// 知识点详情页面（可编辑表单式）
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
  
  String? _category;
  String? _lessonUnit;
  String? _errorType;
  int _fatherId = 0;
  int _difficulty = 1;
  bool _mastered = false;
  String? _knowledgeTag;

  final List<String> _categories = [
    '字词书写', '成语运用', '古诗文默写', '阅读理解',
    '作文写作', '修辞手法', '文体知识', '文学常识',
  ];

  final List<String> _errorTypes = [
    '审题不清', '概念混淆', '计算失误', '知识遗漏', '推理错误', '表达不当',
  ];

  @override
  void initState() {
    super.initState();
    _point = widget.point;
    _titleController = TextEditingController(text: _point.title);
    _cidController = TextEditingController(text: _point.cid ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cidController.dispose();
    super.dispose();
  }

  Future<void> _saveRecord() async {
    final updated = _point.copyWith(
      title: _titleController.text.trim(),
      cid: _cidController.text.trim().isEmpty ? null : _cidController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '取消' : 'Cancel',
      widget.lang == 'cn' ? '保存' : 'Save',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

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
                      // ID + 掌握状态
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
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '已掌握' : 'Mastered',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _mastered,
                                onChanged: (v) => setState(() => _mastered = v),
                                activeColor: const Color(0xFF4CAF50),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 标题
                      TextField(
                        controller: _titleController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【标题】' : 'Title',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 详细内容
                      TextField(
                        controller: _contentController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '【详细内容】' : 'Detailed Content',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 分类标签
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
                      // 错类关联
                      DropdownButtonFormField<String>(
                        initialValue: _errorType,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '关联错类 / Error Type' : 'Error Type',
                          border: const OutlineInputBorder(),
                        ),
                        items: _errorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _errorType = v),
                      ),
                      const SizedBox(height: 12),
                      // CID
                      TextField(
                        controller: _cidController,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? 'CID / 类ID' : 'Class ID',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _cidController.text = v,
                      ),
                      const SizedBox(height: 12),
                      // Father ID
                      TextField(
                        controller: TextEditingController(text: _fatherId.toString()),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? 'Father ID / 父节点ID' : 'Father ID',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _fatherId = int.tryParse(v) ?? 0,
                      ),
                      const SizedBox(height: 12),
                      // 难度选择
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
