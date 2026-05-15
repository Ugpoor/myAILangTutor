import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';

class ScheduleAddPage extends StatefulWidget {
  final String lang;
  final String? lastAiMessage;
  final VoidCallback? onSaved;

  ScheduleAddPage({
    super.key,
    this.lang = 'cn',
    this.lastAiMessage,
    this.onSaved,
  });

  @override
  State<ScheduleAddPage> createState() => _ScheduleAddPageState();
}

class _ScheduleAddPageState extends State<ScheduleAddPage> {
  final _titleController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime _selectedDate = DateTime.now();
  String _repeatType = 'none';
  Set<int> _customDays = {};
  bool _isWeekdayMode = false;
  String _selectedTab = '';
  bool _isSaving = false;
  final dbHelper = DatabaseHelper();

  Future<String> _getNextScheduleId() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM schedule_items');
    final count = result.first['cnt'] as int? ?? 0;
    return 'C${count + 1}';
  }

  Future<void> _pickTime(bool isStart) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleCustomDay(int day) {
    setState(() {
      if (_customDays.contains(day)) {
        _customDays.remove(day);
      } else {
        _customDays.add(day);
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请输入标题' : 'Please enter title')),
      );
      return;
    }

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请选择起止时间' : 'Please select start and end time')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final scheduleId = await _getNextScheduleId();
      final startStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      final endStr = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      String? repeatDaysStr;
      if (_repeatType == 'custom') {
        if (_isWeekdayMode) {
          repeatDaysStr = 'weekday';
        } else if (_customDays.isNotEmpty) {
          final daysList = _customDays.toList()..sort();
          repeatDaysStr = daysList.join(',');
        }
      }

      await dbHelper.insert('schedule_items', {
        'schedule_id': scheduleId,
        'title': title,
        'start_time': startStr,
        'end_time': endStr,
        'date': dateStr,
        'repeat_type': _repeatType,
        'repeat_days': repeatDaysStr,
        'lang': widget.lang,
        'completed': 0,
      });

      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '保存失败' : 'Save failed')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _onTabSelected(String tab) {
    setState(() => _selectedTab = tab);
    if (tab == (widget.lang == 'cn' ? '保存' : 'Save')) {
      _save();
    } else if (tab == (widget.lang == 'cn' ? '取消' : 'Cancel')) {
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      widget.lang == 'cn' ? '取消' : 'Cancel',
      widget.lang == 'cn' ? '保存' : 'Save',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助理-新增日程安排'
                  : 'My AI Language Tutor - Add Schedule',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lastAiMessage ?? '',
              onPullDown: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lang == 'cn' ? '标题：' : 'Title:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: widget.lang == 'cn' ? '输入日程标题' : 'Enter schedule title',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      widget.lang == 'cn' ? '日期：' : 'Date:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '开始时间：' : 'Start:',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _pickTime(true),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _startTime != null
                                        ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                        : (widget.lang == 'cn' ? '选择时间' : 'Select time'),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '结束时间：' : 'End:',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _pickTime(false),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _endTime != null
                                        ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                        : (widget.lang == 'cn' ? '选择时间' : 'Select time'),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      widget.lang == 'cn' ? '是否重复：' : 'Repeat:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _buildRepeatChip('none', widget.lang == 'cn' ? '不重复' : 'None'),
                        _buildRepeatChip('daily', widget.lang == 'cn' ? '按日' : 'Daily'),
                        _buildRepeatChip('weekly', widget.lang == 'cn' ? '按周' : 'Weekly'),
                        _buildRepeatChip('monthly', widget.lang == 'cn' ? '按月' : 'Monthly'),
                        _buildRepeatChip('yearly', widget.lang == 'cn' ? '按年' : 'Yearly'),
                        _buildRepeatChip('custom', widget.lang == 'cn' ? '自定义' : 'Custom'),
                      ],
                    ),

                    if (_repeatType == 'custom') ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _isWeekdayMode = true;
                                _customDays.clear();
                              }),
                              child: Row(
                                children: [
                                  Radio<bool>(
                                    value: true,
                                    groupValue: _isWeekdayMode,
                                    onChanged: (v) => setState(() => _isWeekdayMode = v!),
                                    activeColor: const Color(0xFFC2185B),
                                  ),
                                  Text(widget.lang == 'cn' ? '工作日（周一至周五）' : 'Weekdays (Mon-Fri)'),
                                ],
                              ),
                            ),
                            const Divider(),
                            GestureDetector(
                              onTap: () => setState(() => _isWeekdayMode = false),
                              child: Row(
                                children: [
                                  Radio<bool>(
                                    value: false,
                                    groupValue: _isWeekdayMode,
                                    onChanged: (v) => setState(() => _isWeekdayMode = v!),
                                    activeColor: const Color(0xFFC2185B),
                                  ),
                                  Text(widget.lang == 'cn' ? '自定义选择：' : 'Custom select:'),
                                ],
                              ),
                            ),
                            if (!_isWeekdayMode) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (int i = 1; i <= 7; i++)
                                    _buildDayChip(i),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: _selectedTab,
              onTabSelected: _onTabSelected,
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

  Widget _buildRepeatChip(String type, String label) {
    final isSelected = _repeatType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFC2185B).withOpacity(0.3),
      onSelected: (_) => setState(() => _repeatType = type),
    );
  }

  Widget _buildDayChip(int day) {
    final dayNames = {
      1: widget.lang == 'cn' ? '周一' : 'Mon',
      2: widget.lang == 'cn' ? '周二' : 'Tue',
      3: widget.lang == 'cn' ? '周三' : 'Wed',
      4: widget.lang == 'cn' ? '周四' : 'Thu',
      5: widget.lang == 'cn' ? '周五' : 'Fri',
      6: widget.lang == 'cn' ? '周六' : 'Sat',
      7: widget.lang == 'cn' ? '周日' : 'Sun',
    };
    final isSelected = _customDays.contains(day);
    return FilterChip(
      label: Text(dayNames[day]!, style: const TextStyle(fontSize: 13)),
      selected: isSelected,
      selectedColor: const Color(0xFFC2185B).withOpacity(0.3),
      checkmarkColor: const Color(0xFFC2185B),
      onSelected: (_) => _toggleCustomDay(day),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}