import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/dynamic_tag_selector.dart';
import '../database/db_helper.dart';
import '../database/models/portfolio_item.dart';
import 'package:path_provider/path_provider.dart';
import 'portfolio_detail_page.dart';

class PortfolioPageSimple extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const PortfolioPageSimple({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<PortfolioPageSimple> createState() => _PortfolioPageSimpleState();
}

class _PortfolioPageSimpleState extends State<PortfolioPageSimple> {
  List<PortfolioItem> _allItems = [];
  List<PortfolioItem> _displayItems = [];
  final Set<int> _selectedIds = {};
  Set<String> _filterKnowledgeTags = {};
  Set<String> _filterLessonUnits = {};
  bool? _filterIsOriginal;
  late PortfolioDao _portfolioDao;

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _portfolioDao = PortfolioDao(db);
    await _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _portfolioDao.getAll(lang: widget.lang);
    setState(() {
      _allItems = items;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _displayItems = _allItems.where((item) {
      if (_filterIsOriginal != null && item.isOriginal != _filterIsOriginal) return false;
      if (_filterKnowledgeTags.isNotEmpty && !_filterKnowledgeTags.any((tag) => item.knowledgeTag?.contains(tag) ?? false)) return false;
      if (_filterLessonUnits.isNotEmpty && !_filterLessonUnits.any((unit) => item.lessonUnit?.contains(unit) ?? false)) return false;
      return true;
    }).toList();
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '原创' : 'Original')) {
      _navigateToNewOriginal();
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      _generateExercisesForSelected();
    }
  }

  Future<void> _navigateToDetail(PortfolioItem item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PortfolioDetailPage(
          lang: widget.lang,
          item: item,
          portfolioDao: _portfolioDao,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
    if (result == true) {
      await _loadItems();
    }
  }

  Future<void> _navigateToNewOriginal() async {
    final nextNum = await _portfolioDao.nextPortfolioIdNumber();
    final newItem = PortfolioItem(
      title: widget.lang == 'cn' ? '新原创作品' : 'New Original',
      portfolioId: 'W$nextNum',
      isOriginal: true,
      createdAt: DateTime.now(),
      lang: widget.lang,
    );
    final id = await _portfolioDao.insert(newItem);
    final created = await _portfolioDao.getById(id);
    if (created != null && mounted) {
      await _navigateToDetail(created);
    }
  }

  Future<void> _generateExercisesForSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择非原创作品' : 'Select non-original items first')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.lang == 'cn' ? '练习生成功能开发中' : 'Exercise generation in development')),
    );
  }

  void _showFilterDialog() {
    final knowledgeTags = _allItems.map((i) => i.knowledgeTag).whereType<String>().toSet().toList();
    final lessonUnits = _allItems.map((i) => i.lessonUnit).whereType<String>().toSet().toList();
    final selectedKTags = Set<String>.from(_filterKnowledgeTags);
    final selectedLUnits = Set<String>.from(_filterLessonUnits);
    bool? tempIsOriginal = _filterIsOriginal;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(widget.lang == 'cn' ? '筛选作品' : 'Filter Portfolio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 原创/赏析筛选（单选）
                Text(widget.lang == 'cn' ? '类型：' : 'Type:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    FilterChip(
                      label: Text(widget.lang == 'cn' ? '原创' : 'Original',
                          style: const TextStyle(fontSize: 12)),
                      selected: tempIsOriginal == true,
                      onSelected: (_) {
                        setState(() => tempIsOriginal = true);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(widget.lang == 'cn' ? '赏析' : 'Analysis',
                          style: const TextStyle(fontSize: 12)),
                      selected: tempIsOriginal == false,
                      onSelected: (_) {
                        setState(() => tempIsOriginal = false);
                      },
                    ),
                  ],
                ),
                const Divider(height: 24),
                // 知识点标签筛选（多选）
                Text(widget.lang == 'cn' ? '知识点标签：' : 'Knowledge tags:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (knowledgeTags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    children: knowledgeTags.map((tag) => FilterChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      selected: selectedKTags.contains(tag),
                      onSelected: (_) {
                        setState(() {
                          selectedKTags.contains(tag) ? selectedKTags.remove(tag) : selectedKTags.add(tag);
                        });
                      },
                    )).toList(),
                  ),
                ],
                const Divider(height: 24),
                // 课内标签筛选（多选）
                Text(widget.lang == 'cn' ? '课内标签：' : 'Lesson units:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (lessonUnits.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    children: lessonUnits.map((unit) => FilterChip(
                      label: Text(unit, style: const TextStyle(fontSize: 11)),
                      selected: selectedLUnits.contains(unit),
                      onSelected: (_) {
                        setState(() {
                          selectedLUnits.contains(unit) ? selectedLUnits.remove(unit) : selectedLUnits.add(unit);
                        });
                      },
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filterIsOriginal = null;
                  _filterKnowledgeTags.clear();
                  _filterLessonUnits.clear();
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              child: Text(widget.lang == 'cn' ? '清空' : 'Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterIsOriginal = tempIsOriginal;
                  _filterKnowledgeTags = selectedKTags;
                  _filterLessonUnits = selectedLUnits;
                  _applyFilter();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF69B4)),
              child: Text(widget.lang == 'cn' ? '确定' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '原创', '练习']
        : ['Filter', 'Original', 'Practice'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-作品集' : 'My AI Language Tutor - Portfolio',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'portfolio',
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
                child: _displayItems.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无作品' : 'No portfolio items'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayItems.length,
                        itemBuilder: (context, index) {
                          final item = _displayItems[index];
                          return _buildPortfolioItem(item);
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

  Widget _buildPortfolioItem(PortfolioItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _navigateToDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(item.id!);
                    } else {
                      _selectedIds.remove(item.id!);
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
                          '${item.portfolioId ?? ""} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(item.title)),
                        if (item.isOriginal)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Chip(
                              label: Text(widget.lang == 'cn' ? '原创' : 'Original'),
                              backgroundColor: const Color(0xFFDDA0DD),
                              labelStyle: const TextStyle(fontSize: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (item.lessonUnit != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                            child: Text('课内: ${item.lessonUnit}', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                          ),
                        if (item.knowledgeTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                            child: Text('知识: ${item.knowledgeTag}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                          ),
                        if (item.aiReview != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(4)),
                            child: Text(widget.lang == 'cn' ? '已评析' : 'Reviewed', style: const TextStyle(fontSize: 11, color: Colors.purple)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
