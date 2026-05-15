import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import 'schedule_add_page.dart';

class SchedulePage extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback? onHomeTap;

  SchedulePage({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    this.onHomeTap,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> _schedules = [];
  Set<int> _selectedIds = {};
  String _selectedTab = '';
  bool _isLoading = true;
  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.lang == 'cn' ? '日' : 'Day';
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final schedules = await dbHelper.getAllScheduleItems();
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _schedules = [];
      });
    }
  }

  void _onTabSelected(String tab) {
    // 检查是否是日、周、月标签
    final isDayView = tab == '日' || tab == 'Day';
    final isWeekView = tab == '周' || tab == 'Week';
    final isMonthView = tab == '月' || tab == 'Month';
    
    if (isDayView || isWeekView || isMonthView) {
      setState(() {
        _selectedTab = tab;
      });
      return;
    }

    final addLabel = widget.lang == 'cn' ? '新增' : 'Add';
    final deleteLabel = widget.lang == 'cn' ? '删除' : 'Delete';

    if (tab == addLabel) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleAddPage(
            lang: widget.lang,
            onSaved: _loadSchedules,
          ),
        ),
      );
    } else if (tab == deleteLabel) {
      _deleteSelected();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除选中的 ${_selectedIds.length} 条日程吗？'
            : 'Delete ${_selectedIds.length} selected schedules?'),
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
      try {
        for (final id in _selectedIds) {
          await dbHelper.delete(
            'schedule_items',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        setState(() => _selectedIds.clear());
        await _loadSchedules();
      } catch (e) {
        print('Error deleting schedules: $e');
      }
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final parts = date.split('-');
      if (parts.length >= 3) {
        return '${parts[1]}-${parts[2]}';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  List<Map<String, dynamic>> _filterSchedules() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    switch (_selectedTab) {
      case 'Day':
      case '日':
        return _schedules.where((s) {
          final date = s['date'] as String?;
          return date == today;
        }).toList();
      case 'Week':
      case '周':
        return _schedules.where((s) {
          final date = s['date'] as String?;
          if (date == null) return false;
          try {
            final d = DateTime.parse(date);
            return d.isAfter(weekStart.subtract(const Duration(days: 1))) && 
                   d.isBefore(weekEnd.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      case 'Month':
      case '月':
        return _schedules.where((s) {
          final date = s['date'] as String?;
          if (date == null) return false;
          try {
            final d = DateTime.parse(date);
            return d.isAfter(monthStart.subtract(const Duration(days: 1))) && 
                   d.isBefore(monthEnd.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      default:
        return _schedules;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _selectedTab,
      widget.lang == 'cn' ? '日' : 'Day',
      widget.lang == 'cn' ? '周' : 'Week',
      widget.lang == 'cn' ? '月' : 'Month',
      widget.lang == 'cn' ? '新增' : 'Add',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助理-日程安排'
                  : 'My AI Language Tutor - Schedule',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lastAiMessage,
              onPullDown: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      widget.lang == 'cn' ? '日程安排' : 'Schedule',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _filterSchedules().isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Center(
                                    child: Text(
                                      widget.lang == 'cn' ? '暂无日程，点击\"新增\"添加' : 'No schedules yet. Tap \"Add\" to create.',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _filterSchedules().length,
                                  itemBuilder: (context, index) {
                                    final schedule = _filterSchedules()[index];
                                    final id = schedule['id'] as int;
                                    final isSelected = _selectedIds.contains(id);
                                    final scheduleId = schedule['schedule_id'] as String? ?? 'C${index + 1}';
                                    final title = schedule['title'] as String? ?? '';
                                    final startTime = schedule['start_time'] as String? ?? '';
                                    final endTime = schedule['end_time'] as String? ?? '';
                                    final date = schedule['date'] as String?;
                                    final completed = schedule['completed'] as int? ?? 0;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Checkbox(
                                                value: isSelected,
                                                activeColor: const Color(0xFFC2185B),
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
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      if (date != null && date.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            _formatDate(date),
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.blue,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      if (date != null && date.isNotEmpty) const SizedBox(width: 8),
                                                      Text(
                                                        '$scheduleId. ',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          title,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w600,
                                                            decoration: completed == 1
                                                                ? TextDecoration.lineThrough
                                                                : null,
                                                            color: completed == 1
                                                                ? Colors.grey
                                                                : null,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '$startTime-$endTime',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(0xFF1565C0),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
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
            ),
          ],
        ),
      ),
    );
  }
}
