import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';

// Fake习题集数据
final List<Map<String, dynamic>> _fakeExercises = [
  {
    'id': 'T1',
    'title': '四年级上第二单元测试',
    'lessonUnit': '2单元',
    'knowledgeTag': '句法',
    'progress': '未答题',
  },
  {
    'id': 'T2',
    'title': '专项知识点练习',
    'lessonUnit': '',
    'knowledgeTag': '生字读音',
    'progress': '未批阅',
  },
  {
    'id': 'T3',
    'title': '阅读理解专项训练',
    'lessonUnit': '3单元',
    'knowledgeTag': '阅读',
    'progress': '已批阅',
  },
  {
    'id': 'T4',
    'title': '作文练习',
    'lessonUnit': '4单元',
    'knowledgeTag': '写作',
    'progress': '已订正',
  },
];

class ExercisesPageSimple extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const ExercisesPageSimple({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<ExercisesPageSimple> createState() => _ExercisesPageSimpleState();
}

class _ExercisesPageSimpleState extends State<ExercisesPageSimple> {
  List<Map<String, dynamic>> _displayExercises = [];
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
      _displayExercises = List.from(_fakeExercises);
    });
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '筛选功能（待实现）' : 'Filter function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '批阅' : 'Grade')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '批阅功能（待实现）' : 'Grading function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '订正' : 'Correct')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '订正功能（待实现）' : 'Correction function (to be implemented)')),
      );
    }
  }

  Color _getProgressColor(String progress) {
    switch (progress) {
      case '未答题':
        return const Color(0xFFD3D3D3);
      case '未批阅':
        return const Color(0xFFFFE4E9);
      case '已批阅':
        return const Color(0xFFFFA07A);
      case '已订正':
        return const Color(0xFF90EE90);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn' ? ['筛选', '批阅', '订正'] : ['Filter', 'Grade', 'Correct'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-习题集' : 'My AI Language Tutor - Exercises',
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
                child: _displayExercises.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无习题' : 'No exercises'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = _displayExercises[index];
                          return _buildExerciseItem(exercise);
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

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    final isSelected = _selectedIds.contains(exercise['id']);
    final progressColor = _getProgressColor(exercise['progress']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.lang == 'cn' ? '查看习题' : 'View exercise'}: ${exercise['title']}')),
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
                      _selectedIds.add(exercise['id']);
                    } else {
                      _selectedIds.remove(exercise['id']);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${exercise['id']} ${exercise['title']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (exercise['lessonUnit'].toString().isNotEmpty)
                          Chip(
                            label: Text('课内: ${exercise['lessonUnit']}'),
                            backgroundColor: const Color(0xFFFFE4E9),
                            labelStyle: const TextStyle(fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        Chip(
                          label: Text(exercise['knowledgeTag']),
                          backgroundColor: const Color(0xFF87CEEB),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Chip(
                          label: Text(exercise['progress']),
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
