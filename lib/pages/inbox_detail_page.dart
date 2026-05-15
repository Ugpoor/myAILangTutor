import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';

class InboxDetailPage extends StatefulWidget {
  final InboxItem item;
  final String lang;
  final VoidCallback onUpdate;

  const InboxDetailPage({
    super.key,
    required this.item,
    this.lang = 'cn',
    required this.onUpdate,
  });

  @override
  State<InboxDetailPage> createState() => _InboxDetailPageState();
}

class _InboxDetailPageState extends State<InboxDetailPage> {
  final InboxService _inboxService = InboxService();
  final TextEditingController _mdController = TextEditingController();
  bool _isLoading = false;
  bool _hasRepairableState = false;
  bool _showPreview = true; // 默认显示预览
  bool _isEditorFocused = false;

  final List<String> _categories = [
    '知识点',
    '错题本',
    '习题',
    '作品集',
    '未知归类',
  ];

  final List<String> _statuses = ['未处理', '已处理'];

  late String _selectedCategory;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.item.category;
    _selectedStatus = widget.item.status;
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 首先尝试从文件加载
      final fileContent = await _inboxService.readMarkdownFile(widget.item.filePath);
      if (fileContent.isNotEmpty) {
        _mdController.text = fileContent;
      } else {
        // 如果文件不存在，使用数据库中的内容
        _mdController.text = widget.item.content;
      }
    } catch (e) {
      _mdController.text = widget.item.content;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 保存到文件
      await _inboxService.saveMarkdownFile(widget.item.filePath, _mdController.text);

      // 更新数据库
      final updatedItem = widget.item.copyWith(
        content: _mdController.text,
        category: _selectedCategory,
        status: _selectedStatus,
      );

      await _inboxService.updateInboxItem(updatedItem);

      if (mounted) {
        widget.onUpdate();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '保存失败: $e' : 'Save failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn' 
            ? '确定要删除这条记录吗？这个操作无法撤销。' 
            : 'Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(widget.lang == 'cn' ? '删除' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _inboxService.deleteInboxItem(widget.item.id!);
        if (mounted) {
          widget.onUpdate();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.lang == 'cn' ? '删除失败: $e' : 'Delete failed: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onContentChanged() {
    setState(() {
      _hasRepairableState = true;
    });
  }

  void _toggleView() {
    setState(() {
      _showPreview = !_showPreview;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理 - 编辑文档' : 'My AI Language Assistant - Edit Document',
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isEditorFocused ? 0 : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isEditorFocused ? 0 : 1,
                child: AIReplyBar(
                  lang: widget.lang,
                  lastAiMessage: widget.lang == 'cn' ? '欢迎编辑文档，可以在编辑和预览之间切换。' : 'Welcome to edit the document. You can switch between edit and preview.',
                  onPullDown: () {},
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.item.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                widget.lang == 'cn' ? '来源' : 'Source',
                                                style: const TextStyle(color: Color(0xFFFF69B4), fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFE4E9),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(widget.item.source, style: const TextStyle(fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                widget.lang == 'cn' ? '归类' : 'Category',
                                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 4),
                                              DropdownButton<String>(
                                                value: _selectedCategory,
                                                items: _categories
                                                    .map((cat) => DropdownMenuItem(
                                                          value: cat,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF87CEEB),
                                                              borderRadius: BorderRadius.circular(3),
                                                            ),
                                                            child: Text(cat, style: const TextStyle(fontSize: 12)),
                                                          ),
                                                        ))
                                                    .toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedCategory = value!;
                                                    _hasRepairableState = true;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // 视图切换按钮
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _toggleView,
                                        icon: Icon(_showPreview ? Icons.edit : Icons.visibility),
                                        label: Text(_showPreview ? (widget.lang == 'cn' ? '编辑' : 'Edit') : (widget.lang == 'cn' ? '预览' : 'Preview')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF651FFF),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (widget.item.url.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(widget.lang == 'cn' ? '原始链接功能待实现' : 'Original link feature coming soon')),
                                            );
                                          },
                                          icon: const Icon(Icons.link, size: 16),
                                          label: Text(widget.lang == 'cn' ? '原始链接' : 'Original Link', style: const TextStyle(fontSize: 12)),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Markdown编辑器或预览
                                if (_showPreview)
                                  Container(
                                    height: 400,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Markdown(
                                      data: _mdController.text.isEmpty 
                                          ? (widget.lang == 'cn' ? '暂无内容' : 'No content') 
                                          : _mdController.text,
                                      styleSheet: MarkdownStyleSheet(
                                        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                        h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        p: const TextStyle(fontSize: 14, height: 1.5),
                                        code: const TextStyle(
                                          backgroundColor: Colors.grey,
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 400,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: TextField(
                                      controller: _mdController,
                                      maxLines: null,
                                      expands: true,
                                      decoration: InputDecoration(
                                        hintText: widget.lang == 'cn' ? '在此输入Markdown内容...' : 'Enter Markdown content here...',
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.all(12),
                                      ),
                                      onChanged: (_) => _onContentChanged(),
                                      onTap: () {
                                        setState(() {
                                          _isEditorFocused = true;
                                        });
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                    ),
                    const SizedBox(height: 8),
                    SubmenuTabs(
                      tabs: _hasRepairableState
                          ? (widget.lang == 'cn' ? ['取消', '保存', '删除'] : ['Cancel', 'Save', 'Delete'])
                          : (widget.lang == 'cn' ? ['取消', '保存', '删除'] : ['Cancel', 'Save', 'Delete']),
                      selectedTab: widget.lang == 'cn' ? '保存' : 'Save',
                      onTabSelected: (tab) async {
                        if (tab == (widget.lang == 'cn' ? '取消' : 'Cancel')) {
                          Navigator.of(context).pop();
                        } else if (tab == (widget.lang == 'cn' ? '保存' : 'Save')) {
                          await _saveChanges();
                        } else if (tab == (widget.lang == 'cn' ? '删除' : 'Delete')) {
                          await _deleteItem();
                        }
                      },
                      onHomeTap: () => Navigator.of(context).pop(),
                      lang: widget.lang,
                    ),
                    InputArea(
                      lang: widget.lang,
                      onTextChanged: (text) {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mdController.dispose();
    super.dispose();
  }
}
