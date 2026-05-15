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
    } else {
      setState(() {
        _selectedTab = tab;
      });
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

  List<Map<String, dynamic>> _filterSchedulesByDate(String date) {
    return _schedules.where((s) {
      final scheduleDate = s['date'] as String?;
      return scheduleDate == date;
    }).toList();
  }

  Widget _buildDayView() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final daySchedules = _filterSchedulesByDate(today);

    return _isLoading
        ? const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        : daySchedules.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    widget.lang == 'cn' ? '今日暂无日程' : 'No schedules for today',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: daySchedules.length,
                itemBuilder: (context, index) {
                  final schedule = daySchedules[index];
                  final id = schedule['id'] as int;
                  final isSelected = _selectedIds.contains(id);
                  final scheduleId = schedule['schedule_id'] as String? ?? 'C${index + 1}';
                  final title = schedule['title'] as String? ?? '';
                  final startTime = schedule['start_time'] as String? ?? '';
                  final endTime = schedule['end_time'] as String? ?? '';
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
                                    const Icon(Icons.access_time, color: Color(0xFF1565C0), size: 16),
                                    const SizedBox(width: 4),
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
              );
  }

  Widget _buildWeekView() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return _isLoading
        ? const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final daySchedules = _filterSchedulesByDate(dateStr);
              final isToday = dateStr == '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              final dayNames = widget.lang == 'cn' 
                  ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
                  : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isToday ? Colors.pink[50] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? Border.all(color: const Color(0xFFE91E63)) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isToday ? const Color(0xFFE91E63) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isToday ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dayNames[index],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (daySchedules.isEmpty)
                      Text(
                        widget.lang == 'cn' ? '无日程' : 'No schedule',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      )
                    else
                      Column(
                        children: daySchedules.map((schedule) {
                          final id = schedule['id'] as int;
                          final isSelected = _selectedIds.contains(id);
                          final title = schedule['title'] as String? ?? '';
                          final startTime = schedule['start_time'] as String? ?? '';
                          final completed = schedule['completed'] as int? ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Checkbox(
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
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        startTime.substring(0, 5),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            decoration: completed == 1 ? TextDecoration.lineThrough : null,
                                            color: completed == 1 ? Colors.grey : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            }),
          );
  }

  Widget _buildMonthView() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final firstDayOffset = monthStart.weekday - 1;
    final totalDays = monthEnd.day + firstDayOffset;
    final weeks = (totalDays / 7).ceil();

    final dayNames = widget.lang == 'cn' 
        ? ['日', '一', '二', '三', '四', '五', '六']
        : ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return _isLoading
        ? const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        : Column(
            children: [
              Row(
                children: dayNames.map((name) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              ...List.generate(weeks, (weekIndex) {
                return Row(
                  children: List.generate(7, (dayIndex) {
                    final dayOffset = weekIndex * 7 + dayIndex;
                    final calendarDay = dayOffset - firstDayOffset + 1;
                    final isCurrentMonth = calendarDay >= 1 && calendarDay <= monthEnd.day;
                    final isToday = isCurrentMonth && 
                        calendarDay == now.day &&
                        monthStart.month == now.month &&
                        monthStart.year == now.year;
                    
                    String? dateStr;
                    List<Map<String, dynamic>> daySchedules = [];
                    if (isCurrentMonth) {
                      dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${calendarDay.toString().padLeft(2, '0')}';
                      daySchedules = _filterSchedulesByDate(dateStr);
                    }

                    return Expanded(
                      child: Container(
                        height: 56,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isToday ? const Color(0xFFE91E63) : isCurrentMonth ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: daySchedules.isNotEmpty && isCurrentMonth 
                              ? Border.all(color: const Color(0xFFE91E63), width: 2) 
                              : null,
                        ),
                        child: isCurrentMonth
                            ? Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '$calendarDay',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          color: isToday ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (daySchedules.isNotEmpty)
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: isToday ? Colors.white.withOpacity(0.9) : const Color(0xFFFFCDD2),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${daySchedules.length}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isToday ? const Color(0xFFE91E63) : const Color(0xFFC2185B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    );
                  }),
                );
              }),
              const SizedBox(height: 16),
              Text(
                widget.lang == 'cn' ? '点击有日程的日期查看详情' : 'Tap dates with schedules to view details',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '日' : 'Day',
      widget.lang == 'cn' ? '周' : 'Week',
      widget.lang == 'cn' ? '月' : 'Month',
      widget.lang == 'cn' ? '新增' : 'Add',
      widget.lang == 'cn' ? '删除' : 'Delete',
    ];

    Widget viewContent;
    switch (_selectedTab) {
      case 'Day':
      case '日':
        viewContent = _buildDayView();
        break;
      case 'Week':
      case '周':
        viewContent = _buildWeekView();
        break;
      case 'Month':
      case '月':
        viewContent = _buildMonthView();
        break;
      default:
        viewContent = _buildDayView();
    }

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
                      child: viewContent,
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
