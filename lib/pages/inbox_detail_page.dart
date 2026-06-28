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
  final VoidCallback onHomeTap;

  const InboxDetailPage({
    super.key,
    required this.item,
    this.lang = 'cn',
    required this.onUpdate,
    required this.onHomeTap,
  });

  @override
  State<InboxDetailPage> createState() => _InboxDetailPageState();
}

class _InboxDetailPageState extends State<InboxDetailPage> {
  final InboxService _inboxService = InboxService();
  bool _isProcessing = false;
  String _selectedSource = '';
  String _selectedCategory = '';
  // Local state tracking for mutable fields (widget.item is immutable)
  String _currentStatus = '';
  String _currentFilePath = '';
  String _currentTitle = '';
  // Classification history for AIReplyBar display (user message + AI response)
  List<Map<String, String>> _classificationHistory = [];

  final List<String> _sourceOptions = [
    '豆包',
    '文心一言',
    '通义千问',
    '讯飞星火',
    'Kimi',
    'ChatGPT',
    'Claude',
    'Gemini',
    'Copilot',
    '智谱清言',
    '混元',
    '元宝',
    'Perplexity',
    'Mistral',
    'Poe',
    '其他',
    '未知',
  ];

  final List<String> _categoryOptions = [
    '错题本',
    '知识点',
    '习题集',
    '作品集',
    '无法分类',
    '未知归类',
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
    _currentStatus = widget.item.status;
    _currentFilePath = widget.item.filePath;
    _currentTitle = widget.item.title;

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
          _classificationHistory = history.reversed
              .toList(); // show newest first
        });
      }
    } catch (e) {
      print('[InboxDetailPage] Failed to load chat history: $e');
    }
  }

  Future<void> _updateSource(String value) async {
    setState(() => _selectedSource = value);
    final updated = widget.item.copyWith(
      source: value,
      filePath: _currentFilePath,
      category: _selectedCategory,
      status: _currentStatus,
      title: _currentTitle,
    );
    await _inboxService.updateInboxItem(updated);
  }

  Future<void> _updateCategory(String value) async {
    final previousCategory = _selectedCategory;
    setState(() => _selectedCategory = value);

    // 如果选择了有效分类且不是当前分类，触发手工分类整理
    if (value != previousCategory &&
        (value == '错题本' ||
            value == '习题集' ||
            value == '作品集' ||
            value == '知识点')) {
      // 先确认用户是否要进行手工分类整理
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            widget.lang == 'cn' ? '确认手工分类' : 'Confirm Manual Classification',
          ),
          content: Text(
            widget.lang == 'cn'
                ? '确定要将该条目分类到 \"$value\" 吗？系统将对文档进行解析并在目标栏目创建记录。'
                : 'Are you sure you want to classify this item as \"$value\"? The system will parse the document and create a record in the target section.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(widget.lang == 'cn' ? '确定' : 'Confirm'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // 调用手工分类整理函数
        await _manualOrganizeToCategory(value);
      } else {
        // 用户取消，恢复原来的分类
        setState(() => _selectedCategory = previousCategory);
      }
    } else {
      // 只是简单地更新分类，不进行整理
      final updated = widget.item.copyWith(
        category: value,
        filePath: _currentFilePath,
        status: _currentStatus,
        title: _currentTitle,
      );
      await _inboxService.updateInboxItem(updated);
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(
          widget.lang == 'cn'
              ? '确定要删除这条记录吗？这个操作无法撤销。'
              : 'Are you sure you want to delete this item? This action cannot be undone.',
        ),
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
            SnackBar(
              content: Text(
                widget.lang == 'cn' ? '删除失败: $e' : 'Delete failed: $e',
              ),
            ),
          );
        }
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _organizeItem() async {
    // 检查是否已经是"已处理"状态（使用本地追踪的状态）
    if (_currentStatus == '已处理') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn'
                  ? '该条目已整理，不可再整理'
                  : 'This item has already been organized',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    // Build user prompt text for history display
    final userPromptText = widget.item.content.length > 200
        ? '${widget.item.content.substring(0, 200)}...(truncated)'
        : widget.item.content;

    try {
      // 使用完整流水线：分类 + 移动文件 + 写入模块表 + 更新DB
      final tempItem = widget.item.copyWith(
        filePath: _currentFilePath,
        status: '处理中',
      );
      final result = await _inboxService.processAndClassifyItem(tempItem);
      final category = result['category'] ?? '未知归类';
      final reasoning = result['reasoning'] ?? '';

      // 从 DB 重新读取最新状态，确保本地状态与 DB 一致
      final freshItem = widget.item.id != null
          ? await DatabaseHelper().getInboxItemById(widget.item.id!)
          : null;

      if (mounted) {
        setState(() {
          _selectedCategory = category;
          _currentStatus = freshItem?.status ?? '已处理';
          _currentFilePath = freshItem?.filePath ?? _currentFilePath;
          _currentTitle = freshItem?.title ?? _currentTitle;
        });

        // Re-fetch fresh data to ensure consistency
        widget.onUpdate();

        // Add classification conversation to history for AIReplyBar
        final aiReplyText = '分类结果：$category\n依据：$reasoning';
        setState(() {
          _classificationHistory.add({
            'user': userPromptText,
            'ai': aiReplyText,
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn'
                  ? '整理完成！（分类: $category）'
                  : 'Organized! (Category: $category)',
            ),
          ),
        );
      }
    } catch (e) {
      print('[InboxDetailPage] 整理失败: $e');
      if (mounted) {
        // 从 DB 重新读取状态（可能部分更新成功）
        final freshItem = widget.item.id != null
            ? await DatabaseHelper().getInboxItemById(widget.item.id!)
            : null;
        if (freshItem != null) {
          setState(() {
            _currentStatus = freshItem.status;
            _currentFilePath = freshItem.filePath;
            _selectedCategory = freshItem.category;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' ? '整理失败: $e' : 'Organize failed: $e',
            ),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 手工分类并整理条目到指定栏目
  Future<void> _manualOrganizeToCategory(String newCategory) async {
    setState(() => _isProcessing = true);

    try {
      // 创建临时的 updated item，使用最新的 filePath
      final tempItem = widget.item.copyWith(
        category: newCategory,
        status: '处理中',
        filePath: _currentFilePath,
      );

      // 调用完整的处理流程（移动文件 + 解析内容 + 写入目标栏目数据库）
      await _inboxService.processAndClassifyItem(
        tempItem,
        useManualCategory: true,
      );

      if (mounted) {
        // 从 DB 重新读取最新状态
        final freshItem = widget.item.id != null
            ? await DatabaseHelper().getInboxItemById(widget.item.id!)
            : null;

        setState(() {
          _selectedCategory = newCategory;
          _currentStatus = freshItem?.status ?? '已处理';
          _currentFilePath = freshItem?.filePath ?? _currentFilePath;
          _currentTitle = freshItem?.title ?? _currentTitle;
        });

        // Re-fetch fresh data to ensure consistency
        widget.onUpdate();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn'
                  ? '手工分类完成！（分类: $newCategory）'
                  : 'Manual classification complete! (Category: $newCategory)',
            ),
          ),
        );
      }
    } catch (e) {
      print('[InboxDetailPage] 手工分类失败: $e');
      if (mounted) {
        // 从 DB 重新读取状态（可能部分更新成功）
        final freshItem = widget.item.id != null
            ? await DatabaseHelper().getInboxItemById(widget.item.id!)
            : null;
        if (freshItem != null) {
          setState(() {
            _currentStatus = freshItem.status;
            _currentFilePath = freshItem.filePath;
            _selectedCategory = freshItem.category;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn'
                  ? '手工分类失败: $e'
                  : 'Manual classification failed: $e',
            ),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _performClassification(
    String content, [
    String? newTitle,
  ]) async {
    // Deprecated: All classification goes through _organizeItem() -> _inboxService.classifyItem()
    await _organizeItem();
  }

  @override
  Widget build(BuildContext context) {
    // Current AI message shows either progress or last result
    String currentAiMessage;
    if (_isProcessing) {
      currentAiMessage = widget.lang == 'cn'
          ? '正在整理文档...'
          : 'Organizing document...';
    } else if (_classificationHistory.isNotEmpty) {
      final lastMsg = _classificationHistory.last;
      currentAiMessage = lastMsg['ai']!;
    } else {
      currentAiMessage = widget.lang == 'cn'
          ? '正在查看文档'
          : 'Viewing the document';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助理 - 查看文档'
                  : 'My AI Language Assistant - View Document',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'inbox',
              lastAiMessage: currentAiMessage,
              onPullDown: () {},
              historyMessages: _classificationHistory.isEmpty
                  ? null
                  : _classificationHistory,
            ),
            Expanded(
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
                                  _currentTitle,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                    _buildLabelValue(
                                      '状态',
                                      _currentStatus,
                                      Colors.green,
                                      _getStatusColor(_currentStatus),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: HtmlPreview(
                              filePath: _currentFilePath,
                              showAppBar: false,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            SubmenuTabs(
              tabs: widget.lang == 'cn'
                  ? ['返回', '整理', '删除']
                  : ['Back', 'Organize', 'Delete'],
              selectedTab: '',
              onTabSelected: (tab) async {
                if (tab == (widget.lang == 'cn' ? '返回' : 'Back')) {
                  Navigator.of(context).pop();
                } else if (tab == (widget.lang == 'cn' ? '整理' : 'Organize')) {
                  await _organizeItem();
                } else if (tab == (widget.lang == 'cn' ? '删除' : 'Delete')) {
                  await _deleteItem();
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

  Widget _buildEditableDropdown(
    String label,
    String value,
    Color labelColor,
    Color bgColor,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(opt, style: const TextStyle(fontSize: 12)),
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLabelValue(
    String label,
    String value,
    Color labelColor,
    Color bgColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
          ),
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
