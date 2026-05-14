import 'package:flutter/material.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import 'inbox_detail_page.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';

class InboxPage extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;

  const InboxPage({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
  });

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final InboxService _inboxService = InboxService();
  List<InboxItem> _items = [];
  List<InboxItem> _allItems = [];
  final Set<int> _selectedItems = {};
  bool _isLoading = true;
  bool _showFilterDialog = false;
  bool _isProcessing = false;
  String _currentAiMessage = '';

  final TextEditingController _keywordController = TextEditingController();
  String? _selectedSource;
  String? _selectedCategory;
  String? _selectedStatus;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _currentAiMessage = widget.lastAiMessage;
    _loadItems();
    _loadTestData();
  }

  Future<void> _loadTestData() async {
    await _inboxService.addTestData();
    await _loadItems();
  }

  Future<void> _loadItems() async {
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
      case '习题':
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
      _filterStartDate = null;
      _filterEndDate = null;
      _items = _allItems;
      _showFilterDialog = false;
    });
    Navigator.of(context).pop();
  }

  Widget _buildFilterDialog() {
    final sources = _allItems.map((item) => item.source).toSet().toList();
    final categories = ['知识点', '错题本', '习题', '作品集', '未知归类'];
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

  Future<void> _processSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择条目' : 'Please select items first')),
      );
      return;
    }

    final itemsToProcess = _allItems.where((item) => _selectedItems.contains(item.id)).toList();
    
    setState(() {
      _isProcessing = true;
      _currentAiMessage = widget.lang == 'cn' 
          ? '开始整理 ${itemsToProcess.length} 个条目...' 
          : 'Starting to organize ${itemsToProcess.length} items...';
    });

    await _inboxService.processItems(itemsToProcess, onProgress: (current, total, reasoning) {
      if (mounted) {
        setState(() {
          _currentAiMessage = widget.lang == 'cn' 
              ? '[$current/$total] 正在处理：$reasoning' 
              : '[$current/$total] Processing: $reasoning';
        });
      }
    });

    await _loadItems();
    
    setState(() {
      _selectedItems.clear();
      _isProcessing = false;
      _currentAiMessage = widget.lang == 'cn' 
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
    if (_selectedItems.isEmpty) {
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
            ? '确定要归档选中的 ${_selectedItems.length} 条记录吗？' 
            : 'Are you sure you want to archive ${_selectedItems.length} selected items?'),
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
      final itemsToArchive = _allItems.where((item) => _selectedItems.contains(item.id)).toList();
      await _inboxService.archiveItems(itemsToArchive);
      await _loadItems();
      setState(() {
        _selectedItems.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '归档完成' : 'Archived successfully')),
        );
      }
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
              title: widget.lang == 'cn' ? '我的AI语言学习助理-收件箱' : 'My AI Language Assistant - Inbox',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: _currentAiMessage,
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
            ),
            SubmenuTabs(
              tabs: widget.lang == 'cn' ? ['筛选', '整理', '归档'] : ['Filter', 'Organize', 'Archive'],
              selectedTab: widget.lang == 'cn' ? '筛选' : 'Filter',
              onTabSelected: (tab) async {
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
                  return;
                }
                
                if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
                  setState(() {
                    _showFilterDialog = true;
                  });
                  showDialog(
                    context: context,
                    builder: (context) => _buildFilterDialog(),
                  );
                } else if (tab == (widget.lang == 'cn' ? '整理' : 'Organize')) {
                  await _processSelectedItems();
                } else if (tab == (widget.lang == 'cn' ? '归档' : 'Archive')) {
                  await _archiveSelectedItems();
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
    final isSelected = _selectedItems.contains(item.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InboxDetailPage(
                item: item,
                lang: widget.lang,
                onUpdate: _loadItems,
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
                      _selectedItems.add(item.id!);
                    } else {
                      _selectedItems.remove(item.id);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
