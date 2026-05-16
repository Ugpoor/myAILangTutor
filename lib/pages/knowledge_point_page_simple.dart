import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';
import '../components/input_area.dart';

//  fake知识点数据
final List<Map<String, dynamic>> _fakeKnowledgePoints = [
  {
    'id': 'K1',
    'title': '拼音基础知识',
    'category': '生字读音',
    'lessonUnit': '1单元',
    'mastered': false,
  },
  {
    'id': 'K2',
    'title': '同义词辨析',
    'category': '构词',
    'lessonUnit': '2单元',
    'mastered': true,
  },
  {
    'id': 'K3',
    'title': '句子成分分析',
    'category': '句法',
    'lessonUnit': '3单元',
    'mastered': false,
  },
  {
    'id': 'K4',
    'title': '阅读理解技巧',
    'category': '阅读',
    'lessonUnit': '4单元',
    'mastered': false,
  },
  {
    'id': 'K5',
    'title': '古代文学名人',
    'category': '历史人物',
    'lessonUnit': '',
    'mastered': true,
  },
];

class KnowledgePointPageSimple extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;
  final VoidCallback? onPullDown;

  const KnowledgePointPageSimple({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
    this.onPullDown,
  });

  @override
  State<KnowledgePointPageSimple> createState() => _KnowledgePointPageSimpleState();
}

class _KnowledgePointPageSimpleState extends State<KnowledgePointPageSimple> {
  List<Map<String, dynamic>> _displayPoints = [];
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
      _displayPoints = List.from(_fakeKnowledgePoints);
    });
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '筛选功能（待实现）' : 'Filter function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '知识谱' : 'Knowledge Spectrum')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '知识谱功能（待实现）' : 'Knowledge spectrum function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习功能（待实现）' : 'Practice function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '大纲' : 'Outline')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '大纲编辑功能（待实现）' : 'Outline editor (to be implemented)')),
      );
    }
  }

  Future<void> _toggleMastered(String id) async {
    setState(() {
      final index = _displayPoints.indexWhere((p) => p['id'] == id);
      if (index != -1) {
        _displayPoints[index]['mastered'] = !_displayPoints[index]['mastered'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '知识谱', '练习', '大纲']
        : ['Filter', 'Spectrum', 'Practice', 'Outline'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-知识点' : 'My AI Language Tutor - Knowledge',
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
                child: _displayPoints.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无知识点' : 'No knowledge points'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayPoints.length,
                        itemBuilder: (context, index) {
                          final point = _displayPoints[index];
                          return _buildKnowledgePointItem(point);
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

  Widget _buildKnowledgePointItem(Map<String, dynamic> point) {
    final isSelected = _selectedIds.contains(point['id']);
    final isMastered = point['mastered'] as bool;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.lang == 'cn' ? '查看知识点' : 'View knowledge point'}: ${point['title']}')),
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
                      _selectedIds.add(point['id']);
                    } else {
                      _selectedIds.remove(point['id']);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${point['id']} ${point['title']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (point['lessonUnit'].toString().isNotEmpty)
                          Chip(
                            label: Text('课内: ${point['lessonUnit']}'),
                            backgroundColor: const Color(0xFFFFE4E9),
                            labelStyle: const TextStyle(fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        Chip(
                          label: Text(point['category']),
                          backgroundColor: const Color(0xFF87CEEB),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Chip(
                          label: Text(isMastered ? (widget.lang == 'cn' ? '已掌握' : 'Mastered') : (widget.lang == 'cn' ? '未掌握' : 'Not Mastered')),
                          backgroundColor: isMastered ? const Color(0xFF90EE90) : const Color(0xFFD3D3D3),
                          labelStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isMastered ? Icons.check_circle : Icons.circle_outlined,
                  color: isMastered ? Colors.green : Colors.grey,
                ),
                onPressed: () => _toggleMastered(point['id']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
