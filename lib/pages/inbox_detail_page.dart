import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import '../database/db_helper.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/html_preview.dart';

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
  bool _isProcessing = false;
  String _selectedSource = '';
  String _selectedCategory = '';
  // Classification history for AIReplyBar display (user message + AI response)
  List<Map<String, String>> _classificationHistory = [];

  final List<String> _sourceOptions = [
    '豆包', '文心一言', '通义千问', '讯飞星火', 'Kimi',
    'ChatGPT', 'Claude', 'Gemini', 'Copilot', '智谱清言', '混元', '元宝',
    'Perplexity', 'Mistral', 'Poe', '其他', '未知',
  ];

  final List<String> _categoryOptions = [
    '错题本', '知识点', '习题集', '作品集', '无法分类', '未知归类',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSource = _sourceOptions.contains(widget.item.source)
        ? widget.item.source
        : '未知';
    _selectedCategory = _categoryOptions.contains(widget.item.category)
        ? widget.item.category
        : '未知归类';

    // Load historical classification messages from database
    _loadChatHistory();
  }

  /// Load AI classification messages from database for display in AIReplyBar
  Future<void> _loadChatHistory() async {
    try {
      final db = DatabaseHelper();
      final rawMessages = await db.getClassificationMessages();

      final List<Map<String, String>> history = rawMessages.map((msg) {
        return {
          'user': '', // empty since these are auto-generated AI replies
          'ai': msg['content'] as String,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _classificationHistory = history.reversed.toList(); // show newest first
        });
      }
    } catch (e) {
      print('[InboxDetailPage] Failed to load chat history: $e');
    }
  }

  Future<void> _updateSource(String value) async {
    setState(() => _selectedSource = value);
    final updated = widget.item.copyWith(source: value);
    await _inboxService.updateInboxItem(updated);
  }

  Future<void> _updateCategory(String value) async {
    setState(() => _selectedCategory = value);
    final updated = widget.item.copyWith(category: value);
    await _inboxService.updateInboxItem(updated);
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(widget.lang == 'cn' ? '删除' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await _inboxService.deleteItem(widget.item);
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
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _organizeItem() async {
    setState(() => _isProcessing = true);

    // Build user prompt text for history display
    final userPromptText = widget.item.content.length > 200
        ? '${widget.item.content.substring(0, 200)}...(truncated)'
        : widget.item.content;

    try {
      // Use unified classification from InboxService
      final result = await _inboxService.classifyItem(widget.item);
      final category = result.category;
      final newTitle = result.newTitle;

      // Update the item with classified category and optional new title
      final updatedItem = widget.item.copyWith(
        title: newTitle ?? widget.item.title,
        category: category,
        status: '已处理',
      );

      // Save to database first
      await _inboxService.updateInboxItem(updatedItem);

      if (mounted) {
        // Refresh local UI state
        setState(() {
          _selectedCategory = category;
        });

        // Re-fetch fresh data to ensure consistency
        widget.onUpdate();

        // Add classification conversation to history for AIReplyBar
        final aiReplyText = '分类结果：$category\n依据：${result.reasoning}';
        setState(() {
          _classificationHistory.add({
            'user': userPromptText,
            'ai': aiReplyText,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn'
              ? '整理完成！（分类: $category）'
              : 'Organized! (Category: $category)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '整理失败: $e' : 'Organize failed: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _performClassification(String content, [String? newTitle]) async {
    // Deprecated: All classification goes through _organizeItem() -> _inboxService.classifyItem()
    await _organizeItem();
  }

  @override
  Widget build(BuildContext context) {
    // Current AI message shows either progress or last result
    String currentAiMessage;
    if (_isProcessing) {
      currentAiMessage = widget.lang == 'cn' ? '正在整理文档...' : 'Organizing document...';
    } else if (_classificationHistory.isNotEmpty) {
      final lastMsg = _classificationHistory.last;
      currentAiMessage = lastMsg['ai']!;
    } else {
      currentAiMessage = widget.lang == 'cn' ? '正在查看文档' : 'Viewing the document';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理 - 查看文档' : 'My AI Language Assistant - View Document',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: currentAiMessage,
              onPullDown: () {},
              historyMessages: _classificationHistory.isEmpty ? null : _classificationHistory,
            ),
            Expanded(
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
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
                                Text(
                                  widget.item.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    _buildEditableDropdown(
                                      '来源',
                                      _selectedSource,
                                      const Color(0xFFFF69B4),
                                      const Color(0xFFFFE4E9),
                                      _sourceOptions,
                                      _updateSource,
                                    ),
                                    _buildEditableDropdown(
                                      '分类',
                                      _selectedCategory,
                                      Colors.blue,
                                      const Color(0xFF87CEEB),
                                      _categoryOptions,
                                      _updateCategory,
                                    ),
                                    _buildLabelValue('状态', widget.item.status, Colors.green, _getStatusColor(widget.item.status)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: HtmlPreview(filePath: widget.item.filePath, showAppBar: false),
                          ),
                        ),
                      ],
                    ),
            ),
            SubmenuTabs(
              tabs: widget.lang == 'cn' ? ['返回', '整理', '删除'] : ['Back', 'Organize', 'Delete'],
              selectedTab: widget.lang == 'cn' ? '返回' : 'Back',
              onTabSelected: (tab) async {
                if (tab == (widget.lang == 'cn' ? '返回' : 'Back')) {
                  Navigator.of(context).pop();
                } else if (tab == (widget.lang == 'cn' ? '整理' : 'Organize')) {
                  await _organizeItem();
                } else if (tab == (widget.lang == 'cn' ? '删除' : 'Delete')) {
                  await _deleteItem();
                }
              },
              onHomeTap: () => Navigator.of(context).pop(),
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableDropdown(String label, String value, Color labelColor, Color bgColor, List<String> options, ValueChanged<String> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Container(
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(3)),
          child: DropdownButton<String>(
            value: options.contains(value) ? value : null,
            underline: const SizedBox.shrink(),
            iconEnabledColor: Colors.grey[600],
            dropdownColor: Colors.white,
            isDense: true,
            items: options.map((opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(opt, style: const TextStyle(fontSize: 12)),
                ),
              );
            }).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ],
    );
  }

  Widget _buildLabelValue(String label, String value, Color labelColor, Color bgColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(3)),
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已处理':
      case '已整理':
        return const Color(0xFF90EE90);
      case '处理中':
        return const Color(0xFFFFA500);
      case 'error':
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFFFFE4E9);
    }
  }
}
