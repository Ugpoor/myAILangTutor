import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';

// Fake技能库数据
final List<Map<String, dynamic>> _fakeSkills = [
  {
    'id': 'S1',
    'title': '拼音识别',
    'category': '内部',
    'prerequisite': '',
  },
  {
    'id': 'S2',
    'title': '同义词辨析',
    'category': '内部',
    'prerequisite': 'S1',
  },
  {
    'id': 'S3',
    'title': '句子分析',
    'category': '外部',
    'prerequisite': 'S1',
  },
  {
    'id': 'S4',
    'title': '阅读理解',
    'category': '外部',
    'prerequisite': 'S2',
  },
  {
    'id': 'S5',
    'title': '作文评分',
    'category': '外部',
    'prerequisite': '',
  },
];

class SkillsPageSimple extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;

  const SkillsPageSimple({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
  });

  @override
  State<SkillsPageSimple> createState() => _SkillsPageSimpleState();
}

class _SkillsPageSimpleState extends State<SkillsPageSimple> {
  List<Map<String, dynamic>> _displaySkills = [];
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
      _displaySkills = List.from(_fakeSkills);
    });
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '筛选功能（待实现）' : 'Filter function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '新增' : 'Add')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '新增技能功能（待实现）' : 'Add skill function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '技能树' : 'Skill Tree')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '技能树功能（待实现）' : 'Skill tree function (to be implemented)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn' ? ['筛选', '新增', '技能树'] : ['Filter', 'Add', 'Skill Tree'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-技能库' : 'My AI Language Tutor - Skills',
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
                child: _displaySkills.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无技能' : 'No skills'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displaySkills.length,
                        itemBuilder: (context, index) {
                          final skill = _displaySkills[index];
                          return _buildSkillItem(skill);
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
          ],
        ),
      ),
    );
  }

  Widget _buildSkillItem(Map<String, dynamic> skill) {
    final isSelected = _selectedIds.contains(skill['id']);
    final categoryColor = skill['category'] == '内部' ? const Color(0xFF87CEEB) : const Color(0xFF98FB98);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.lang == 'cn' ? '查看技能' : 'View skill'}: ${skill['title']}')),
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
                      _selectedIds.add(skill['id']);
                    } else {
                      _selectedIds.remove(skill['id']);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${skill['id']} ${skill['title']}',
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
                          label: Text(skill['category']),
                          backgroundColor: categoryColor,
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        if (skill['prerequisite'].toString().isNotEmpty)
                          Chip(
                            label: Text('前置: ${skill['prerequisite']}'),
                            backgroundColor: const Color(0xFFFFE4E9),
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
