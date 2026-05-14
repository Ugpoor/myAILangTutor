import 'package:flutter/material.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import '../components/wysiwyg_editor.dart';

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
  bool _isLoading = false;
  String _currentContent = '';
  bool _hasRepairableState = false;
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
    _currentContent = widget.item.content;
    _selectedCategory = widget.item.category;
    _selectedStatus = widget.item.status;
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedItem = widget.item.copyWith(
        content: _currentContent,
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
          SnackBar(content: Text(widget.lang == 'cn' ? '保存失败' : 'Save failed')),
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
        content: Text(widget.lang == 'cn' ? '确定要删除这条记录吗？' : 'Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
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
            SnackBar(content: Text(widget.lang == 'cn' ? '删除失败' : 'Delete failed')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onEditorFocusChanged(bool isFocused) {
    setState(() {
      _isEditorFocused = isFocused;
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
              title: widget.lang == 'cn' ? '我的AI语言学习助理-收件箱条目编辑' : 'My AI Language Assistant - Inbox Item Edit',
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isEditorFocused ? 0 : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isEditorFocused ? 0 : 1,
                child: AIReplyBar(
                  lang: widget.lang,
                  lastAiMessage: widget.lang == 'cn' ? '你好，我来帮你编辑这条记录。' : 'Hello, I can help you edit this record.',
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
                          ? const Center(child: CircularProgressIndicator())
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
                                          fontSize: 16,
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
                                SizedBox(
                                  height: 400,
                                  child: WysiwygEditor(
                                    initialContent: widget.item.content,
                                    lang: widget.lang,
                                    onContentChanged: (content) {
                                      setState(() {
                                        _currentContent = content;
                                        _hasRepairableState = true;
                                      });
                                    },
                                    onFocusChanged: _onEditorFocusChanged,
                                  ),
                                ),
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
    super.dispose();
  }
}
