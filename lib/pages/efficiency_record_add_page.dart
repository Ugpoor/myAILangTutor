import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';

class EfficiencyRecordAddPage extends StatefulWidget {
  final String lang;
  final VoidCallback? onSaved;

  const EfficiencyRecordAddPage({
    super.key,
    this.lang = 'cn',
    this.onSaved,
  });

  @override
  State<EfficiencyRecordAddPage> createState() => _EfficiencyRecordAddPageState();
}

class _EfficiencyRecordAddPageState extends State<EfficiencyRecordAddPage> {
  final TextEditingController _titleController = TextEditingController();
  String _selectedTab = '';
  bool _isSaving = false;

  Future<String> _getNextRecordId() async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM efficiency_records');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return 'R${count + 1}';
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请输入记录动作' : 'Please enter the action')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final recordId = await _getNextRecordId();
      final db = await DatabaseHelper().database;
      
      final now = DateTime.now().toString().substring(0, 19).replaceFirst(' ', 'T');
      
      print('Saving record: recordId=$recordId, title=$title, recordTime=$now');
      
      final insertResult = await db.insert('efficiency_records', {
        'record_id': recordId,
        'title': title,
        'unit_count': 0,
        'unit_efficiency': 0.0,
        'record_time': now,
        'lang': widget.lang,
      });
      
      print('Insert result: $insertResult');

      widget.onSaved?.call();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('Error saving record: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '保存失败: $e' : 'Save failed: $e')),
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
                  ? '我的AI语言学习助理-新增效率记录'
                  : 'My AI Language Tutor - Add Record',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: '',
              onPullDown: () {},
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lang == 'cn' ? '记录的动作：' : 'Action to record:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: widget.lang == 'cn' ? '例如：书写、阅读、背诵...' : 'e.g., Writing, Reading, Reciting...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      autofocus: true,
                      onSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: _selectedTab,
              onTabSelected: _onTabSelected,
              onHomeTap: () => Navigator.pop(context),
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
    _titleController.dispose();
    super.dispose();
  }
}
