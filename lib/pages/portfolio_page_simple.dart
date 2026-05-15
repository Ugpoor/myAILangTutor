import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';

// Fake作品集数据
final List<Map<String, dynamic>> _fakePortfolioItems = [
  {
    'id': 'W1',
    'title': '我的第一篇作文',
    'isOriginal': true,
    'category': '写作',
    'contentPreview': '这是一篇关于春天的作文...',
  },
  {
    'id': 'W2',
    'title': '《红楼梦》赏析',
    'isOriginal': false,
    'category': '阅读',
    'contentPreview': '《红楼梦》是中国古典文学...',
  },
  {
    'id': 'W3',
    'title': '古诗《静夜思》赏析',
    'isOriginal': false,
    'category': '阅读',
    'contentPreview': '床前明月光，疑是地上霜...',
  },
  {
    'id': 'W4',
    'title': '我的日记',
    'isOriginal': true,
    'category': '写作',
    'contentPreview': '今天天气很好，我去了公园...',
  },
];

class PortfolioPageSimple extends StatefulWidget {
  final String lang;
  final String lastAiMessage;
  final VoidCallback onHomeTap;

  const PortfolioPageSimple({
    super.key,
    this.lang = 'cn',
    required this.lastAiMessage,
    required this.onHomeTap,
  });

  @override
  State<PortfolioPageSimple> createState() => _PortfolioPageSimpleState();
}

class _PortfolioPageSimpleState extends State<PortfolioPageSimple> {
  List<Map<String, dynamic>> _displayItems = [];
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
      _displayItems = List.from(_fakePortfolioItems);
    });
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '筛选功能（待实现）' : 'Filter function (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '原创' : 'Original')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '原创编辑功能（待实现）' : 'Original editor (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '练习' : 'Practice')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '练习生成功能（待实现）' : 'Practice generation (to be implemented)')),
      );
    } else if (tab == (widget.lang == 'cn' ? '评析' : 'Analyze')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? 'AI评析功能（待实现）' : 'AI analysis (to be implemented)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['筛选', '原创', '练习', '评析']
        : ['Filter', 'Original', 'Practice', 'Analyze'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-作品集' : 'My AI Language Tutor - Portfolio',
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
                child: _displayItems.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无作品' : 'No portfolio items'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _displayItems.length,
                        itemBuilder: (context, index) {
                          final item = _displayItems[index];
                          return _buildPortfolioItem(item);
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

  Widget _buildPortfolioItem(Map<String, dynamic> item) {
    final isSelected = _selectedIds.contains(item['id']);
    final isOriginal = item['isOriginal'] as bool;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.lang == 'cn' ? '查看作品' : 'View portfolio item'}: ${item['title']}')),
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
                      _selectedIds.add(item['id']);
                    } else {
                      _selectedIds.remove(item['id']);
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
                          '${item['id']} ${item['title']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isOriginal)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Chip(
                              label: Text(widget.lang == 'cn' ? '原创' : 'Original'),
                              backgroundColor: const Color(0xFFDDA0DD),
                              labelStyle: const TextStyle(fontSize: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['contentPreview'],
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(item['category']),
                          backgroundColor: const Color(0xFFDDA0DD),
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
