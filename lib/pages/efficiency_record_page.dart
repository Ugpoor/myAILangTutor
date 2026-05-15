import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import 'timer_page.dart';
import 'efficiency_record_add_page.dart';

class EfficiencyRecordPage extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback? onHomeTap;

  const EfficiencyRecordPage({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    this.onHomeTap,
  });

  @override
  State<EfficiencyRecordPage> createState() => _EfficiencyRecordPageState();
}

class _EfficiencyRecordPageState extends State<EfficiencyRecordPage> {
  List<Map<String, dynamic>> _records = [];
  Set<int> _selectedIds = {};
  String _filterKeyword = '';
  String _selectedTab = '筛选';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final db = await DatabaseHelper().database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (_filterKeyword.isNotEmpty) {
      whereClause = 'title LIKE ? OR record_time LIKE ?';
      whereArgs = ['%$_filterKeyword%', '%$_filterKeyword%'];
    }

    final records = await db.query(
      'efficiency_records',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });

    if (tab == '新增') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EfficiencyRecordAddPage(
            lang: widget.lang,
            onSaved: _loadRecords,
          ),
        ),
      );
    } else if (tab == '计时器') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimerPage(
            lang: widget.lang,
            onSaved: _loadRecords,
          ),
        ),
      );
    } else if (tab == '删除') {
      _deleteSelected();
    } else if (tab == '筛选') {
      _showFilterDialog();
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final keywordController = TextEditingController(text: _filterKeyword);
        return AlertDialog(
          title: Text(widget.lang == 'cn' ? '筛选' : 'Filter'),
          content: TextField(
            controller: keywordController,
            decoration: InputDecoration(
              labelText: widget.lang == 'cn' ? '关键词' : 'Keyword',
              hintText: widget.lang == 'cn' ? '输入标题或日期搜索' : 'Search by title or date',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filterKeyword = keywordController.text.trim();
                });
                Navigator.pop(context);
                _loadRecords();
              },
              child: Text(widget.lang == 'cn' ? '确定' : 'OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除选中的 ${_selectedIds.length} 条记录吗？'
            : 'Delete ${_selectedIds.length} selected records?'),
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

    if (confirm == true) {
      final db = await DatabaseHelper().database;
      for (final id in _selectedIds) {
        await db.delete('efficiency_records', where: 'id = ?', whereArgs: [id]);
      }
      setState(() {
        _selectedIds.clear();
      });
      _loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '已删除' : 'Deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '筛选' : 'Filter',
      widget.lang == 'cn' ? '新增' : 'Add',
      widget.lang == 'cn' ? '计时器' : 'Timer',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助理-效率记录'
                  : 'My AI Language Tutor - Efficiency Records',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lastAiMessage,
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
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFE4E9),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        widget.lang == 'cn' ? '效率记录' : 'Efficiency Records',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _records.isEmpty
                              ? Center(
                                  child: Text(
                                    widget.lang == 'cn' ? '暂无记录，点击"新增"添加' : 'No records yet. Tap "Add" to create.',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) {
                                    final record = _records[index];
                                    final id = record['id'] as int;
                                    final isSelected = _selectedIds.contains(id);
                                    final recordId = record['record_id'] as String? ?? 'R${index + 1}';
                                    final title = record['title'] as String? ?? '';
                                    final unitEff = record['unit_efficiency'] as double? ?? 0;
                                    final recordTime = record['record_time'] as String? ?? '';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isSelected,
                                              activeColor: const Color(0xFF651FFF),
                                              onChanged: (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _selectedIds.add(id);
                                                  } else {
                                                    _selectedIds.remove(id);
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
                                                      Text(
                                                        '$recordId. ',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          title,
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${widget.lang == "cn" ? "单位效率" : "Unit Eff"}: ${unitEff.toStringAsFixed(1)}',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC2185B)),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    recordTime.isNotEmpty
                                                        ? recordTime
                                                        : (widget.lang == 'cn' ? '刚刚记录' : 'Just recorded'),
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: _selectedTab,
              onTabSelected: _onTabSelected,
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
            InputArea(
              lang: widget.lang,
              onTextChanged: (text) {},
            ),
          ],
        ),
      ),
    );
  }
}
