import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/colored_label.dart';
import '../components/html_preview.dart';
import '../components/wysiwyg_editor.dart';
import '../database/db_helper.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/exercise.dart';
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
  late TextEditingController _articleContentController;
  late TextEditingController _unitNoController; // 单元号
  late TextEditingController _lessonNoController; // 课号
  bool _isAiAnalyzing = false;
  String? _aiReview;
  final LlmService _llmService = LlmService();
  bool _isLoadingOptions = true;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _titleController = TextEditingController(text: _item.title);
    _articleContentController = TextEditingController(text: _getInitialArticleContent());
    
    // 解析单元和课号
    _unitNoController = TextEditingController(text: _item.unitNumber ?? '');
    _lessonNoController = TextEditingController(text: _item.lessonNumber ?? '');
    
    _aiReview = _item.aiReview;
    _llmService.init();
    _loadOptions().then((_) {
      // 如果还没有评析，自动生成
      if (_aiReview == null && mounted) {
        _autoGenerateReview();
      }
    });
  }
  
  /// 从课内单元字符串提取单元号（如"五年级上-第一单元第3课" -> "3"）
  String _parseUnitNo(String lessonUnit) {
    final match = RegExp(r'第(\d+)单').firstMatch(lessonUnit);
    return match?.group(1) ?? '';
  }
  
  /// 从课内单元字符串提取课号（如"五年级上-第一单元第3课" -> "3"）
  String _parseLessonNo(String lessonUnit) {
    final match = RegExp(r'第(\d+)课$').firstMatch(lessonUnit);
    return match?.group(1) ?? '';
  }
  
  /// 生成课内单元字符串（如"3" + "5" -> "第一单元第5课"）
  String _buildLessonUnit() {
    final unitNo = _unitNoController.text.trim();
    final lessonNo = _lessonNoController.text.trim();
    if (unitNo.isEmpty && lessonNo.isEmpty) return '';
    final unitText = unitNo.isEmpty ? '' : '第${unitNo}单元';
    final lessonText = lessonNo.isEmpty ? '' : '第${lessonNo}课';
    return '$unitText$lessonText'.trim();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _articleContentController.dispose();
    _unitNoController.dispose();
    _lessonNoController.dispose();
    super.dispose();
  }

  // Store article content for saving
  String _articleContent = '';

  String _getInitialArticleContent() {
    if (_item.contentPath != null) {
      final filePath = '${_item.contentPath}/index.html';
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          return file.readAsStringSync(encoding: utf8);
        } catch (e) {
          print('[PortfolioDetail] 读取文章失败: $e');
        }
      }
    }
    return '';
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoadingOptions = false);
  }

  Future<void> _saveItem() async {
    // 先保存文章内容到文件
    if (_item.contentPath != null) {
      final dir = Directory(_item.contentPath!);
      if (await dir.exists()) {
        final indexFile = File('${dir.path}/index.html');
        await indexFile.writeAsString(
          _articleContent.isEmpty ? '<p>暂无内容</p>' : _articleContent,
          encoding: utf8,
        );
      }
    }

    final updated = _item.copyWith(
      title: _titleController.text.trim(),
      unitNumber: _unitNoController.text.trim().isEmpty ? null : _unitNoController.text.trim(),
      lessonNumber: _lessonNoController.text.trim().isEmpty ? null : _lessonNoController.text.trim(),
      aiReview: _aiReview,
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

  /// AI自动生成评析
  Future<void> _autoGenerateReview() async {
    if (_isAiAnalyzing || _aiReview != null) return;
    
    setState(() => _isAiAnalyzing = true);

    try {
      if (_item.isOriginal) {
        await _aiAnalyzeOriginal();
      } else {
        await _aiAnalyzeNonOriginal();
      }
    } catch (e) {
      setState(() => _isAiAnalyzing = false);
    }
  }

  /// AI评析 - 针对原创内容
  Future<void> _aiAnalyzeOriginal() async {
    if (_isAiAnalyzing) return;
    
    setState(() => _isAiAnalyzing = true);

    try {
      // 获取文章内容
      String articleContent = '';
      if (_item.contentPath != null) {
        final filePath = '${_item.contentPath}/index.html';
        final file = File(filePath);
        if (await file.exists()) {
          articleContent = await file.readAsString(encoding: utf8);
          // 去除HTML标签只保留文本
          articleContent = articleContent
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        }
      }

      if (articleContent.isEmpty) {
        articleContent = '(无内容)';
      }

      final prompt = '请从"立意"、"文章布局"、"文学表达手法"、"可参考的其他名人名著中片段"对以下原创作文"{文章}"进行评述，中肯客观，不仅描述优点，也描述缺点。\n\n${articleContent.substring(0, articleContent.length > 500 ? 500 : articleContent.length)}...';

      final response = await _llmService.generateResponse(prompt);
      final review = response['response'] ?? '';

      setState(() {
        _aiReview = review;
        _isAiAnalyzing = false;
      });

      // 自动保存评析结果
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

  /// AI评析 - 非原创作品
  Future<void> _aiAnalyzeNonOriginal() async {
    if (_isAiAnalyzing) return;
    
    setState(() => _isAiAnalyzing = true);

    try {
      final prompt = '请对以下作品进行赏析，包括写作手法、语言特色和情感表达：\n标题：${_item.title}';

      final response = await _llmService.generateResponse(prompt);
      final review = response['response'] ?? '';

      setState(() {
        _aiReview = review;
        _isAiAnalyzing = false;
      });

      // 自动保存评析结果
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
      widget.lang == 'cn' ? '取消' : 'Cancel',
      widget.lang == 'cn' ? '保存' : 'Save',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '作品详情' : 'Portfolio Detail',
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
                      // 作品ID + 标题
                      Row(
                        children: [
                          Text(
                            '${_item.wid ?? ""} ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: widget.lang == 'cn' ? '文章标题' : 'Title',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // ========== 紧凑标签区域 ==========
                      if (_isLoadingOptions)
                        const Center(child: CircularProgressIndicator()),
                      ...[
                        
                        const SizedBox(height: 4),
                        
                        // 课内单元 - 手动输入（非年级，格式：第X单元第X课）
                        Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                widget.lang == 'cn' ? '课内标签' : 'Lesson:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // 单元号输入框
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _unitNoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: widget.lang == 'cn' ? '单元' : 'Unit',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  helperText: widget.lang == 'cn' ? '如：1' : 'e.g. 1',
                                  helperStyle: const TextStyle(fontSize: 10),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 4),
                            
                            // 课号输入框
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _lessonNoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: widget.lang == 'cn' ? '课号' : 'Lesson',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  helperText: widget.lang == 'cn' ? '如：3' : 'e.g. 3',
                                  helperStyle: const TextStyle(fontSize: 10),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // 预览完整格式
                            Expanded(
                              child: Text(
                                _buildLessonUnit().isEmpty 
                                    ? (widget.lang == 'cn' ? '请输入单元号和课号' : 'Enter unit and lesson no.')
                                    : _buildLessonUnit(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        
                        const SizedBox(height: 4),
                        
                        
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // ========== 富媒体编辑器（H1-H3，图片，视频） ==========
                      Text(
                        widget.lang == 'cn' ? '文章内容' : 'Article Content',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
                        child: WysiwygEditor(
                          initialContent: _getInitialArticleContent(),
                          lang: widget.lang,
                          onContentChanged: (html) {
                            setState(() {
                              _articleContent = html;
                            });
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // ========== AI 评析（直接展示，非按钮） ==========
                      Row(
                        children: [
                          Text(
                            widget.lang == 'cn' ? 'AI评析' : 'AI Review',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          if (_aiReview == null)
                            OutlinedButton.icon(
                              onPressed: _isAiAnalyzing ? null : (_item.isOriginal ? _aiAnalyzeOriginal : _aiAnalyzeNonOriginal),
                              icon: _isAiAnalyzing
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.auto_awesome, size: 16),
                              label: Text(_isAiAnalyzing
                                  ? (widget.lang == 'cn' ? '评析中...' : 'Analyzing...')
                                  : (widget.lang == 'cn' ? '生成评析' : 'Generate Review')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF651FFF),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _aiReview != null ? const Color(0xFFF0FFF0) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _aiReview != null ? Colors.green[200]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          _aiReview ?? (widget.lang == 'cn' ? '尚未进行评析，点击"生成评析"按钮' : 'No review yet. Click "Generate Review"'),
                          style: TextStyle(
                            fontSize: 14,
                            color: _aiReview != null ? Colors.black87 : Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: (tab) {
                final cnCancel = widget.lang == 'cn' ? '取消' : 'Cancel';
                final cnSave = widget.lang == 'cn' ? '保存' : 'Save';
                final cnDelete = widget.lang == 'cn' ? '删除' : 'Delete';

                if (tab == cnCancel) {
                  Navigator.of(context).pop(false);
                } else if (tab == cnSave) {
                  _saveItem();
                } else if (tab == cnDelete) {
                  _deleteItem();
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

  /// 构建下拉标签选择器
  Widget _buildLabelDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String type, // knowledge, lesson, exercise, errorType
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: items.contains(value) ? value : null,
            decoration: InputDecoration(
              hintText: widget.lang == 'cn' ? '请选择' : 'Select',
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              constraints: const BoxConstraints(maxHeight: 32),
            ),
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// 构建 HTML 预览区（不可编辑）
  Widget _buildHtmlPreview() {
    if (_item.contentPath == null) {
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
