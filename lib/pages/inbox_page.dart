import 'package:flutter/material.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import 'inbox_detail_page.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/chat_bubble_list.dart';
import '../database/db_helper.dart';
import '../services/llm_service.dart';
import '../components/generic_filter_dialog.dart';

// Top-level key for main_screen.dart to trigger inbox refresh after clipboard save
final GlobalKey<InboxPageState> inboxPageKey = GlobalKey<InboxPageState>();

class InboxPage extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;
  
  /// 统一的消息发送回调（委托给 MainScreen）
  final void Function(ChatMessage)? onSendMessage;

  const InboxPage({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
    this.onPullDown,
    this.onSendMessage,
  });

  @override
  State<InboxPage> createState() => InboxPageState();
}

class InboxPageState extends State<InboxPage> {
  final InboxService _inboxService = InboxService();
  List<InboxItem> _items = [];
  List<InboxItem> _allItems = [];
  final Set<String> _selectedItemKeys = {}; // 使用 filePath 作为唯一 key
  bool _isLoading = true;
  bool _isFilterDialogShowing = false;
  bool _isProcessing = false;

  // Classification history for AIReplyBar display
  List<Map<String, String>> _classificationHistory = [];
  
  /// Loading message for processing status
  String _loadingMessage = '';
  
  /// Text input controller for inbox chat at bottom
  final TextEditingController _inboxChatController = TextEditingController();
  
  @override
  void dispose() {
    _inboxChatController.dispose();
    super.dispose();
  }

  /// Handle chat message from inbox page (delegates to MainScreen)
  Future<void> _handleInboxChat(String text) async {
    if (text.isEmpty || widget.onSendMessage == null) return;

    final userMessage = ChatMessage(
      sender: '用户',
      text: text,
      isAI: false,
      topic: 'inbox',
    );

    // 委托给 MainScreen 统一处理
    widget.onSendMessage!(userMessage);
  }

  String _getItemKey(InboxItem item) {
    return item.filePath.isNotEmpty ? item.filePath : item.id.toString();
  }

  // 检查是否所有显示的条目都已选中
  bool get _isAllSelected {
    if (_items.isEmpty) return false;
    return _items.every((item) => _selectedItemKeys.contains(_getItemKey(item)));
  }

  // 检查是否有未选中的条目
  bool get _hasUnselectedItems {
    if (_items.isEmpty) return false;
    return _items.any((item) => !_selectedItemKeys.contains(_getItemKey(item)));
  }

  // 全选
  void _selectAll() {
    setState(() {
      for (final item in _items) {
        _selectedItemKeys.add(_getItemKey(item));
      }
    });
  }

  // 全不选
  void _deselectAll() {
    setState(() {
      _selectedItemKeys.clear();
    });
  }

  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _contentKeywordController = TextEditingController();
  
  Set<String> _filterSources = {};
  Set<String> _filterCategories = {};
  Set<String> _filterStatus = {};
  Set<String> _filterIsValid = {};
  MatchMode _filterSourceMatchMode = MatchMode.equals;
  MatchMode _filterCategoryMatchMode = MatchMode.equals;
  MatchMode _filterStatusMatchMode = MatchMode.equals;
  MatchMode _filterIsValidMatchMode = MatchMode.equals;

  @override
  void initState() {
    super.initState();
    loadItems();
    _loadTestData();
    _loadClassificationMessages();
  }

  /// Load AI classification messages from database for display in AIReplyBar
  Future<void> _loadClassificationMessages() async {
    try {
      final db = DatabaseHelper();
      final rawMessages = await db.getClassificationMessages();

      // Transform: group each message as a single AI reply (no user/AI pairing needed)
      final List<Map<String, String>> history = rawMessages.map((msg) {
        return {
          'user': '', // empty since these are auto-generated AI replies
          'ai': msg['content'] as String,
        };
      }).toList();

      setState(() {
        _classificationHistory = history.reversed.toList(); // show newest first
      });
    } catch (e) {
      print('[InboxPage] Failed to load classification messages: $e');
    }
  }

