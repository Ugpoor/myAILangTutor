import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';

class TimerPage extends StatefulWidget {
  final String lang;
  final VoidCallback? onSaved;

  const TimerPage({
    super.key,
    this.lang = 'cn',
    this.onSaved,
  });

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  String _selectedAction = '';
  final TextEditingController _unitController = TextEditingController();
  List<String> _availableActions = [];

  @override
  void initState() {
    super.initState();
    _loadActions();
  }

  Future<void> _loadActions() async {
    final db = await DatabaseHelper().database;
    final records = await db.query('efficiency_records', columns: ['title']);
    final actions = records.map((r) => r['title'] as String).toSet().toList();

    if (mounted && actions.isNotEmpty) {
      setState(() {
        _availableActions = actions;
        _selectedAction = actions.first;
      });
    }
  }

  void _toggleTimer() {
    setState(() {
      if (_isRunning) {
        _timer?.cancel();
        _isRunning = false;
      } else {
        _isRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedSeconds++;
          });
        });
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isRunning = false;
    });
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _calculateEfficiency() {
    final units = int.tryParse(_unitController.text.trim()) ?? 0;
    if (units <= 0 || _elapsedSeconds <= 0) return 0.0;
    return _elapsedSeconds / units;
  }

  Future<void> _saveRecord() async {
    final action = _selectedAction.trim();
    if (action.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请选择计时动作' : 'Please select an action')),
      );
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      final unitCount = int.tryParse(_unitController.text.trim()) ?? 0;
      final efficiency = _calculateEfficiency();
      final now = DateTime.now().toString().substring(0, 19).replaceFirst(' ', 'T');

      final existing = await db.query(
        'efficiency_records',
        where: 'title = ?',
        whereArgs: [action],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await db.update(
          'efficiency_records',
          {
            'unit_count': unitCount,
            'unit_efficiency': efficiency,
            'record_time': now,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM efficiency_records');
        final count = Sqflite.firstIntValue(result) ?? 0;
        final recordId = 'R${count + 1}';
        await db.insert('efficiency_records', {
          'record_id': recordId,
          'title': action,
          'unit_count': unitCount,
          'unit_efficiency': efficiency,
          'record_time': now,
          'lang': widget.lang,
        });
      }

      widget.onSaved?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '记录已保存' : 'Record saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '保存失败' : 'Save failed')),
        );
      }
    }
  }

  void _onTabSelected(String tab) {
    if (tab == '保存') {
      _saveRecord();
    } else if (tab == '取消') {
      Navigator.pop(context);
    }
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
                  ? '我的AI语言学习助理-计时器'
                  : 'My AI Language Tutor - Timer',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: '',
              onPullDown: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lang == 'cn' ? '记录的动作：' : 'Action:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _availableActions.isNotEmpty ? _selectedAction : null,
                          isExpanded: true,
                          hint: Text(widget.lang == 'cn' ? '请选择动作' : 'Select action'),
                          items: _availableActions.map((action) {
                            return DropdownMenuItem(
                              value: action,
                              child: Text(action, style: const TextStyle(fontSize: 15)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedAction = v);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: Text(
                        _formatTime(_elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF651FFF),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _toggleTimer,
                            icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 28),
                            label: Text(
                              _isRunning
                                  ? (widget.lang == 'cn' ? '暂停' : 'Pause')
                                  : (widget.lang == 'cn' ? '开始' : 'Start'),
                              style: const TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_elapsedSeconds > 0)
                            ElevatedButton.icon(
                              onPressed: _resetTimer,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: Text(widget.lang == 'cn' ? '重置' : 'Reset'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '单位数：' : 'Units:',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _unitController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: widget.lang == 'cn' ? '输入数字' : 'Enter number',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '单位效率：' : 'Unit Eff:',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  '${_calculateEfficiency().toStringAsFixed(2)} s/unit',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: _onTabSelected,
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

  @override
  void dispose() {
    _timer?.cancel();
    _unitController.dispose();
    super.dispose();
  }
}
