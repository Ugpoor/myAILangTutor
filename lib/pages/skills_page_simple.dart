import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';
import '../database/db_helper.dart';
import '../database/models/skill.dart';
import 'skill_detail_page.dart';

class SkillsPageSimple extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const SkillsPageSimple({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<SkillsPageSimple> createState() => _SkillsPageSimpleState();
}

class _SkillsPageSimpleState extends State<SkillsPageSimple> {
  List<Skill> _allSkills = [];
  List<Skill> _displaySkills = [];
  final Set<int> _selectedIds = {};
  String? _filterCategory;
  late SkillDao _skillDao;

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _skillDao = SkillDao(db);
    await _loadSkills();
  }

  Future<void> _loadSkills() async {
    final skills = await _skillDao.getAll(lang: widget.lang);
    setState(() {
      _allSkills = skills;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_filterCategory == null) {
      _displaySkills = List.from(_allSkills);
    } else {
      _displaySkills = _allSkills.where((s) => s.category == _filterCategory).toList();
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.lang == 'cn' ? '已复制到剪贴板' : 'Copied to clipboard')),
    );
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '新增' : 'Add')) {
      await _navigateToDetail(null);
    } else if (tab == (widget.lang == 'cn' ? '技能树' : 'Skill Tree')) {
      _showSkillTreeDialog();
    }
  }

  Future<void> _navigateToDetail(Skill? skill) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SkillDetailPage(
          lang: widget.lang,
          skill: skill,
          skillDao: _skillDao,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
    if (result == true) {
      await _loadSkills();
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '筛选技能' : 'Filter Skills'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(widget.lang == 'cn' ? '按分类筛选：' : 'Filter by category:'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterCategory = '内部';
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('内部'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterCategory = '外部';
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('外部'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterCategory = null;
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                  child: Text(widget.lang == 'cn' ? '全部' : 'All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSkillTreeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '技能树' : 'Skill Tree'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: widget.lang == 'cn' ? '输入技能ID（如S1）' : 'Enter skill ID (e.g. S1)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSkillTree(controller.text.trim());
            },
            child: Text(widget.lang == 'cn' ? '查看' : 'View'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSkillTree(String skillId) async {
    final target = await _skillDao.getBySkillId(skillId);
    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '未找到该技能' : 'Skill not found')),
        );
      }
      return;
    }

    final parent = target.prerequisite != null
        ? await _skillDao.getBySkillId(target.prerequisite!)
        : null;
    final children = await _skillDao.getChildrenOf(skillId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.lang == 'cn' ? '技能树' : 'Skill Tree'}: $skillId'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parent != null) ...[
                Text(
                  '${widget.lang == 'cn' ? '父技能' : 'Parent'}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildSkillTreeItem(parent),
                const Divider(),
              ],
              Text(
                '${widget.lang == 'cn' ? '当前技能' : 'Current'}:',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF69B4)),
              ),
              _buildSkillTreeItem(target),
              const Divider(),
              if (children.isNotEmpty) ...[
                Text(
                  '${widget.lang == 'cn' ? '子技能' : 'Children'}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...children.map((c) => _buildSkillTreeItem(c)),
              ] else ...[
                Text(
                  widget.lang == 'cn' ? '暂无子技能' : 'No child skills',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillTreeItem(Skill skill) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('${skill.skillId} ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(skill.name),
          const SizedBox(width: 8),
          Chip(
            label: Text(skill.category ?? '', style: const TextStyle(fontSize: 10)),
            backgroundColor: skill.category == '内部'
                ? const Color(0xFF87CEEB)
                : const Color(0xFF98FB98),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn' ? ['筛选', '新增', '技能树'] : ['Filter', 'Add', 'Skill Tree'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-技能库' : 'My AI Language Tutor - Skills',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'skills',
              onPullDown: widget.onPullDown ?? () {},
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _displaySkills.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无技能' : 'No skills'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displaySkills.length,
                        itemBuilder: (context, index) {
                          final skill = _displaySkills[index];
                          return _buildSkillItem(skill);
                        },
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: _handleTabSelected,
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
            InputArea(
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillItem(Skill skill) {
    final isSelected = _selectedIds.contains(skill.id);
    final categoryColor = skill.category == '内部' ? const Color(0xFF87CEEB) : const Color(0xFF98FB98);
    final isExternal = skill.category == '外部';
    final hasContent = skill.contentPath != null && skill.contentPath!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _navigateToDetail(skill),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedIds.add(skill.id!);
                            } else {
                              _selectedIds.remove(skill.id!);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${skill.skillId ?? ""} ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(child: Text(skill.name)),
                                const SizedBox(width: 8),
                                if (skill.category != null)
                                  Chip(
                                    label: Text(skill.category!, style: const TextStyle(fontSize: 10)),
                                    backgroundColor: categoryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    labelStyle: const TextStyle(fontSize: 10),
                                  ),
                                if (skill.prerequisite != null) ...[
                                  const SizedBox(width: 4),
                                  Chip(
                                    label: Text('前置:${skill.prerequisite}', style: const TextStyle(fontSize: 9)),
                                    backgroundColor: Colors.orange[100],
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (skill.description != null && skill.description!.isNotEmpty)
                              Text(
                                skill.description!,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isExternal && skill.promptText != null && skill.promptText!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              skill.promptText!,
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _copyToClipboard(skill.promptText!),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF651FFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            child: Text(
                              widget.lang == 'cn' ? '复制' : 'Copy',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isExternal && skill.internalFunction != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.settings, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.lang == 'cn' ? "内部函数" : "Internal"}: ${skill.internalFunction}',
                            style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 内容指示和预览按钮（如果有关联内容）
          if (hasContent)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: OutlinedButton.icon(
                onPressed: () => _previewContent(skill.contentPath!),
                icon: const Icon(Icons.html, size: 16),
                label: Text(widget.lang == 'cn' ? '在线阅读' : 'Read Online'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF651FFF),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 预览技能关联的HTML内容
  Future<void> _previewContent(String contentPath) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HtmlPreviewPage(
          lang: widget.lang,
          filePath: contentPath,
        ),
      ),
    );
  }
}

/// HTML预览页面 - 用于显示技能关联的网页内容
class HtmlPreviewPage extends StatefulWidget {
  final String lang;
  final String filePath;

  const HtmlPreviewPage({
    super.key,
    required this.lang,
    required this.filePath,
  });

  @override
  State<HtmlPreviewPage> createState() => _HtmlPreviewPageState();
}

class _HtmlPreviewPageState extends State<HtmlPreviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage = error.description;
            });
          },
        ),
      );

    await _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final indexPath = '${widget.filePath}/index.html';
      final file = File(indexPath);
      if (await file.exists()) {
        final content = await file.readAsString(encoding: utf8);
        await _controller.loadHtmlString(content);
      } else {
        throw Exception('File not found: $indexPath');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lang == 'cn' ? '在线阅读' : 'Read Online'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadContent,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载...'),
          ],
        ),
      );
    }

    return WebViewWidget(controller: _controller);
  }
}
