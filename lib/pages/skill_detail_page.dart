import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/skill.dart';

class SkillDetailPage extends StatefulWidget {
  final String lang;
  final Skill? skill;
  final SkillDao skillDao;
  final VoidCallback onHomeTap;

  const SkillDetailPage({
    super.key,
    this.lang = 'cn',
    this.skill,
    required this.skillDao,
    required this.onHomeTap,
  });

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _promptController;
  late TextEditingController _descriptionController;
  late TextEditingController _parametersController;
  late TextEditingController _returnTypeController;
  String _category = '外部';
  String? _prerequisite;
  String? _internalFunction;
  bool _isDirty = false;

  final List<String> _internalFunctions = [
    '练习题批改',
    '知识点梳理',
    '练习题生成',
    '同义词辨析',
    '作文点评',
    '名篇赏析',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.skill?.name ?? '');
    _promptController = TextEditingController(text: widget.skill?.promptText ?? '');
    _descriptionController = TextEditingController(text: widget.skill?.description ?? '');
    _parametersController = TextEditingController(text: widget.skill?.parameters ?? '');
    _returnTypeController = TextEditingController(text: widget.skill?.returnType ?? '');
    _category = widget.skill?.category ?? '外部';
    _prerequisite = widget.skill?.prerequisite;
    _internalFunction = widget.skill?.internalFunction;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _descriptionController.dispose();
    _parametersController.dispose();
    _returnTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveSkill() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请输入技能名称' : 'Please enter skill name')),
      );
      return;
    }

    if (widget.skill == null) {
      // 新增技能
      final nextNum = await widget.skillDao.nextSkillIdNumber();
      final newSkill = Skill(
        name: _nameController.text.trim(),
        skillId: 'S$nextNum',
        category: _category,
        prerequisite: _prerequisite,
        promptText: _category == '外部' ? _promptController.text.trim() : null,
        internalFunction: _category == '内部' ? _internalFunction : null,
        parameters: _category == '内部' ? _parametersController.text.trim() : null,
        returnType: _category == '内部' ? _returnTypeController.text.trim() : null,
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        lang: widget.lang,
      );
      await widget.skillDao.insert(newSkill);
    } else {
      // 更新技能
      final updated = widget.skill!.copyWith(
        name: _nameController.text.trim(),
        category: _category,
        prerequisite: _prerequisite,
        promptText: _category == '外部' ? _promptController.text.trim() : null,
        internalFunction: _category == '内部' ? _internalFunction : null,
        parameters: _category == '内部' ? _parametersController.text.trim() : null,
        returnType: _category == '内部' ? _returnTypeController.text.trim() : null,
        description: _descriptionController.text.trim(),
      );
      await widget.skillDao.update(updated);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteSkill() async {
    if (widget.skill == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除技能 "${widget.skill!.name}" 吗？'
            : 'Are you sure you want to delete "${widget.skill!.name}"?'),
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
      await widget.skillDao.delete(widget.skill!.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  void _copyPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.lang == 'cn' ? '提示语已复制到剪贴板' : 'Prompt copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExternal = _category == '外部';
    final tabs = isExternal
        ? [widget.lang == 'cn' ? '复制提示' : 'Copy', widget.lang == 'cn' ? '取消' : 'Cancel', widget.lang == 'cn' ? '保存' : 'Save', widget.lang == 'cn' ? '删除' : 'Delete']
        : [widget.lang == 'cn' ? '取消' : 'Cancel', widget.lang == 'cn' ? '保存' : 'Save', widget.lang == 'cn' ? '删除' : 'Delete'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '技能${widget.skill != null ? "编辑" : "新增"}'
                  : '${widget.skill != null ? "Edit" : "New"} Skill',
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
                      // 技能ID
                      if (widget.skill != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Text(
                                '${widget.skill!.skillId ?? ""} ',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      // 名称
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '技能名称' : 'Skill Name',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _isDirty = true),
                      ),
                      const SizedBox(height: 16),
                      // 分类标签
                      Row(
                        children: [
                          Text(
                            widget.lang == 'cn' ? '分类：' : 'Category: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('内部'),
                            selected: _category == '内部',
                            onSelected: (selected) {
                              setState(() {
                                _category = selected ? '内部' : '外部';
                                _isDirty = true;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('外部'),
                            selected: _category == '外部',
                            onSelected: (selected) {
                              setState(() {
                                _category = selected ? '外部' : '内部';
                                _isDirty = true;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 前置技能
                      FutureBuilder<List<Skill>>(
                        future: widget.skillDao.getAll(lang: widget.lang),
                        builder: (context, snapshot) {
                          final allSkills = snapshot.data ?? [];
                          final otherSkills = allSkills.where((s) => s.id != widget.skill?.id).toList();
                          return DropdownButtonFormField<String>(
                            value: _prerequisite,
                            decoration: InputDecoration(
                              labelText: widget.lang == 'cn' ? '前置技能' : 'Prerequisite',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(widget.lang == 'cn' ? '无' : 'None'),
                              ),
                              ...otherSkills.map((s) => DropdownMenuItem<String>(
                                value: s.skillId,
                                child: Text('${s.skillId} - ${s.name}'),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _prerequisite = value;
                                _isDirty = true;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // 内部/外部区分内容
                      if (_category == '内部') ...[
                        // 内部函数选择
                        DropdownButtonFormField<String>(
                          value: _internalFunction,
                          decoration: InputDecoration(
                            labelText: widget.lang == 'cn' ? '执行内部函数' : 'Internal Function',
                            border: const OutlineInputBorder(),
                          ),
                          items: _internalFunctions.map((f) => DropdownMenuItem<String>(
                            value: f,
                            child: Text(f),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _internalFunction = value;
                              _isDirty = true;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _parametersController,
                          decoration: InputDecoration(
                            labelText: widget.lang == 'cn' ? '参数' : 'Parameters',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _isDirty = true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _returnTypeController,
                          decoration: InputDecoration(
                            labelText: widget.lang == 'cn' ? '返回值类型' : 'Return Type',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _isDirty = true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: widget.lang == 'cn' ? '解释：函数功能和参数说明' : 'Description: function and parameters',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _isDirty = true),
                        ),
                      ] else ...[
                        // 外部技能：提示语 + 使用说明
                        TextField(
                          controller: _promptController,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: widget.lang == 'cn' ? '提示语' : 'Prompt',
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) => setState(() => _isDirty = true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 4,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: widget.lang == 'cn' ? '使用说明' : 'Usage Instructions',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ],
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
                final cnCopy = widget.lang == 'cn' ? '复制提示' : 'Copy';

                if (tab == cnCancel) {
                  Navigator.of(context).pop(false);
                } else if (tab == cnSave) {
                  _saveSkill();
                } else if (tab == cnDelete) {
                  _deleteSkill();
                } else if (tab == cnCopy) {
                  _copyPrompt();
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