  Future<void> _loadTestData() async {
    await _inboxService.addTestData();
    await loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _inboxService.getAllInboxItems();
      setState(() {
        _allItems = items;
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '知识点':
        return const Color(0xFF87CEEB);
      case '错题本':
        return const Color(0xFFFFA07A);
      case '习题集':
        return const Color(0xFF98FB98);
      case '作品集':
        return const Color(0xFFDDA0DD);
      default:
        return Colors.grey;
    }
  }

  Future<void> _applyFilters() async {
    bool? isValid = _filterIsValid.contains('true') ? true : (_filterIsValid.contains('false') ? false : null);
    
    final filteredItems = await _inboxService.filterItems(
      keyword: _keywordController.text.isNotEmpty ? _keywordController.text : null,
      source: _filterSources.isNotEmpty ? _filterSources : null,
      category: _filterCategories.isNotEmpty ? _filterCategories : null,
      status: _filterStatus.isNotEmpty ? _filterStatus : null,
      isValid: isValid,
      contentKeyword: _contentKeywordController.text.isNotEmpty ? _contentKeywordController.text : null,
    );
    setState(() {
      _items = filteredItems;
    });
    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _keywordController.clear();
      _contentKeywordController.clear();
      _filterSources.clear();
      _filterCategories.clear();
      _filterStatus.clear();
      _filterIsValid.clear();
      _items = _allItems;
    });
    Navigator.of(context).pop();
  }

  void _showFilterDialog() async {
    final sources = _allItems.map((item) => item.source).toSet().toList();
    final categories = ['知识点', '错题本', '习题集', '作品集', '无法分类', '未知归类'];
    final statuses = ['未处理', '已处理'];
    final isValidOptions = ['true', 'false'];

    final config = FilterConfig(
      filterTypes: ['source', 'category', 'status', 'isValid'],
      typeConfigs: {
        'source': FilterTypeConfig(
          options: sources.map((s) => FilterOption(value: s, label: s)).toList(),
          initialValues: _filterSources,
          label: widget.lang == 'cn' ? '来源' : 'Source',
          hintText: widget.lang == 'cn' ? '输入来源...' : 'Enter source...',
          defaultMatchMode: MatchMode.equals,
        ),
        'category': FilterTypeConfig(
          options: categories.map((c) => FilterOption(value: c, label: c)).toList(),
          initialValues: _filterCategories,
          label: widget.lang == 'cn' ? '归类' : 'Category',
          hintText: widget.lang == 'cn' ? '输入归类...' : 'Enter category...',
          defaultMatchMode: MatchMode.equals,
        ),
        'status': FilterTypeConfig(
          options: statuses.map((s) => FilterOption(value: s, label: s)).toList(),
          initialValues: _filterStatus,
          label: widget.lang == 'cn' ? '状态' : 'Status',
          hintText: widget.lang == 'cn' ? '输入状态...' : 'Enter status...',
          defaultMatchMode: MatchMode.equals,
        ),
        'isValid': FilterTypeConfig(
          options: isValidOptions.map((v) => FilterOption(
            value: v, 
            label: v == 'true' ? (widget.lang == 'cn' ? '有效' : 'Valid') : (widget.lang == 'cn' ? '异常' : 'Invalid')
          )).toList(),
          initialValues: _filterIsValid,
          label: widget.lang == 'cn' ? '有效性' : 'Validity',
          hintText: widget.lang == 'cn' ? '选择有效性...' : 'Select validity...',
          defaultMatchMode: MatchMode.equals,
        ),
      },
    );

    final result = await GenericFilterDialog.show(context, config: config, lang: widget.lang);

    if (result != null) {
      setState(() {
        _filterSources = Set<String>.from((result['source'] as Map?)?['values'] ?? {});
        _filterCategories = Set<String>.from((result['category'] as Map?)?['values'] ?? {});
        _filterStatus = Set<String>.from((result['status'] as Map?)?['values'] ?? {});
        _filterIsValid = Set<String>.from((result['isValid'] as Map?)?['values'] ?? {});
        
        _filterSourceMatchMode = MatchMode.values[(result['source'] as Map?)?['matchMode'] as int? ?? 0];
        _filterCategoryMatchMode = MatchMode.values[(result['category'] as Map?)?['matchMode'] as int? ?? 0];
        _filterStatusMatchMode = MatchMode.values[(result['status'] as Map?)?['matchMode'] as int? ?? 0];
        _filterIsValidMatchMode = MatchMode.values[(result['isValid'] as Map?)?['matchMode'] as int? ?? 0];
      });
      await _applyFilters();
    }
  }

  /// Build dynamic tabs based on selection state
  List<String> _buildDynamicTabs() {
    final List<String> tabs = [];

    // Base action tabs always shown
    if (_isProcessing) {
      // Show processing indicator while processing
      tabs.add(widget.lang == 'cn' ? '收件箱整理中...' : 'Organizing...');
    } else {
      tabs.addAll([
        widget.lang == 'cn' ? '筛选' : 'Filter',
        widget.lang == 'cn' ? '整理' : 'Organize',
        widget.lang == 'cn' ? '归档' : 'Archive',
        widget.lang == 'cn' ? '删除' : 'Delete',
      ]);

      // Select/deselect tabs are dynamically shown based on selection state
      if (_hasUnselectedItems && _items.isNotEmpty) {
        // Has unselected items → show "Select All" only
        tabs.add(widget.lang == 'cn' ? '全选' : 'Select All');
      }
      if (_isAllSelected && _items.isNotEmpty) {
        // All selected → show "Deselect All" only
        tabs.add(widget.lang == 'cn' ? '全不选' : 'Deselect All');
      }
    }

    return tabs;
  }

  Future<void> _processSelectedItems() async {
    if (_selectedItemKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择条目' : 'Please select items first')),
      );
      return;
    }

    final itemsToProcess = _allItems.where((item) => _selectedItemKeys.contains(_getItemKey(item))).toList();

    // 过滤掉已处理的条目
    final alreadyProcessed = itemsToProcess.where((item) => item.status == '已处理' || item.status == '整理失败').toList();
    final pendingItems = itemsToProcess.where((item) => item.status != '已处理' && item.status != '整理失败').toList();

    if (alreadyProcessed.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lang == 'cn'
                ? '${alreadyProcessed.length} 个条目已处理，将跳过'
                : '${alreadyProcessed.length} items already processed, will skip'),
          ),
        );
      }
    }

    if (pendingItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '没有需要整理的条目' : 'No items to organize')),
        );
      }
      setState(() {
        _selectedItemKeys.clear();
      });
      return;
    }

    // 询问用户是使用AI自动分类还是手工分类
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '选择整理方式' : 'Choose Organization Method'),
        content: Text(widget.lang == 'cn'
            ? '请选择如何整理这些条目：'
            : 'Please choose how to organize these items:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('auto'),
            child: Text(widget.lang == 'cn' ? 'AI自动分类' : 'AI Auto Classification'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('manual'),
            child: Text(widget.lang == 'cn' ? '手工分类' : 'Manual Classification'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'auto') {
      // AI自动分类
      setState(() {
        _isProcessing = true;
        _loadingMessage = widget.lang == 'cn'
            ? '开始整理 ${pendingItems.length} 个条目...'
            : 'Starting to organize ${pendingItems.length} items...';
      });

      await _inboxService.processItems(pendingItems, onProgress: (current, total, reasoning) {
        if (mounted) {
          setState(() {
            _loadingMessage = widget.lang == 'cn'
                ? '[$current/$total] 正在处理：$reasoning'
                : '[$current/$total] Processing: $reasoning';
          });
        }
      });

      await loadItems();

      setState(() {
        _selectedItemKeys.clear();
        _isProcessing = false;
        _loadingMessage = widget.lang == 'cn' ? '整理完成！' : 'Organization complete!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '整理完成' : 'Organized successfully')),
        );
      }
    } else if (choice == 'manual') {
      // 手工分类
      final selectedCategory = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.lang == 'cn' ? '选择分类' : 'Select Category'),
          content: Text(widget.lang == 'cn'
              ? '请将这些条目分类到哪个栏目？'
              : 'Which section should these items be classified into?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('错题本'),
              child: const Text('错题本'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('习题集'),
              child: const Text('习题集'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('作品集'),
              child: const Text('作品集'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('知识点'),
              child: const Text('知识点'),
            ),
          ],
        ),
      );

      if (selectedCategory == null) return;

      // 执行批量手工分类
      setState(() {
        _isProcessing = true;
        _loadingMessage = widget.lang == 'cn'
            ? '正在将 ${pendingItems.length} 个条目分类到 $selectedCategory...'
            : 'Classifying ${pendingItems.length} items to $selectedCategory...';
      });

      try {
        // 逐个处理条目
        int successCount = 0;
        for (int i = 0; i < pendingItems.length; i++) {
          final item = pendingItems[i];
          try {
            final tempItem = item.copyWith(
              category: selectedCategory,
              status: '处理中',
            );
            await _inboxService.processAndClassifyItem(tempItem, useManualCategory: true);
            successCount++;
            
            // 更新进度
            if (mounted) {
              setState(() {
                _loadingMessage = widget.lang == 'cn'
                  ? '[${i+1}/${pendingItems.length}] 正在分类 $selectedCategory'
                  : '[${i+1}/${pendingItems.length}] Classifying to $selectedCategory';
              });
            }
          } catch (e) {
            print('Failed to process item ${item.title}: $e');
          }
        }

        await loadItems();

        setState(() {
          _selectedItemKeys.clear();
          _isProcessing = false;
          _loadingMessage = widget.lang == 'cn' ? '整理完成！' : 'Organization complete!';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.lang == 'cn'
                ? '手工分类完成！成功分类 $successCount/${pendingItems.length} 个条目到 $selectedCategory'
                : 'Manual classification complete! Successfully classified $successCount/${pendingItems.length} items to $selectedCategory')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.lang == 'cn' ? '分类失败: $e' : 'Classification failed: $e')),
          );
        }
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _archiveSelectedItems() async {
    if (_selectedItemKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择条目' : 'Please select items first')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认归档' : 'Confirm Archive'),
        content: Text(widget.lang == 'cn'
            ? '确定要归档选中的 ${_selectedItemKeys.length} 条记录吗？'
            : 'Are you sure you want to archive ${_selectedItemKeys.length} selected items?'),
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
      final itemsToArchive = _allItems.where((item) => _selectedItemKeys.contains(_getItemKey(item))).toList();
      await _inboxService.archiveItems(itemsToArchive);
      await loadItems();
      setState(() {
        _selectedItemKeys.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '归档完成' : 'Archived successfully')),
        );
      }
    }
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItemKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择条目' : 'Please select items first')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除选中的 ${_selectedItemKeys.length} 条记录吗？此操作不可恢复！'
            : 'Are you sure you want to delete ${_selectedItemKeys.length} selected items? This action cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(widget.lang == 'cn' ? '确定删除' : 'Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final itemsToDelete = _allItems.where((item) => _selectedItemKeys.contains(_getItemKey(item))).toList();
      for (final item in itemsToDelete) {
        await _inboxService.deleteItem(item);
      }
      await loadItems();
      setState(() {
        _selectedItemKeys.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '删除完成' : 'Deleted successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamicTabs = _buildDynamicTabs();

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-收件箱' : 'My AI Language Assistant - Inbox',
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  children: [
                    // 全选/全不选 buttons now integrated into SubmenuTabs dynamically
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _items.isEmpty
                              ? Center(
                                  child: Text(widget.lang == 'cn' ? '暂无消息' : 'No messages'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _items.length,
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return _buildInboxItem(item);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            SubmenuTabs(
              tabs: dynamicTabs,
              selectedTab: '',
              onTabSelected: (tab) async {
                if (tab.isEmpty || _isProcessing) {
                  if (_isProcessing) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(widget.lang == 'cn' ? '提示' : 'Notice'),
                        content: Text(widget.lang == 'cn' ? '当前正在整理中，请稍候完成后再试' : 'Currently organizing, please wait until completion'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(widget.lang == 'cn' ? '确定' : 'OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                final cnFilter = widget.lang == 'cn' ? '筛选' : 'Filter';
                final cnOrganize = widget.lang == 'cn' ? '整理' : 'Organize';
                final cnArchive = widget.lang == 'cn' ? '归档' : 'Archive';
                final cnDelete = widget.lang == 'cn' ? '删除' : 'Delete';
                final cnSelectAll = widget.lang == 'cn' ? '全选' : 'Select All';
                final cnDeselectAll = widget.lang == 'cn' ? '全不选' : 'Deselect All';

                if (tab == cnFilter) {
                  setState(() {
                    _isFilterDialogShowing = true;
                  });
                  _showFilterDialog();
                } else if (tab == cnOrganize) {
                  await _processSelectedItems();
                } else if (tab == cnArchive) {
                  await _archiveSelectedItems();
                } else if (tab == cnDelete) {
                  await _deleteSelectedItems();
                } else if (tab == cnSelectAll) {
                  _selectAll();
                } else if (tab == cnDeselectAll) {
                  _deselectAll();
                }
              },
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inboxChatController,
                      decoration: InputDecoration(
                        hintText: widget.lang == 'cn' ? '输入消息...' : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onSubmitted: _handleInboxChat,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleInboxChat(_inboxChatController.text.trim()),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B9D),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxItem(InboxItem item) {
    final itemKey = _getItemKey(item);
    final isSelected = _selectedItemKeys.contains(itemKey);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: item.isValid ? Colors.white : const Color(0xFFFFEBEB),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InboxDetailPage(
                item: item,
                lang: widget.lang,
                onUpdate: loadItems,
                onHomeTap: widget.onHomeTap,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedItemKeys.add(itemKey);
                    } else {
                      _selectedItemKeys.remove(itemKey);
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
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        if (!item.isValid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '异常',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(item.source),
                          backgroundColor: const Color(0xFFFFE4E9),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Chip(
                          label: Text(item.status),
                          backgroundColor: item.status == '已处理'
                              ? const Color(0xFF90EE90)
                              : const Color(0xFFD3D3D3),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        if (item.category != '未知归类')
                          Chip(
                            label: Text(item.category),
                            backgroundColor: _getCategoryColor(item.category),
                            labelStyle: const TextStyle(fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                      ],
                    ),
                    if (item.filePath.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '文件路径: ${item.filePath}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
