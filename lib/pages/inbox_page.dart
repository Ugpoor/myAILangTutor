import 'package:flutter/material.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import 'inbox_detail_page.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';
import '../database/db_helper.dart';

// Top-level key for main_screen.dart to trigger inbox refresh after clipboard save
final GlobalKey<InboxPageState> inboxPageKey = GlobalKey<InboxPageState>();

class InboxPage extends StatefulWidget {
  final String lang;
  final List<ChatMessage>? messages;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const InboxPage({
    super.key,
    this.lang = 'cn',
    this.messages,
    required this.onHomeTap,
    this.onPullDown,
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
  bool _showFilterDialog = false;
  bool _isProcessing = false;

  // Classification history for AIReplyBar display
  List<Map<String, String>> _classificationHistory = [];

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
  String? _selectedSource;
  String? _selectedCategory;
  String? _selectedStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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
    final filteredItems = await _inboxService.filterItems(
      keyword: _keywordController.text,
      source: _selectedSource,
      category: _selectedCategory,
      status: _selectedStatus,
      startDate: _filterStartDate,
      endDate: _filterEndDate,
    );
    setState(() {
      _items = filteredItems;
      _showFilterDialog = false;
    });
    Navigator.of(context).pop();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _keywordController.clear();
      _selectedSource = null;
      _selectedCategory = null;
      _selectedStatus = null;
      _filterStartDate = null;;
      _filterEndDate = null;
      _items = _allItems;
      _showFilterDialog = false;
    });
    Navigator.of(context).pop();
  }

  Widget _buildFilterDialog() {
    final sources = _allItems.map((item) => item.source).toSet().toList();
    final categories = ['知识点', '错题本', '习题集', '作品集', '无法分类', '未知归类'];
    final statuses = ['未处理', '已处理'];

    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '筛选' : 'Filter'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _keywordController,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '关键词' : 'Keywords',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSource,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '来源' : 'Source',
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(widget.lang == 'cn' ? '全部' : 'All'),
                  ),
                  ...sources.map((source) => DropdownMenuItem(
                        value: source,
                        child: Text(source),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSource = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '归类' : 'Category',
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(widget.lang == 'cn' ? '全部' : 'All'),
                  ),
                  ...categories.map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '状态' : 'Status',
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(widget.lang == 'cn' ? '全部' : 'All'),
                  ),
                  ...statuses.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _clearFilters,
          child: Text(widget.lang == 'cn' ? '重置' : 'Reset'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: Text(widget.lang == 'cn' ? '确定' : 'Apply'),
        ),
      ],
    );
  }

  /// Build dynamic tabs based on selection state
  List<String> _buildDynamicTabs() {
    final List<String> tabs = [];

    // Base action tabs always shown
    if (_isProcessing) {
      // Show placeholder while processing — user can't interact anyway
      tabs.add(''); // empty placeholder
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

    setState(() {
      _isProcessing = true;
          ? '开始整理 ${itemsToProcess.length} 个条目...'
          : 'Starting to organize ${itemsToProcess.length} items...';
    });

    await _inboxService.processItems(itemsToProcess, onProgress: (current, total, reasoning) {
      if (mounted) {
        setState(() {
              ? '[$current/$total] 正在处理：$reasoning'
              : '[$current/$total] Processing: $reasoning';
        });
      }
    });

    await loadItems();

    setState(() {
      _selectedItemKeys.clear();
      _isProcessing = false;
          ? '整理完成！'
          : 'Organization complete!';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '整理完成' : 'Organized successfully')),
      );
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
            AIReplyBar(
              lang: widget.lang,
              messages: widget.messages ?? [],
              onPullDown: widget.onPullDown ?? () {},
              historyMessages: _classificationHistory.isEmpty ? null : _classificationHistory,
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
                    _showFilterDialog = true;
                  });
                  showDialog(
                    context: context,
                    builder: (context) => _buildFilterDialog(),
                  );
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
            InputArea(
              lang: widget.lang,
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
