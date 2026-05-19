import 'dart:convert';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';
import '../database/db_helper.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/exercise.dart';
import '../services/llm_service.dart';
import 'knowledge_outline_page.dart';

class KnowledgePointPageSimple extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;
  
  /// 统一的消息发送回调（委托给 MainScreen）
  final void Function(ChatMessage)? onSendMessage;

  const KnowledgePointPageSimple({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
    this.onSendMessage,
  });

  @override
  State<KnowledgePointPageSimple> createState() => _KnowledgePointPageSimpleState();
}

class _KnowledgePointPageSimpleState extends State<KnowledgePointPageSimple> {
  List<KnowledgePoint> _allPoints = [];
  List<KnowledgePoint> _displayPoints = [];
  final Set<int> _selectedIds = {};
  String? _filterCategory;
  String? _filterLessonUnit;
  late KnowledgePointDao _knowledgePointDao;
  late ExerciseDao _exerciseDao;
  final LlmService _llmService = LlmService();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _knowledgePointDao = KnowledgePointDao(db);
    _exerciseDao = ExerciseDao(db);
    await _llmService.init();
    await _loadPoints();
  }

  @override
  void dispose() {
    // LlmService is singleton and has no dispose method
    super.dispose();
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
      // 直接导航到知识点大纲页面（替代原来的对话框方式）
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KnowledgeOutlinePage(
            lang: widget.lang,
            onHomeTap: widget.onHomeTap,
          ),
        ),
      );
      // 从大纲页面返回后重新加载数据
      await _loadPoints();
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      await _generateExercisesFromKnowledgePoint();
    }
  }

  /// 根据选中的知识点条目，使用LLM生成练习题
  Future<void> _generateExercisesFromKnowledgePoint() async {
    // 获取所有选中的知识点
    List<KnowledgePoint> selectedPoints = [];
    
    if (_selectedIds.isNotEmpty) {
      selectedPoints = _displayPoints.where((p) => _selectedIds.contains(p.id)).toList();
    } else if (_displayPoints.isNotEmpty) {
      // 如果没有选中，使用第一条作为默认
      selectedPoints = [_displayPoints.first];
    }

    if (selectedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '暂无知识点，无法生成练习' : 'No knowledge points available')),
      );
      return;
    }

    if (_isGenerating) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习生成进行中...' : 'Exercise generation in progress')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 合并所有选中知识点的内容
      StringBuffer combinedContent = StringBuffer();
      for (final point in selectedPoints) {
        combinedContent.writeln('【${point.title}】');
        if (point.category != null) combinedContent.writeln('分类：${point.category}');
        if (point.lessonUnit != null) combinedContent.writeln('课时单元：${point.lessonUnit}');
        if (point.cid != null) combinedContent.writeln('CID: ${point.cid}');
        final content = point.content ?? '';
        combinedContent.writeln('内容：$content');
        combinedContent.writeln('');
      }

      final subjectLabel = widget.lang == 'cn' ? '科目' : 'Subject';
      final prompt = '''你是一位教育专家。请根据以下主题知识点内容，出一组综合练习题。

主题知识点（共${selectedPoints.length}个）：
${combinedContent.toString()}

要求：
1. 出填空题2题（针对核心概念）
2. 出选择题5题（每题A/B/C/D四个选项）
3. 题目要覆盖所有选中知识点的关键内容
4. 只出与当前知识点相关的语文题目，不要涉及数学等其他学科

请以如下JSON数组格式回复（只回复JSON，不要其他文字）：
[
  {
    "type": "fill_blank" 或 "multiple_choice",
    "question": "题目内容",
    "options": null 或 ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "correctAnswer": "答案",
    "explanation": "解析",
    "knowledgeTag": "所属知识点标题"
  },
  ...
]

注意：
- question 字段是完整的题目描述
- options 字段对于选择题是 A/B/C/D 选项数组，填空题为 null
- correctAnswer 是简短的答案
- explanation 是详细的解题思路
- knowledgeTag 标识该题目属于哪个知识点
- 请严格按照格式输出7道题目的JSON数组
''';

      final response = await _llmService.generateResponse(prompt);
      
      if (response['success'] != true || response['response'] == null) {
        throw Exception('LLM响应失败');
      }

      final jsonResponse = response['response'] as String;
      
      // 解析JSON
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        throw Exception('未找到JSON数组');
      }

      final List<dynamic> exercisesJson = json.decode(jsonMatch.group(0)!);

      // 批量插入习题集
      int createdCount = 0;

      for (final exData in exercisesJson) {
        final nextNum = await _exerciseDao.nextExerciseIdNumber();
        
        // 根据 knowledgeTag 匹配对应的知识点（如果有）
        KnowledgePoint pointForExercise = selectedPoints[0];
        if (exData['knowledgeTag'] != null) {
          final matched = selectedPoints.firstWhere(
            (p) => p.title == exData['knowledgeTag'],
            orElse: () => selectedPoints[0],
          );
          pointForExercise = matched;
        }
        
        final exercise = Exercise(
          question: exData['question'] ?? '',
          options: exData['options'] != null 
              ? (exData['options'] as List).join('\n') 
              : null,
          correctAnswer: exData['correctAnswer'] as String?,
          explanation: exData['explanation'] as String?,
          category: pointForExercise.category ?? '练习题',
          difficulty: 1,
          lessonUnit: pointForExercise.lessonUnit,
          knowledgeTag: pointForExercise.title,
          progress: '未答题',
          source: '知识点',
          exerciseId: 'T$nextNum',
          contentPath: pointForExercise.contentPath,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );

        await _exerciseDao.insert(exercise);
        createdCount++;
      }

      final cnSubjectLabel = widget.lang == 'cn' ? '个知识点' : 'knowledge points';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' 
                ? '已从${selectedPoints.length}$cnSubjectLabel生成$createdCount道练习题并添加到习题集'
                : 'Generated $createdCount exercises from ${selectedPoints.length}$cnSubjectLabel and added to exercise set',
          )),
        );
      }
      
      await _loadPoints();
    } catch (e) {
      print('[GenerateExercises] 生成失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' ? '生成练习失败: ${e.toString()}' : 'Failed to generate exercises: ${e.toString()}',
          )),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _toggleMastered(KnowledgePoint point) async {
    final updated = point.copyWith(mastered: !point.mastered);
    await _knowledgePointDao.update(updated);
    await _loadPoints();
  }

  List<KnowledgePoint> _rootPoints = [];
  KnowledgePoint? _currentParentPoint;
  List<KnowledgePoint> _childrenPoints = [];
  List<KnowledgePoint> _spectrumResults = []; // 知识谱筛选结果
  bool _showSpectrumMode = false; // 是否处于知识谱筛选模式

  Future<void> _loadRootNodes() async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    final rootNodes = await dao.getRootNodes(lang: widget.lang);
    setState(() {
      _rootPoints = rootNodes;
      _currentParentPoint = null;
      _childrenPoints = [];
      _showSpectrumMode = false;
      _spectrumResults = [];
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

  /// 执行知识谱筛选：根据选中的知识点，获取父类、自身、子类
  Future<void> _executeSpectrumFilter(KnowledgePoint selectedPoint) async {
    final db = await DatabaseHelper().database;
    final dao = KnowledgePointDao(db);
    
    final Set<int> resultIds = {};
    final List<KnowledgePoint> results = [];

    // 1. 添加自身
    results.add(selectedPoint);
    resultIds.add(selectedPoint.id!);

    // 2. 获取父类（基于 fatherId）
    if (selectedPoint.fatherId != null) {
      final parentList = await dao.getByFatherId(selectedPoint.fatherId!, lang: widget.lang);
      for (final parent in parentList) {
        if (!resultIds.contains(parent.id!)) {
          results.add(parent);
          resultIds.add(parent.id!);
        }
      }
    }

    // 3. 获取所有子类（基于 fatherId）
    final children = await dao.getAllChildrenByFatherId(selectedPoint.id!, lang: widget.lang);
    for (final child in children) {
      if (!resultIds.contains(child.id!)) {
        results.add(child);
        resultIds.add(child.id!);
      }
    }

    setState(() {
      _spectrumResults = results;
      _showSpectrumMode = true;
      _displayPoints = results;
    });

    Navigator.pop(context); // 关闭弹窗
  }

  void _showSpectrumDialog() {
    showDialog(
      context: context,
      builder: (context) => _SpectrumSearchDialog(
        lang: widget.lang,
        allPoints: _allPoints,
        onPointSelected: _executeSpectrumFilter,
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
        ? ['筛选', '知识谱', '大纲', '练习']
        : ['Filter', 'Spectrum', 'Outline', 'Practice'];

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
              messages: widget.onSendMessage != null ? [] : null,
              topic: 'knowledge',
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

  Widget _buildKnowledgePointItem(KnowledgePoint point) {
    final isSelected = _selectedIds.contains(point.id);
    
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
                  // 左侧方框多选
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(point.id!);
                        } else {
                          _selectedIds.remove(point.id!);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // CID 标识
                            if (point.cid != null && point.cid!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('CID: ${point.cid}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 8),
                            // FatherID 标识
                            if (point.fatherId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDDA0DD),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('父:${point.fatherId}', style: const TextStyle(fontSize: 10)),
                              ),
                            const SizedBox(width: 8),
                            // 标题
                            Text(
                              point.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 掌握状态（移动到标签区域）
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

/// 知识谱搜索对话框 - 支持 cid/关键词模糊匹配
class _SpectrumSearchDialog extends StatefulWidget {
  final String lang;
  final List<KnowledgePoint> allPoints;
  final Future<void> Function(KnowledgePoint) onPointSelected;

  const _SpectrumSearchDialog({
    required this.lang,
    required this.allPoints,
    required this.onPointSelected,
  });

  @override
  State<_SpectrumSearchDialog> createState() => _SpectrumSearchDialogState();
}

class _SpectrumSearchDialogState extends State<_SpectrumSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<KnowledgePoint> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // 延迟执行搜索，避免频繁查询
    Future.delayed(const Duration(milliseconds: 300), () async {
      final db = await DatabaseHelper().database;
      final dao = KnowledgePointDao(db);
      
      // 根据 cid 或 title 模糊匹配
      final results = await dao.searchByCidOrTitle(query, lang: widget.lang);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final confirmText = widget.lang == 'cn' ? '确定' : 'Confirm';
    final cancelText = widget.lang == 'cn' ? '取消' : 'Cancel';
    final placeholderText = widget.lang == 'cn' 
        ? '输入 CID（如 1.1）或关键词...' 
        : 'Enter CID (e.g., 1.1) or keyword...';

    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱搜索' : 'Knowledge Spectrum Search'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜索输入框
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: placeholderText,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty && _searchResults.isNotEmpty) {
                  widget.onPointSelected(_searchResults.first);
                }
              },
            ),
            const SizedBox(height: 8),
            // 搜索结果下拉列表
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _searchResults.isEmpty
                    ? const Center(
                        child: Text('暂无结果', style: TextStyle(color: Colors.grey)),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _searchResults.map((point) {
                            return InkWell(
                              onTap: () {
                                widget.onPointSelected(point);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // CID 标签
                                    if (point.cid != null && point.cid!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          point.cid!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (point.cid != null && point.cid!.isNotEmpty)
                                      const SizedBox(width: 8),
                                    // 标题
                                    Expanded(
                                      child: Text(
                                        point.title,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: _searchResults.isNotEmpty
              ? () => widget.onPointSelected(_searchResults.first)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF69B4),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
