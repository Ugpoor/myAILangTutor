import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';
import '../database/db_helper.dart';
import '../database/models/knowledge_point.dart';
import '../services/llm_service.dart';

class KnowledgePointPageSimple extends StatefulWidget {
  final String lang;
  final List<ChatMessage>? messages;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const KnowledgePointPageSimple({
    super.key,
    this.lang = 'cn',
    this.messages,
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<KnowledgePointPageSimple> createState() => _KnowledgePointPageSimpleState();
}

class _KnowledgePointPageSimpleState extends State<KnowledgePointPageSimple> {
  List<KnowledgePoint> _allPoints = [];
  List<KnowledgePoint> _displayPoints = [];
  String? _filterCategory;
  String? _filterLessonUnit;
  String _outlineContent = '';
  late KnowledgePointDao _knowledgePointDao;
  final LlmService _llmService = LlmService();

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _knowledgePointDao = KnowledgePointDao(db);
    await _llmService.init();
    await _loadPoints();
  }

  Future<void> _loadPoints() async {
    final points = await _knowledgePointDao.getAll(lang: widget.lang);
    setState(() {
      _allPoints = points;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _displayPoints = _allPoints.where((p) {
      if (_filterCategory != null && p.category != _filterCategory) return false;
      if (_filterLessonUnit != null &&
          (p.lessonUnit == null || !p.lessonUnit!.contains(_filterLessonUnit!))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '知识谱' : 'Spectrum')) {
      _showSpectrumDialog();
    } else if (tab == (widget.lang == 'cn' ? '大纲' : 'Outline')) {
      await _showOutlineDialog();
    }
  }

  Future<void> _toggleMastered(KnowledgePoint point) async {
    final updated = point.copyWith(mastered: !point.mastered);
    await _knowledgePointDao.update(updated);
    await _loadPoints();
  }

  Future<void> _showOutlineDialog() async {
    // 生成大纲内容

    try {
      final allContent = _allPoints.map((p) => '${p.category ?? ""} - ${p.title}: ${p.content ?? ""}').join('\n');
      final prompt = '请根据以下知识点内容，生成一个层次分明的知识大纲（用缩进表示层级）：\n$allContent';
      final response = await _llmService.generateResponse(prompt);
      _outlineContent = response['response'] ?? '';
    } catch (e) {
      _outlineContent = _allPoints.map((p) {
        var line = '${p.category ?? "未分类"} - ${p.title}';
        if (p.lessonUnit != null) line += ' (${p.lessonUnit})';
        return line;
      }).join('\n');
    }

    if (!mounted) return;

    final controller = TextEditingController(text: _outlineContent);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '知识大纲' : 'Knowledge Outline'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: (text) => _outlineContent = text,
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

  List<KnowledgePoint> _rootPoints = [];
  KnowledgePoint? _currentParentPoint;
  List<KnowledgePoint> _childrenPoints = [];

  Future<void> _loadRootNodes() async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    final rootNodes = await dao.getRootNodes(lang: widget.lang);
    setState(() {
      _rootPoints = rootNodes;
      _currentParentPoint = null;
      _childrenPoints = [];
    });
  }

  Future<void> _loadChildrenOf(KnowledgePoint point) async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    final children = await dao.getByParentId(point.id!, lang: widget.lang);
    setState(() {
      _currentParentPoint = point;
      _childrenPoints = children;
    });
  }

  void _showSpectrumDialog() {
    showDialog(
      context: context,
      builder: (context) => _SpectrumDialog(
        lang: widget.lang,
        rootPoints: _rootPoints.isNotEmpty ? _rootPoints : _allPoints.where((p) => p.parentId == null).toList(),
        currentParent: _currentParentPoint,
        childrenPoints: _childrenPoints,
        allPoints: _allPoints,
        onLoadChildren: _loadChildrenOf,
        onBackToRoot: _loadRootNodes,
      ),
    );
  }

  void _showFilterDialog() {
    final categories = _allPoints.map((p) => p.category).whereType<String>().toSet().toList();
    final lessonUnits = _allPoints.map((p) => p.lessonUnit).whereType<String>().toSet().toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '筛选知识点' : 'Filter Knowledge'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.lang == 'cn' ? '按分类筛选：' : 'By category:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: categories.map((c) => ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: _filterCategory == c,
                  onSelected: (_) {
                    setState(() {
                      _filterCategory = _filterCategory == c ? null : c;
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
              Text(widget.lang == 'cn' ? '按课内单元筛选：' : 'By lesson unit:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: lessonUnits.map((u) => ChoiceChip(
                  label: Text(u, style: const TextStyle(fontSize: 12)),
                  selected: _filterLessonUnit == u,
                  onSelected: (_) {
                    setState(() {
                      _filterLessonUnit = _filterLessonUnit == u ? null : u;
                      _applyFilter();
                    });
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterCategory = null;
                    _filterLessonUnit = null;
                    _applyFilter();
                  });
                  Navigator.pop(context);
                },
                child: Text(widget.lang == 'cn' ? '全部' : 'All'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '知识谱', '大纲']
        : ['Filter', 'Spectrum', 'Outline'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-知识点' : 'My AI Language Tutor - Knowledge',
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
                child: _displayPoints.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无知识点' : 'No knowledge points'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayPoints.length,
                        itemBuilder: (context, index) {
                          final point = _displayPoints[index];
                          return _buildKnowledgePointItem(point);
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

  Widget _buildKnowledgePointItem(KnowledgePoint point) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showPointDetail(point),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      point.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      point.mastered ? Icons.check_circle : Icons.circle_outlined,
                      color: point.mastered ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => _toggleMastered(point),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  if (point.lessonUnit != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFE4E9), borderRadius: BorderRadius.circular(4)),
                      child: Text('课内: ${point.lessonUnit}', style: const TextStyle(fontSize: 11)),
                    ),
                  if (point.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF87CEEB), borderRadius: BorderRadius.circular(4)),
                      child: Text(point.category!, style: const TextStyle(fontSize: 11)),
                    ),
                  if (point.errorType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFA07A), borderRadius: BorderRadius.circular(4)),
                      child: Text('错类: ${point.errorType}', style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: point.mastered ? const Color(0xFF90EE90) : const Color(0xFFD3D3D3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      point.mastered ? (widget.lang == 'cn' ? '已掌握' : 'Mastered') : (widget.lang == 'cn' ? '未掌握' : 'Not Mastered'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPointDetail(KnowledgePoint point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(point.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (point.category != null)
                Text('${widget.lang == 'cn' ? "分类" : "Category"}: ${point.category}'),
              if (point.lessonUnit != null)
                Text('${widget.lang == 'cn' ? "课内" : "Lesson"}: ${point.lessonUnit}'),
              if (point.errorType != null)
                Text('${widget.lang == 'cn' ? "关联错类" : "Error type"}: ${point.errorType}'),
              const Divider(),
              Text(
                point.content ?? (widget.lang == 'cn' ? '无详细内容' : 'No content'),
                style: const TextStyle(fontSize: 14),
              ),
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
}

/// 知识谱对话框组件 - 支持父子层级导航
class _SpectrumDialog extends StatefulWidget {
  final String lang;
  final List<KnowledgePoint> rootPoints;
  final KnowledgePoint? currentParent;
  final List<KnowledgePoint> childrenPoints;
  final List<KnowledgePoint> allPoints;
  final Future<void> Function(KnowledgePoint) onLoadChildren;
  final Future<void> Function() onBackToRoot;

  const _SpectrumDialog({
    required this.lang,
    required this.rootPoints,
    required this.currentParent,
    required this.childrenPoints,
    required this.allPoints,
    required this.onLoadChildren,
    required this.onBackToRoot,
  });

  @override
  State<_SpectrumDialog> createState() => _SpectrumDialogState();
}

class _SpectrumDialogState extends State<_SpectrumDialog> {
  Map<String, List<KnowledgePoint>> _categories = {};

  @override
  void initState() {
    super.initState();
    _groupByCategory();
  }

  @override
  void didUpdateWidget(_SpectrumDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentParent != oldWidget.currentParent ||
        widget.childrenPoints.length != oldWidget.childrenPoints.length) {
      _groupByCategory();
    }
  }

  void _groupByCategory() {
    final points = widget.currentParent != null ? widget.childrenPoints : widget.rootPoints;
    _categories = <String, List<KnowledgePoint>>{};
    for (final p in points) {
      final cat = p.category ?? (widget.lang == 'cn' ? '未分类' : 'Uncategorized');
      _categories.putIfAbsent(cat, () => []).add(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.currentParent != null
        ? '${widget.currentParent!.title} - ${widget.lang == 'cn' ? '子知识点' : 'Sub-points'}'
        : (widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum');

    return AlertDialog(
      title: Text(titleText),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 返回按钮
            if (widget.currentParent != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton.icon(
                  onPressed: () => widget.onBackToRoot(),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(widget.lang == 'cn' ? '返回根节点' : 'Back to Root'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF69B4),
                  ),
                ),
              ),
            // 知识点列表
            Expanded(
              child: _categories.isEmpty
                  ? Center(
                      child: Text(
                        widget.lang == 'cn' ? '暂无子知识点' : 'No sub-points',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _categories.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFFF69B4),
                                  ),
                                ),
                              ),
                              ...entry.value.map((p) {
                                final hasChildren = widget.allPoints
                                    .where((point) => point.parentId == p.id)
                                    .isNotEmpty;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                                  child: InkWell(
                                    onTap: hasChildren
                                        ? () => widget.onLoadChildren(p)
                                        : null,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          p.mastered
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          size: 16,
                                          color: p.mastered
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        if (hasChildren)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(right: 6),
                                            child: const Icon(
                                              Icons.child_care,
                                              size: 14,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.title,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: hasChildren
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: hasChildren
                                                      ? const Color(0xFF4169E1)
                                                      : Colors.black87,
                                                ),
                                              ),
                                              if (p.lessonUnit != null)
                                                Text(
                                                  '(${p.lessonUnit})',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const Divider(height: 16),
                            ],
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
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }
}
