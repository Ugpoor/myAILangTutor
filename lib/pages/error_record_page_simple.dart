import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';

// Fake错误本数据
final List<Map<String, dynamic>> _fakeErrorRecords = [
  {
    'id': 'T013_2',
    'title': '审题错误',
    'lessonUnit': '1单元2课',
    'knowledgeTag': '5.阅读',
    'errorType': '3.审题',
    'exerciseTag': 'T013',
    'progress': '待订正',
    'mastered': false,
  },
  {
    'id': 'T014_1',
    'title': '概念混淆',
    'lessonUnit': '2单元1课',
    'knowledgeTag': '2.构词',
    'errorType': '1.概念',
    'exerciseTag': 'T014',
    'progress': '已订正',
    'mastered': true,
  },
  {
    'id': 'T015_3',
    'title': '计算错误',
    'lessonUnit': '3单元3课',
    'knowledgeTag': '1.生字读音',
    'errorType': '2.计算',
    'exerciseTag': 'T015',
    'progress': '待订正',
    'mastered': false,
  },
];

class ErrorRecordPageSimple extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const ErrorRecordPageSimple({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<ErrorRecordPageSimple> createState() => _ErrorRecordPageSimpleState();
}

class _ErrorRecordPageSimpleState extends State<ErrorRecordPageSimple> {
  List<Map<String, dynamic>> _displayRecords = [];
  final Set<String> _selectedIds = {};
  String _currentAiMessage = '';

  @override
  void initState() {
    super.initState();
    _currentAiMessage = widget.lastAiMessage;
    _loadFakeData();
  }

  void _loadFakeData() {
    setState(() {
      _displayRecords = List.from(_fakeErrorRecords);
    });
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '筛选功能（待实现）' : 'Filter function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '视图' : 'View')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '视图切换功能（待实现）' : 'View switch function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习功能（待实现）' : 'Practice function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '错类' : 'Error Type')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '错类大纲功能（待实现）' : 'Error type outline (to be implemented)')),
      );
    }
  }

  Color _getProgressColor(String progress) {
    switch (progress) {
      case '待订正':
        return const Color(0xFFFFA07A);
      case '已订正':
        return const Color(0xFF90EE90);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '视图', '练习', '错类']
        : ['Filter', 'View', 'Practice', 'Error Type'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-错误本' : 'My AI Language Tutor - Error Book',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: _currentAiMessage,
              onPullDown: widget.onPullDown ?? () {},
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _displayRecords.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无错误记录' : 'No error records'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayRecords.length,
                        itemBuilder: (context, index) {
                          final record = _displayRecords[index];
                          return _buildErrorRecordItem(record);
                        },
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: tabs[0],
              onTabSelected: _handleTabSelected,
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

  Widget _buildErrorRecordItem(Map<String, dynamic> record) {
    final isSelected = _selectedIds.contains(record['id']);
    final progressColor = _getProgressColor(record['progress']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.lang == 'cn' ? '查看错误记录' : 'View error record'}: ${record['title']}')),
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
                      _selectedIds.add(record['id']);
                    } else {
                      _selectedIds.remove(record['id']);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record['id']} ${record['title']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (record['lessonUnit'].toString().isNotEmpty)
                          Chip(
                            label: Text('课内: ${record['lessonUnit']}'),
                            backgroundColor: const Color(0xFFFFE4E9),
                            labelStyle: const TextStyle(fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        Chip(
                          label: Text(record['knowledgeTag']),
                          backgroundColor: const Color(0xFF87CEEB),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Chip(
                          label: Text(record['errorType']),
                          backgroundColor: const Color(0xFFFFA07A),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Chip(
                          label: Text(record['exerciseTag']),
                          backgroundColor: const Color(0xFF98FB98),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Chip(
                          label: Text(record['progress']),
                          backgroundColor: progressColor,
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
