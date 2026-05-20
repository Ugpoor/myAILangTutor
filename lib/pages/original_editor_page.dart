import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../components/app_title_bar.dart';
import '../../components/submenu_tabs.dart';
import '../../database/db_helper.dart';
import '../../database/models/portfolio_item.dart';
import '../../database/models/knowledge_point.dart';
import '../../services/llm_service.dart';

/// 原创编辑页面 - 可编辑富媒体MD编辑器 + 预览切换 + AI评析
class OriginalEditorPage extends StatefulWidget {
  final String lang;
  final PortfolioDao portfolioDao;
  final VoidCallback onHomeTap;
  final PortfolioItem? existingItem; // 如果是新建则为null

  const OriginalEditorPage({
    super.key,
    this.lang = 'cn',
    required this.portfolioDao,
    required this.onHomeTap,
    this.existingItem,
  });

  @override
  State<OriginalEditorPage> createState() => _OriginalEditorPageState();
}

class _OriginalEditorPageState extends State<OriginalEditorPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  late WebViewController _webViewController;
  
  String? _title;
  String? _knowledgeTag;
  String? _lessonUnit;
  bool _isAiAnalyzing = false;
  String? _aiReview;
  final LlmService _llmService = LlmService();
  
  List<String> _knowledgeTags = [];
  List<String> _lessonUnits = [];
  bool _isLoadingOptions = true;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    if (widget.existingItem != null) {
      _title = widget.existingItem!.title;
      _knowledgeTag = widget.existingItem!.knowledgeTag;
      _lessonUnit = widget.existingItem!.lessonUnit;
      _aiReview = widget.existingItem!.aiReview;
      
      // 加载已有内容
      _loadExistingContent();
    } else {
      _title = '';
      _knowledgeTag = null;
      _lessonUnit = null;
      _aiReview = null;
    }
    
    _editorFocusNode.addListener(() {
      if (_editorFocusNode.hasFocus) {
        setState(() {});
      }
    });
    
    _llmService.init();
    _initWebViewController();
    _loadOptions();
  }

  Future<void> _loadExistingContent() async {
    try {
      if (widget.existingItem?.contentPath != null) {
        final filePath = '${widget.existingItem!.contentPath}/index.html';
        final file = File(filePath);
        if (await file.exists()) {
          var content = await file.readAsString(encoding: utf8);
          // 提取HTML body内容
          final match = RegExp(r'<body[^>]*>(.*?)</body>').firstMatch(content);
          if (match != null) {
            content = match.group(1)!;
            // 去除HTML标签转为纯文本
            content = content
                .replaceAll(RegExp(r'<[^>]*>'), '\n')
                .replaceAll(RegExp(r'\n+'), '\n')
                .trim();
          }
          _textController.text = content;
        }
      }
    } catch (e) {
      print('[OriginalEditor] 加载内容失败: $e');
    }
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(_buildHtmlPreview(''));
  }

  String _buildHtmlPreview(String content) {
    // 简单的 Markdown -> HTML 转换
    String html = content
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    
    // 标题
    html = html.replaceAllMapped(RegExp(r'^# (.*$)', multiLine: true), (m) => '<h1>${m.group(1)}</h1>');
    html = html.replaceAllMapped(RegExp(r'^## (.*$)', multiLine: true), (m) => '<h2>${m.group(1)}</h2>');
    html = html.replaceAllMapped(RegExp(r'^### (.*$)', multiLine: true), (m) => '<h3>${m.group(1)}</h3>');
    
    // 段落
    html = html.split('\n\n').map((p) {
      p = p.trim();
      if (p.isEmpty) return '';
      if (p.startsWith('<h') || p.startsWith('<ul') || p.startsWith('<ol')) return p;
      return '<p>$p</p>';
    }).join('\n');
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
      font-size: 16px;
      line-height: 1.6;
      color: #333;
      padding: 16px;
      margin: 0;
    }
    h1 { font-size: 24px; font-weight: bold; margin: 16px 0 12px; color: #1a1a1a; border-bottom: 2px solid #eee; padding-bottom: 8px; }
    h2 { font-size: 20px; font-weight: bold; margin: 14px 0 10px; color: #2a2a2a; border-bottom: 1px solid #eee; padding-bottom: 6px; }
    h3 { font-size: 18px; font-weight: bold; margin: 12px 0 8px; color: #3a3a3a; }
    p { margin: 10px 0; }
    img { max-width: 100%; height: auto; border-radius: 4px; margin: 8px 0; }
    strong { font-weight: bold; }
    em { font-style: italic; }
  </style>
</head>
<body>
  ${html.isEmpty ? '<p style="color: #999;">暂无内容，请在左侧编辑区域输入 Markdown...</p>' : html}
</body>
</html>
''';
  }

  Future<void> _loadOptions() async {
    try {
      final db = await DatabaseHelper().database;
      final dao = KnowledgePointDao(db);
      
      final knowledgePoints = await dao.getAll(lang: widget.lang);
      final kTags = knowledgePoints.map((p) => p.title).whereType<String>().toSet().toList();
      final lessonUnits = await dao.getAllLessonUnits();
      
      setState(() {
        _knowledgeTags = kTags;
        _lessonUnits = lessonUnits;
        _isLoadingOptions = false;
      });
    } catch (e) {
      print('[OriginalEditor] 加载选项失败: $e');
      setState(() => _isLoadingOptions = false);
    }
  }

  /// 更新预览
  void _updatePreview() {
    final content = _textController.text;
    _webViewController.loadHtmlString(_buildHtmlPreview(content));
    setState(() => _hasUnsavedChanges = content.isNotEmpty);
  }

  /// 保存作品
  Future<void> _savePortfolio() async {
    if (_title == null || _title!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请输入文章标题' : 'Please enter a title')),
      );
      return;
    }

    try {
      // 获取当前内容
      final content = _textController.text;
      
      // 创建/更新目录结构
      final db = await DatabaseHelper().database;
      final dao = PortfolioDao(db);
      
      if (widget.existingItem?.id != null) {
        // 更新现有作品
        final updated = widget.existingItem!.copyWith(
          title: _title!.trim(),
          contentPath: widget.existingItem!.contentPath,
          knowledgeTag: _knowledgeTag,
          lessonUnit: _lessonUnit,
          aiReview: _aiReview,
          isOriginal: true,
        );
        await dao.update(updated);
      } else {
        // 新建作品
        final nextNum = await dao.nextPortfolioIdNumber();
        final portfolioId = 'W${nextNum.toString().padLeft(3, "0")}Y';
        
        final item = PortfolioItem(
          title: _title!.trim(),
          type: 'original',
          contentPath: null, // TODO: 保存到文件
          portfolioId: portfolioId,
          isOriginal: true,
          knowledgeTag: _knowledgeTag,
          lessonUnit: _lessonUnit,
          aiReview: _aiReview,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );
        
        await dao.insert(item);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '作品已保存' : 'Portfolio saved')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('[OriginalEditor] 保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '保存失败: ${e.toString()}' : 'Save failed: ${e.toString()}')),
        );
      }
    }
  }

  /// 生成原创评析
  Future<void> _generateReview() async {
    if (_isAiAnalyzing) return;
    
    final content = _textController.text;
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先输入文章内容' : 'Please enter article content first')),
      );
      return;
    }

    setState(() => _isAiAnalyzing = true);

    try {
      final prompt = '请从"立意"、"文章布局"、"文学表达手法"、"可参考的其他名人名著中片段"对以下原创作文进行评述，中肯客观，不仅描述优点，也描述缺点。\n\n标题：${_title}\n正文：\n$content';

      final response = await _llmService.generateResponse(prompt);
      final review = response['response'] ?? '';

      setState(() {
        _aiReview = review;
        _isAiAnalyzing = false;
      });
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
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _editorFocusNode.removeListener(() {});
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '取消' : 'Cancel',
      widget.lang == 'cn' ? '保存' : 'Save',
      widget.lang == 'cn' ? '评析' : 'Review',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '原创编辑' : 'Original Editor',
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  children: [
                    // 标题输入行
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              widget.lang == 'cn' ? '标题：' : 'Title:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _title = v),
                              decoration: InputDecoration(
                                hintText: widget.lang == 'cn' ? '输入文章标题' : 'Enter title',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 标签选择行
                    if (_isLoadingOptions)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                widget.lang == 'cn' ? '知识点：' : 'Knowledge:',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _knowledgeTags.contains(_knowledgeTag) ? _knowledgeTag : null,
                                decoration: InputDecoration(
                                  hintText: widget.lang == 'cn' ? '请选择' : 'Select',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                items: _knowledgeTags.map((tag) => DropdownMenuItem(value: tag, child: Text(tag, style: const TextStyle(fontSize: 11)))).toList(),
                                onChanged: (v) => setState(() => _knowledgeTag = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: Text(
                                widget.lang == 'cn' ? '课内：' : 'Lesson:',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _lessonUnits.contains(_lessonUnit) ? _lessonUnit : null,
                                decoration: InputDecoration(
                                  hintText: widget.lang == 'cn' ? '请选择' : 'Select',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                items: _lessonUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit, style: const TextStyle(fontSize: 11)))).toList(),
                                onChanged: (v) => setState(() => _lessonUnit = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    Divider(height: 1),
                    
                    // Tab 切换栏
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '编辑'),
                        Tab(text: '预览'),
                      ],
                      indicatorColor: const Color(0xFF651FFF),
                    ),
                    
                    // 编辑器/预览区域
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 编辑模式
                          Column(
                            children: [
                              // 工具栏
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                                ),
                                child: Row(
                                  children: [
                                    _buildToolbarButton('H1', () {
                                      _insertAtCursor('# ');
                                    }),
                                    _buildToolbarButton('H2', () {
                                      _insertAtCursor('## ');
                                    }),
                                    _buildToolbarButton('H3', () {
                                      _insertAtCursor('### ');
                                    }),
                                    const SizedBox(width: 8),
                                    _buildToolbarButton('**粗体**', () {
                                      _insertAtCursorWithSelection('**粗体文字**');
                                    }),
                                    _buildToolbarButton('*斜体*', () {
                                      _insertAtCursorWithSelection('*斜体文字*');
                                    }),
                                    const Spacer(),
                                    Text(
                                      widget.lang == 'cn' ? 'Markdown 格式' : 'Markdown Format',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              // 文本编辑区
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _editorFocusNode,
                                  onChanged: (_) => _updatePreview(),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  enableInteractiveSelection: true,
                                ),
                              ),
                            ],
                          ),
                          // 预览模式
                          WebViewWidget(controller: _webViewController),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: (tab) {
                final cnCancel = widget.lang == 'cn' ? '取消' : 'Cancel';
                final cnSave = widget.lang == 'cn' ? '保存' : 'Save';
                final cnReview = widget.lang == 'cn' ? '评析' : 'Review';

                if (tab == cnCancel) {
                  Navigator.of(context).pop(false);
                } else if (tab == cnSave) {
                  _savePortfolio();
                } else if (tab == cnReview) {
                  _generateReview();
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

  Widget _buildToolbarButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  void _insertAtCursor(String text) {
    final controller = _textController;
    final selection = controller.selection;
    
    if (selection.start == selection.end) {
      controller.text = controller.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      controller.selection = TextSelection.collapsed(
        offset: selection.start + text.length,
      );
    } else {
      controller.text = controller.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      controller.selection = TextSelection.collapsed(
        offset: selection.start + text.length,
      );
    }
    
    _updatePreview();
  }

  void _insertAtCursorWithSelection(String text) {
    final controller = _textController;
    final selection = controller.selection;
    
    controller.text = controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    
    // 选中中间的文字
    final startOffset = selection.start ?? 0;
    final endOffset = startOffset + text.length;
    controller.selection = TextSelection(baseOffset: startOffset, extentOffset: endOffset);
    
    _updatePreview();
  }
}
