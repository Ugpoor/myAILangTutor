import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/colored_label.dart';
import '../components/html_preview.dart';
import '../database/db_helper.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/knowledge_point.dart';
import '../services/llm_service.dart';

class PortfolioDetailPage extends StatefulWidget {
  final String lang;
  final PortfolioItem item;
  final PortfolioDao portfolioDao;
  final VoidCallback onHomeTap;

  const PortfolioDetailPage({
    super.key,
    this.lang = 'cn',
    required this.item,
    required this.portfolioDao,
    required this.onHomeTap,
  });

  @override
  State<PortfolioDetailPage> createState() => _PortfolioDetailPageState();
}

class _PortfolioDetailPageState extends State<PortfolioDetailPage> {
  late PortfolioItem _item;
  late TextEditingController _titleController;
  String? _selectedUnitNumber;
  String? _selectedLessonNumber;
  String? _selectedKid;
  List<String> _kidOptions = [];
  bool _isLoadingOptions = true;
  bool _isAiAnalyzing = false;
  final LlmService _llmService = LlmService();
  bool _showAiReview = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _titleController = TextEditingController(text: _item.title);
    _selectedUnitNumber = _item.unitNumber;
    _selectedLessonNumber = _item.lessonNumber;
    _selectedKid = _item.kid;
    _llmService.init();
    _showAiReview = _item.aiReview != null && _item.aiReview!.isNotEmpty;
    _loadKidOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadKidOptions() async {
    final db = await DatabaseHelper().database;
    final kpDao = KnowledgePointDao(db);
    final all = await kpDao.getAll();
    if (mounted) {
      setState(() {
        _kidOptions = all.map((e) => e.kid ?? '').where((e) => e.isNotEmpty).toList();
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

  Future<void> _saveItem() async {
    final updated = _item.copyWith(
      title: _titleController.text.trim(),
      unitNumber: _selectedUnitNumber,
      lessonNumber: _selectedLessonNumber,
      kid: _selectedKid,
    );
    
    await widget.portfolioDao.update(updated);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除作品 "${_item.title}" 吗？'
            : 'Are you sure you want to delete "${_item.title}"?'),
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
      await widget.portfolioDao.delete(_item.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _generateAiReview() async {
    if (_isAiAnalyzing) return;
    
    setState(() => _isAiAnalyzing = true);

    try {
      String articleContent = '';
      if (_item.contentPath != null) {
        final filePath = '${_item.contentPath}/index.html';
        final file = File(filePath);
        if (await file.exists()) {
          articleContent = await file.readAsString(encoding: utf8);
          articleContent = articleContent
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        }
      }

      if (articleContent.isEmpty) {
        articleContent = '(无内容)';
      }

      final prompt = '请从"立意"、"文章布局"、"文学表达手法"、"可参考的其他名人名著中片段"对以下原创作文进行评述，中肯客观，不仅描述优点，也描述缺点。\n\n${articleContent.substring(0, articleContent.length > 500 ? 500 : articleContent.length)}...';

      final response = await _llmService.generateResponse(prompt);
      final review = response['response'] ?? '';

      setState(() {
        _isAiAnalyzing = false;
        _showAiReview = true;
      });

      final updated = _item.copyWith(aiReview: review);
      await widget.portfolioDao.update(updated);
      _item = updated;
    } catch (e) {
      setState(() => _isAiAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '评析失败: ${e.toString()}' : 'Analysis failed: ${e.toString()}')),
        );
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

    final shouldShowAiReviewButton = _item.isOriginal && (_item.aiReview == null || _item.aiReview!.isEmpty);
    final testRecsCount = _item.testRecs != null && _item.testRecs!.isNotEmpty 
        ? _item.testRecs!.split(',').length 
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理 - 作品详情' : 'My AI Language Assistant - Portfolio Detail',
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
                          // 作品ID和标题
                          Row(
                            children: [
                              Text(
                                '${_item.wid ?? ""} ',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              Expanded(
                                child: Text(
                                  _item.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 标签行
                          if (_isLoadingOptions)
                            const Center(child: CircularProgressIndicator())
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // 类型标签
                                _buildLabelValue(
                                  '类型',
                                  _item.isOriginal 
                                      ? (widget.lang == 'cn' ? '原创' : 'Original')
                                      : (widget.lang == 'cn' ? '赏析' : 'Analysis'),
                                  _item.isOriginal ? const Color(0xFFFFE4B5) : const Color(0xFFE0FFFF),
                                ),
                                // 知识点标签 - 可编辑下拉
                                _buildKidDropdown(
                                  '知识点',
                                  _selectedKid,
                                  const Color(0xFFFFE4E9),
                                  (value) {
                                    setState(() => _selectedKid = value);
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
                                if (testRecsCount > 0)
                                  _buildLabelValue('练习', '${testRecsCount}次', const Color(0xFF90EE90)),
                                // AI点评标签
                                if (_showAiReview)
                                  _buildLabelValue('AI评', widget.lang == 'cn' ? '已点评' : 'Reviewed', const Color(0xFF90EE90)),
                              ],
                            ),
                          // AI点评按钮
                          if (shouldShowAiReviewButton)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ElevatedButton.icon(
                                onPressed: _isAiAnalyzing ? null : _generateAiReview,
                                icon: _isAiAnalyzing
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.auto_awesome, size: 16),
                                label: Text(_isAiAnalyzing
                                    ? (widget.lang == 'cn' ? '点评中...' : 'Reviewing...')
                                    : (widget.lang == 'cn' ? 'AI点评' : 'AI Review')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF69B4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 内容区域
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // HTML预览
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: _buildHtmlPreview(),
                            ),
                          ),
                          // AI点评显示
                          if (_showAiReview)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FFF0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.lang == 'cn' ? 'AI点评' : 'AI Review',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _item.aiReview ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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
                  _saveItem();
                } else if (tab == cnDelete) {
                  _deleteItem();
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

  Widget _buildKidDropdown(
    String label,
    String? value,
    Color bgColor,
    Function(String?) onChanged,
  ) {
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
              value: _kidOptions.contains(value) ? value : null,
              isDense: true,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              hint: Text(widget.lang == 'cn' ? '请选择' : 'Select', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(widget.lang == 'cn' ? '请选择' : 'Select', style: const TextStyle(fontSize: 12)),
                ),
                ..._kidOptions.map((option) {
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
    if (_item.contentPath == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lang == 'cn' ? '内容区域' : 'Content Area',
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
      filePath: _item.contentPath,
      showAppBar: false,
    );
  }
}
