import 'dart:io';
import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/colored_label.dart';
import '../components/html_preview.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/knowledge_outline.dart';
import '../database/db_helper.dart';

class KnowledgePointDetailPage extends StatefulWidget {
  final String lang;
  final KnowledgePoint point;
  final KnowledgePointDao knowledgePointDao;
  final VoidCallback onHomeTap;

  const KnowledgePointDetailPage({
    super.key,
    this.lang = 'cn',
    required this.point,
    required this.knowledgePointDao,
    required this.onHomeTap,
  });

  @override
  State<KnowledgePointDetailPage> createState() => _KnowledgePointDetailPageState();
}

class _KnowledgePointDetailPageState extends State<KnowledgePointDetailPage> {
  late KnowledgePoint _point;
  late TextEditingController _titleController;
  String _selectedCid = '';
  String? _selectedUnitNumber;
  String? _selectedLessonNumber;
  List<KnowledgeOutline> _cidOptions = [];
  bool _isLoadingOptions = true;

  @override
  void initState() {
    super.initState();
    _point = widget.point;
    _titleController = TextEditingController(text: _point.title);
    _selectedCid = _point.cid;
    _selectedUnitNumber = _point.unitNumber;
    _selectedLessonNumber = _point.lessonNumber;
    
    _loadCidOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadCidOptions() async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgeOutlineDao(db);
    final all = await dao.getAll();
    if (mounted) {
      setState(() {
        _cidOptions = all;
        _isLoadingOptions = false;
      });
    }
  }

  Widget _buildLabelValue(String label, String? value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value ?? '',
        style: const TextStyle(color: Colors.black87, fontSize: 12),
      ),
    );
  }

  Future<void> _savePoint() async {
    final updated = _point.copyWith(
      title: _titleController.text.trim(),
      cid: _selectedCid,
      unitNumber: _selectedUnitNumber,
      lessonNumber: _selectedLessonNumber,
    );
    
    await widget.knowledgePointDao.update(updated);
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
      await widget.knowledgePointDao.delete(_point.id!);
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
      backgroundColor: const Color(0xFFFFE4E9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理 - 知识点详情' : 'My AI Language Assistant - Knowledge Detail',
            ),
            Expanded(
              child: Column(
                children: [
                  // 标签区域（固定在顶部）
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 知识点ID和标题
                          Row(
                            children: [
                              Text(
                                '${_point.kid ?? ""} ',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              Expanded(
                                child: Text(
                                  _point.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 可编辑标签行
                          if (_isLoadingOptions)
                            const Center(child: CircularProgressIndicator())
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // 分类标签 - 可编辑下拉
                                _buildEditableDropdown(
                                  '分类',
                                  _selectedCid,
                                  const Color(0xFFE0FFFF),
                                  _cidOptions.map((e) => e.cid).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedCid = value ?? '');
                                  },
                                ),
                                // 单元标签 - 可编辑下拉
                                _buildEditableUnitDropdown(
                                  '单元',
                                  _selectedUnitNumber,
                                  const Color(0xFFE6E6FA),
                                  (value) {
                                    setState(() => _selectedUnitNumber = value);
                                  },
                                ),
                                // 课号标签 - 可编辑下拉
                                _buildEditableUnitDropdown(
                                  '课号',
                                  _selectedLessonNumber,
                                  const Color(0xFFE6E6FA),
                                  (value) {
                                    setState(() => _selectedLessonNumber = value);
                                  },
                                ),
                                // 测试次数 - 只读
                                if (_point.testTimes > 0)
                                  _buildLabelValue('练习', '${_point.testTimes}次', const Color(0xFF90EE90)),
                                // 错误次数 - 只读
                                if (_point.errorTimes > 0)
                                  _buildLabelValue('错误', '${_point.errorTimes}次', const Color(0xFFFFB6C1)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 内容区域
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildHtmlPreview(),
                    ),
                  ),
                ],
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
                  _savePoint();
                } else if (tab == cnDelete) {
                  _deleteRecord();
                }
              },
              useGlobalHome: true,
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableDropdown(
    String label,
    String value,
    Color bgColor,
    List<String> options, {
    required Function(String?) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 中文标签名显示在左侧
        Text(
          '$label:',
          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        // 下拉选择框
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : null,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              hint: Text(widget.lang == 'cn' ? '请选择' : 'Select', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableUnitDropdown(
    String label,
    String? value,
    Color bgColor,
    Function(String?) onChanged,
  ) {
    final options = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 中文标签名显示在左侧
        Text(
          '$label:',
          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        // 下拉选择框
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              hint: Text(widget.lang == 'cn' ? '请选择' : 'Select', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(widget.lang == 'cn' ? '请选择' : 'Select', style: const TextStyle(fontSize: 12)),
                ),
                ...options.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, style: const TextStyle(fontSize: 12)),
                  );
                }),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHtmlPreview() {
    if (_point.contentPath == null) {
      return Container(
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
              widget.lang == 'cn' ? '详细内容' : 'Detailed Content',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              widget.lang == 'cn' ? '（暂无内容）' : '(No content)',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return HtmlPreview(
      filePath: _point.contentPath,
      showAppBar: false,
    );
  }
}
