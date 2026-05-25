import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../components/dynamic_tag_selector.dart';
import '../components/generic_filter_dialog.dart';
import '../database/db_helper.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
import '../database/models/chat_message.dart';
import '../services/llm_service.dart';
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
  Set<String> _filterUnitNumbers = {};
  Set<String> _filterLessonNumbers = {};
  bool? _filterIsOriginal;
  String _filterContentKeyword = '';
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
    List<PortfolioItem> filtered = _allItems.where((item) {
      if (_filterIsOriginal != null && item.isOriginal != _filterIsOriginal) return false;
      if (_filterKnowledgeTags.isNotEmpty && !_filterKnowledgeTags.contains(item.kid)) return false;
      if (_filterUnitNumbers.isNotEmpty && !_filterUnitNumbers.contains(item.unitNumber)) return false;
      if (_filterLessonNumbers.isNotEmpty && !_filterLessonNumbers.contains(item.lessonNumber)) return false;
      if (_filterContentKeyword.isNotEmpty) {
        final keyword = _filterContentKeyword.toLowerCase();
        return (item.content ?? '').toLowerCase().contains(keyword);
      }
      return true;
    }).toList();
    
    setState(() {
      _displayItems = filtered;
    });
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
    final newItem = PortfolioItem(
      title: widget.lang == 'cn' ? '新原创作品' : 'New Original',
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
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择作品' : 'Select items first')),
      );
      return;
    }

    final selectedItems = _allItems.where((item) => _selectedIds.contains(item.id)).toList();
    final originalItems = selectedItems.where((item) => item.isOriginal).toList();
    
    if (originalItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '自由作品，不符合出题要求' : 'Original works do not meet the requirements for generating exercises')),
      );
      return;
    }

    final db = await DatabaseHelper().database;
    late int loadingMsgId;

    try {
      final chatMsgDao = ChatMessageDao(db);
      loadingMsgId = await chatMsgDao.insert(ChatMessage(
        content: widget.lang == 'cn' ? '习题生成中...' : 'Generating exercises...',
        isUser: false,
        createdAt: DateTime.now(),
        lang: widget.lang,
      ));

      final llmService = LlmService();
      await llmService.init();

      final portfolioContent = selectedItems.map((item) {
        return '作品：${item.title}\n简介：${item.brief ?? ''}\n知识点：${item.kid ?? ''}';
      }).join('\n\n');

      final prompt = '''你是一位语文教育专家。请根据以下文学作品，分析其写作风格特点，并出一道模仿写作练习题。

作品参考：
$portfolioContent

要求：
1. 先分析上述作品的写作风格特点（叙事章法、文学修辞手法等）
2. 根据这些特点，出一道习作题，要求学生模仿该风格进行写作
3. 题目类型为"写作题"

请以如下JSON格式回复（只回复JSON，不要其他文字）：
{
  "type": "writing",
  "question": "写作题目内容",
  "requirements": ["要求1", "要求2", "要求3"],
  "explanation": "题目解析和写作指导"
}

注意：
- question 是完整的写作题目描述
- requirements 是具体的写作要求列表
- explanation 是对题目的详细解析和写作指导
''';

      final response = await llmService.generateResponse(prompt);

      if (response['success'] != true || response['response'] == null) {
        throw Exception('LLM响应失败');
      }

      final jsonResponse = response['response'] as String;
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        throw Exception('未找到JSON数据');
      }

      final Map<String, dynamic> exerciseJson = json.decode(jsonMatch.group(0)!);

      final testDao = TestDao(db);
      final nextNum = await testDao.nextTidNumber();
      final tid = 'T$nextNum';

      final firstItem = selectedItems.first;
      final workTitle = firstItem.title.contains('——') 
          ? firstItem.title.split('——').first 
          : firstItem.title;
      
      String exerciseTitle;
      if (widget.lang == 'cn') {
        if (selectedItems.length == 1) {
          exerciseTitle = '关于《$workTitle》的写作手法模仿习作';
        } else {
          exerciseTitle = '关于多篇作品的写作手法综合练习';
        }
      } else {
        if (selectedItems.length == 1) {
          exerciseTitle = 'Writing Style Imitation: "$workTitle"';
        } else {
          exerciseTitle = 'Comprehensive Writing Practice';
        }
      }

      await testDao.insert(Test(
        tid: tid,
        title: exerciseTitle,
        createdAt: DateTime.now(),
        lang: widget.lang,
      ));

      final questionDao = QuestionDao(db);
      final question = Question(
        tid: tid,
        question: exerciseJson['question'] as String? ?? '',
        correctAnswer: '',
        explanation: exerciseJson['explanation'] as String?,
        category: '写作题',
        progress: '未答题',
        source: '作品集',
        createdAt: DateTime.now(),
        lang: widget.lang,
      );

      await questionDao.insert(question);

      for (final item in selectedItems) {
        await _portfolioDao.addTestRec(item.id!, tid);
      }

      if (mounted) {
        Navigator.of(context).pop();

        final completedMsg = ChatMessage(
          id: loadingMsgId,
          content: widget.lang == 'cn' 
              ? '已根据${selectedItems.length}篇作品生成写作练习题并添加到习题集'
              : 'Generated writing exercise from ${selectedItems.length} portfolio items',
          isUser: false,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );
        await chatMsgDao.update(completedMsg);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' 
                ? '已根据${selectedItems.length}篇作品生成写作练习题'
                : 'Generated writing exercise from ${selectedItems.length} portfolio items',
          )),
        );
      }

    } catch (e) {
      print('[GenerateExercises] 生成失败: $e');
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        try {
          final errorChatMsgDao = ChatMessageDao(db);
          final errorMsg = ChatMessage(
            id: loadingMsgId,
            content: widget.lang == 'cn' 
                ? '生成练习失败: ${e.toString()}'
                : 'Failed to generate exercises: ${e.toString()}',
            isUser: false,
            createdAt: DateTime.now(),
            lang: widget.lang,
          );
          await errorChatMsgDao.update(errorMsg);
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            widget.lang == 'cn' ? '生成练习失败' : 'Failed to generate exercises',
          )),
        );
      }
    }
  }

  void _showFilterDialog() async {
    final knowledgeTags = _allItems.map((i) => i.kid).whereType<String>().toSet();
    final unitNumbers = _allItems.map((i) => i.unitNumber).whereType<String>().toSet();
    final lessonNumbers = _allItems.map((i) => i.lessonNumber).whereType<String>().toSet();
    final isOriginalOptions = [
      FilterOption(value: 'true', label: widget.lang == 'cn' ? '原创' : 'Original'),
      FilterOption(value: 'false', label: widget.lang == 'cn' ? '赏析' : 'Analysis'),
    ];

    final config = FilterConfig(
      filterTypes: [
        'type',
        'kid',
        'unit',
        'lesson',
      ],
      typeConfigs: {
        'type': FilterTypeConfig(
          options: isOriginalOptions,
          initialValues: _filterIsOriginal != null ? {_filterIsOriginal.toString()} : {},
          label: widget.lang == 'cn' ? '类型' : 'Type',
          hintText: widget.lang == 'cn' ? '选择类型...' : 'Select type...',
        ),
        'kid': FilterTypeConfig(
          options: knowledgeTags.map((k) => FilterOption(value: k, label: k)).toList(),
          initialValues: _filterKnowledgeTags,
          label: widget.lang == 'cn' ? '知识点' : 'Knowledge',
          hintText: widget.lang == 'cn' ? '输入知识点...' : 'Enter knowledge...',
        ),
        'unit': FilterTypeConfig(
          options: unitNumbers.map((u) => FilterOption(value: u, label: u)).toList(),
          initialValues: _filterUnitNumbers,
          label: widget.lang == 'cn' ? '单元号' : 'Unit',
          hintText: widget.lang == 'cn' ? '输入单元号...' : 'Enter unit...',
        ),
        'lesson': FilterTypeConfig(
          options: lessonNumbers.map((l) => FilterOption(value: l, label: l)).toList(),
          initialValues: _filterLessonNumbers,
          label: widget.lang == 'cn' ? '课号' : 'Lesson',
          hintText: widget.lang == 'cn' ? '输入课号...' : 'Enter lesson...',
        ),
      },
    );

    final result = await GenericFilterDialog.show(context, config: config, lang: widget.lang);

    if (result != null) {
      setState(() {
        final typeValue = (result['type'] as Map?)?['values'] as Set?;
        _filterIsOriginal = typeValue?.contains('true') ?? false
            ? true
            : typeValue?.contains('false') ?? false
                ? false
                : null;
        _filterKnowledgeTags = Set<String>.from((result['kid'] as Map?)?['values'] ?? {});
        _filterUnitNumbers = Set<String>.from((result['unit'] as Map?)?['values'] ?? {});
        _filterLessonNumbers = Set<String>.from((result['lesson'] as Map?)?['values'] ?? {});
      });
      _applyFilter();
    }
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
                          '${item.wid ?? ""} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                            child: Text(
                              item.title,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
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
                        if (item.unitNumber != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                            child: Text('单元: ${item.unitNumber}', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                          ),
                        if (item.kid != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                            child: Text('知识: ${item.kid}', style: const TextStyle(fontSize: 11, color: Colors.green)),
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
