import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/exercise.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';
import '../services/llm_service.dart';

class KnowledgePointPage extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;

  const KnowledgePointPage({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
  });

  @override
  State<KnowledgePointPage> createState() => _KnowledgePointPageState();
}

class _KnowledgePointPageState extends State<KnowledgePointPage> {
  List<KnowledgePoint> _knowledgePoints = [];
  List<KnowledgePoint> _filteredPoints = [];
  List<int> _selectedPoints = [];
  bool _isLoading = false;
  bool _isGeneratingExercise = false;
  String _selectedTab = '筛选';
  String _keyword = '';
  String? _selectedCategory;
  String? _selectedLessonUnit;
  String? _selectedErrorType;
  String _outlineContent = '';
  bool _showOutlineDialog = false;
  bool _showCategoryDialog = false;
  bool _showFilterDialog = false;
  String? _selectedParentCategory;
  final TextEditingController _keywordController = TextEditingController();
  final LlmService _llmService = LlmService();
  @override
  void initState() {
    super.initState();
    _loadKnowledgePoints();
    _loadOutline();
    _llmService.init();
  }

  @override
  void initState() {
    super.initState();
    _loadKnowledgePoints();
    _loadOutline();
    _llmService.init();
  }



  Future<void> _loadKnowledgePoints() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper().database;
      final dao = KnowledgePointDao(db);
      _knowledgePoints = await dao.getAll(lang: widget.lang);
      _filteredPoints = List.from(_knowledgePoints);
    } catch (e) {
      print('Load knowledge points error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadOutline() {
    _outlineContent = _outlineCategories.join('\n');
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  Future<void> _saveOutlineToDb() async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(
        'settings',
        {
          'key': 'knowledge_outline',
          'value': _outlineContent,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save outline error: $e');
    }
  }

  void _filterPoints() {
    _filteredPoints = _knowledgePoints.where((point) {
      if (_keyword.isNotEmpty && 
          !point.title.toLowerCase().contains(_keyword.toLowerCase()) &&
          (point.content == null || !point.content!.toLowerCase().contains(_keyword.toLowerCase()))) {
        return false;
      }
      if (_selectedCategory != null && point.category != _selectedCategory) {
        return false;
      }
      if (_selectedLessonUnit != null && point.lessonUnit != _selectedLessonUnit) {
        return false;
      }
      if (_selectedErrorType != null && point.errorType != _selectedErrorType) {
        return false;
      }
      return true;
    }).toList();
    setState(() {});
  }

  void _clearFilters() {
    _keywordController.clear();
    _keyword = '';
    _selectedCategory = null;
    _selectedLessonUnit = null;
    _selectedErrorType = null;
    _filteredPoints = List.from(_knowledgePoints);
    setState(() {});
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedPoints.contains(id)) {
        _selectedPoints.remove(id);
      } else {
        _selectedPoints.add(id);
      }
    });
  }

  void _openCategoryDialog() {
    setState(() {
      _showCategoryDialog = true;
    });
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _selectParentCategory(String category) {
    setState(() {
      _selectedParentCategory = category;
      _filteredPoints = _knowledgePoints.where((p) => 
        p.category != null && p.category!.startsWith(category.split('.')[0])
      ).toList();
    });
  }

  Widget _buildCategoryDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.lang == 'cn' ? '请选择知识类目：' : 'Please select category:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _outlineCategories
                .where((c) => !c.contains('.1.') && !c.contains('.2.'))
                .map((category) => Chip(
                  label: Text(category),
                  backgroundColor: _selectedParentCategory == category ? const Color(0xFFFF69B4) : Colors.grey[200],
                  labelColor: _selectedParentCategory == category ? Colors.white : Colors.black,
                  onPressed: () => _selectParentCategory(category),
                )).toList(),
            ),
            if (_selectedParentCategory != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(widget.lang == 'cn' ? '子类：' : 'Subcategories:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _outlineCategories
                      .where((c) => c.startsWith(_selectedParentCategory!.split('.')[0] + '.') && c.contains('.1.') || c.contains('.2.'))
                      .map((sub) => Chip(
                        label: Text(sub),
                        backgroundColor: Colors.blue[100],
                        labelColor: Colors.blue,
                      )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showCategoryDialog = false),
          child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _openOutlineDialog() {
    setState(() {
      _showOutlineDialog = true;
    });
  }

  void _saveOutline() {
    _saveOutlineToDb();
    setState(() {
      _showOutlineDialog = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.lang == 'cn' ? '大纲已保存' : 'Outline saved')),
    );
  }

  Future<void> _generateExercise() async {
    if (_selectedPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择知识点' : 'Please select knowledge points first')),
      );
      return;
    }

    if (_isGeneratingExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习正在生成中' : 'Exercise is being generated')),
      );
      return;
    }

    setState(() => _isGeneratingExercise = true);

    try {
      final selectedPoints = _knowledgePoints.where((p) => _selectedPoints.contains(p.id)).toList();
      final knowledgeContent = selectedPoints.map((p) => '${p.title}: ${p.content}').join('\n');

      final prompt = widget.lang == 'cn'
          ? '根据以下知识点生成练习题：\n$knowledgeContent\n\n请生成5道选择题，包含题目、选项和正确答案。' 
          : 'Generate exercises based on the following knowledge points:\n$knowledgeContent\n\nPlease generate 5 multiple-choice questions with options and correct answers.';

      final response = await _llmService.generateResponse(prompt);
      final exerciseContent = response['response'] ?? '';

      final exercise = Exercise(
        question: widget.lang == 'cn' ? '专项知识点练习' : 'Knowledge Points Practice',
        options: exerciseContent,
        correctAnswer: '',
        explanation: '',
        category: selectedPoints.first.category ?? '',
        difficulty: 1,
        completed: false,
        lang: widget.lang,
      );

      final db = await DatabaseHelper().database;
      final exerciseDao = ExerciseDao(db);
      await exerciseDao.insert(exercise);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习已添加到习题集' : 'Exercise added to exercises')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '生成练习失败' : 'Failed to generate exercise')),
      );
    } finally {
      setState(() {
        _isGeneratingExercise = false;
        _selectedPoints.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-知识点' : 'My AI Language Assistant - Knowledge Points',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lastAiMessage,
              onPullDown: () {},
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          SubmenuTabs(
                            tabs: widget.lang == 'cn' 
                                ? ['筛选', '知识谱', '练习', '大纲']
                                : ['Filter', 'Knowledge', 'Practice', 'Outline'],
                            selectedTab: _selectedTab,
                            onTabSelected: (tab) {
                              setState(() {
                                _selectedTab = tab;
                              });
                              if (tab == (widget.lang == 'cn' ? '知识谱' : 'Knowledge')) {
                                _openCategoryDialog();
                              } else if (tab == (widget.lang == 'cn' ? '大纲' : 'Outline')) {
                                _openOutlineDialog();
                              } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
                                _generateExercise();
                              }
                            },
                            onHomeTap: widget.onHomeTap,
                            lang: widget.lang,
                          ),
                          if (_selectedTab == (widget.lang == 'cn' ? '筛选' : 'Filter'))
                            _buildFilterSection(),
                          Expanded(
                            child: _filteredPoints.isEmpty && !_isLoading
                                ? Center(
                                    child: Text(_selectedParentCategory != null 
                                        ? (widget.lang == 'cn' ? '该类目暂无知识点' : 'No knowledge points in this category')
                                        : (widget.lang == 'cn' ? '暂无知识点' : 'No knowledge points')),
                                  )
                                : ListView.builder(
                              itemCount: _filteredPoints.length,
                              itemBuilder: (context, index) {
                                final point = _filteredPoints[index];
                                return _buildKnowledgePointItem(point);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            InputArea(
              lang: widget.lang,
              onTextChanged: (text) {},
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == (widget.lang == 'cn' ? '筛选' : 'Filter') && _selectedPoints.isNotEmpty
          ? FloatingActionButton(
              onPressed: _generateExercise,
              backgroundColor: const Color(0xFFFF69B4),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-知识点' : 'My AI Language Assistant - Knowledge Points',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lastAiMessage,
              onPullDown: () {},
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          SubmenuTabs(
                            tabs: widget.lang == 'cn' 
                                ? ['筛选', '知识谱', '练习', '大纲']
                                : ['Filter', 'Knowledge', 'Practice', 'Outline'],
                            selectedTab: _selectedTab,
                            onTabSelected: (tab) {
                              setState(() {
                                _selectedTab = tab;
                              });
                              if (tab == (widget.lang == 'cn' ? '知识谱' : 'Knowledge')) {
                                _openCategoryDialog();
                              } else if (tab == (widget.lang == 'cn' ? '大纲' : 'Outline')) {
                                _openOutlineDialog();
                              } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
                                _generateExercise();
                              }
                            },
                            onHomeTap: widget.onHomeTap,
                            lang: widget.lang,
                          ),
                          if (_selectedTab == (widget.lang == 'cn' ? '筛选' : 'Filter'))
                            _buildFilterSection(),
                          Expanded(
                            child: _filteredPoints.isEmpty && !_isLoading
                                ? Center(
                                    child: Text(_selectedParentCategory != null 
                                        ? (widget.lang == 'cn' ? '该类目暂无知识点' : 'No knowledge points in this category')
                                        : (widget.lang == 'cn' ? '暂无知识点' : 'No knowledge points')),
                                  )
                                : ListView.builder(
                              itemCount: _filteredPoints.length,
                              itemBuilder: (context, index) {
                                final point = _filteredPoints[index];
                                return _buildKnowledgePointItem(point);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            InputArea(
              lang: widget.lang,
              onTextChanged: (text) {},
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == (widget.lang == 'cn' ? '筛选' : 'Filter') && _selectedPoints.isNotEmpty
          ? FloatingActionButton(
              onPressed: _generateExercise,
              backgroundColor: const Color(0xFFFF69B4),
              child: const Icon(Icons.add),
            )
          : null,
      // Dialogs
      ..._buildDialogs(),
    );
  }

  List<Widget> _buildDialogs() {
    return [
      if (_showOutlineDialog)
        AlertDialog(
          title: Text(widget.lang == 'cn' ? '知识点大纲' : 'Knowledge Outline'),
          content: Container(
            width: 400,
            height: 300,
            child: TextField(
              controller: TextEditingController(text: _outlineContent),
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(border: InputBorder.none),
              onChanged: (text) => _outlineContent = text,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => _showOutlineDialog = false),
              child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
            ),
            TextButton(
              onPressed: _saveOutline,
              child: Text(widget.lang == 'cn' ? '保存' : 'Save'),
            ),
          ],
        ),
      if (_showCategoryDialog)
        _buildCategoryDialog(),
      if (_showFilterDialog)
        _buildFilterDialog(),
    ];
  }
}

// Original build method kept for reference
class _KnowledgePointPageStateOriginal extends State<KnowledgePointPage> {
  List<KnowledgePoint> _knowledgePoints = [];
  List<KnowledgePoint> _filteredPoints = [];
  List<int> _selectedPoints = [];
  bool _isLoading = false;
  String _selectedTab = '筛选';
  String _keyword = '';
  String? _selectedCategory;
  String? _selectedLessonUnit;
  String? _selectedErrorType;
  String _outlineContent = '';
  bool _showOutlineDialog = false;
  bool _showCategoryDialog = false;
  final TextEditingController _keywordController = TextEditingController();

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  onChanged: (text) {
                    _keyword = text;
                    _filterPoints();
                  },
                  decoration: InputDecoration(
                    hintText: widget.lang == 'cn' ? '关键词搜索...' : 'Search keywords...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _clearFilters,
                child: Text(widget.lang == 'cn' ? '清空筛选' : 'Clear Filters'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(widget.lang == 'cn' ? '知识类目' : 'Category', _selectedCategory),
              const SizedBox(width: 8),
              _buildFilterChip(widget.lang == 'cn' ? '课内单元' : 'Lesson', _selectedLessonUnit),
              const SizedBox(width: 8),
              _buildFilterChip(widget.lang == 'cn' ? '错类' : 'Error Type', _selectedErrorType),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? selectedValue) {
    return FilterChip(
      label: Text(selectedValue ?? label),
      onSelected: (_) => _openFilterDialog(label),
      onDeleted: selectedValue != null ? () {
        if (label == (widget.lang == 'cn' ? '知识类目' : 'Category')) {
          _selectedCategory = null;
        } else if (label == (widget.lang == 'cn' ? '课内单元' : 'Lesson')) {
          _selectedLessonUnit = null;
        } else {
          _selectedErrorType = null;
        }
        _filterPoints();
      } : null,
    );
  }

  void _openFilterDialog(String label) {
    setState(() {
      _showFilterDialog = true;
    });
  }

  void _selectFilterValue(String type, String value) {
    setState(() {
      if (type == 'category') {
        _selectedCategory = value;
      } else if (type == 'lesson') {
        _selectedLessonUnit = value;
      } else if (type == 'error') {
        _selectedErrorType = value;
      }
      _showFilterDialog = false;
      _filterPoints();
    });
  }

  Widget _buildFilterDialog() {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '筛选选项' : 'Filter Options'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildFilterOption('category', widget.lang == 'cn' ? '知识类目' : 'Category'),
            const SizedBox(height: 16),
            _buildFilterOption('lesson', widget.lang == 'cn' ? '课内单元' : 'Lesson Unit'),
            const SizedBox(height: 16),
            _buildFilterOption('error', widget.lang == 'cn' ? '错类' : 'Error Type'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showFilterDialog = false),
          child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
        ),
      ],
    );
  }

  Widget _buildFilterOption(String type, String label) {
    List<String> options = [];
    String? selectedValue;

    if (type == 'category') {
      options = _outlineCategories.where((c) => !c.contains('.1.') && !c.contains('.2.')).toList();
      selectedValue = _selectedCategory;
    } else if (type == 'lesson') {
      options = ['1单元1课', '1单元2课', '1单元3课', '2单元1课', '2单元2课', '3单元1课'];
      selectedValue = _selectedLessonUnit;
    } else if (type == 'error') {
      options = ['审题', '计算', '概念', '理解', '表达'];
      selectedValue = _selectedErrorType;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) => Chip(
            label: Text(option),
            backgroundColor: selectedValue == option ? const Color(0xFFFF69B4) : Colors.grey[200],
            labelColor: selectedValue == option ? Colors.white : Colors.black,
            onPressed: () => _selectFilterValue(type, option),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildKnowledgePointItem(KnowledgePoint point) {
    final isSelected = _selectedPoints.contains(point.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSelect(point.id!),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'K${point.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF69B4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point.title,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (point.lessonUnit != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '课内: ${point.lessonUnit}',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (point.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '知识: ${point.category}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (point.errorType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '错类: ${point.errorType}',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}