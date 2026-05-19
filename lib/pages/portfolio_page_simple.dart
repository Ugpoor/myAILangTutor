import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../database/db_helper.dart';
import '../database/models/portfolio_item.dart';
import 'portfolio_detail_page.dart';

class PortfolioPageSimple extends StatefulWidget {
  final String lang;
  final String messages;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const PortfolioPageSimple({
    super.key,
    this.lang = 'cn',
    required this.messages,
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
  bool? _filterIsOriginal;
  String? _filterKnowledgeTag;
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
      if (_filterKnowledgeTag != null &&
          (item.knowledgeTag == null || !item.knowledgeTag!.contains(_filterKnowledgeTag!))) {
        return false;
      }
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
    } else if (tab == (widget.lang == 'cn' ? '评析' : 'Analyze')) {
      _aiAnalyzeSelected();
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

  Future<void> _aiAnalyzeSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择作品' : 'Select items first')),
      );
      return;
    }
    // Navigate to first selected item for AI review
    final firstItem = _allItems.firstWhere((item) => _selectedIds.contains(item.id));
    await _navigateToDetail(firstItem);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '筛选作品' : 'Filter Portfolio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.lang == 'cn' ? '按类型筛选：' : 'Filter by type:'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterIsOriginal = true;
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                  child: Text(widget.lang == 'cn' ? '原创' : 'Original'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterIsOriginal = false;
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                  child: Text(widget.lang == 'cn' ? '赏析' : 'Analysis'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterIsOriginal = null;
                      _filterKnowledgeTag = null;
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

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '原创', '练习', '评析']
        : ['Filter', 'Original', 'Practice', 'Analyze'];

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
              messages: widget.messages ?? [],
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
              selectedTab: tabs[0],
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
