import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/ai_reply_bar.dart';

final List<Map<String, dynamic>> _skillPrompts = [
  {
    'id': 'S1',
    'title': '搜集文章',
    'category': '外部',
    'description': '搜集指定作者的文章',
    'prompt': '请帮我搜集一篇老舍的《猫》全文。',
  },
  {
    'id': 'S2',
    'title': '错题识别',
    'category': '外部',
    'description': '将照片中的答卷识别成错题本格式',
    'prompt': '请帮我将这张答卷照片识别成错题本格式，包括题目、我的答案、正确答案和解析。',
  },
  {
    'id': 'S3',
    'title': '作文点评',
    'category': '外部',
    'description': '点评用户的习作',
    'prompt': '请帮我点评这篇作文，从内容、结构、语言三个方面给出详细的修改建议。',
  },
  {
    'id': 'S4',
    'title': '名篇赏析',
    'category': '外部',
    'description': '点评名家名篇',
    'prompt': '请帮我赏析朱自清的《春》，分析其写作手法和艺术特色。',
  },
  {
    'id': 'S5',
    'title': '练习题批改',
    'category': '内部',
    'description': '批改练习题',
    'prompt': '请帮我批改以下练习题，给出正确答案和详细解析。',
  },
  {
    'id': 'S6',
    'title': '知识点梳理',
    'category': '内部',
    'description': '梳理知识点',
    'prompt': '请帮我梳理一下小学语文五年级上册第三单元的知识点，包括生字词、重点句型和课文理解要点。',
  },
  {
    'id': 'S7',
    'title': '练习题生成',
    'category': '内部',
    'description': '根据知识点生成练习题',
    'prompt': '请根据以下知识点生成5道填空题、3道选择题和2道阅读理解题：',
  },
  {
    'id': 'S8',
    'title': '同义词辨析',
    'category': '内部',
    'description': '辨析同义词',
    'prompt': '请帮我辨析以下几组同义词的区别：美丽/漂亮、高兴/快乐、安静/宁静。',
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
    _loadSkills();
  }

  void _loadSkills() {
    setState(() {
      _displaySkills = List.from(_skillPrompts);
    });
  }

  void _copyToClipboard(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.lang == 'cn' ? '已复制到剪贴板' : 'Copied to clipboard')),
    );
  }

  Future<void> _handleTabSelected(String tab) async {
    if (tab == (widget.lang == 'cn' ? '筛选' : 'Filter')) {
      _showFilterDialog();
    } else if (tab == (widget.lang == 'cn' ? '新增' : 'Add')) {
      _showAddSkillDialog();
    } else if (tab == (widget.lang == 'cn' ? '技能树' : 'Skill Tree')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '技能树功能（待实现）' : 'Skill tree function (to be implemented)')),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '筛选技能' : 'Filter Skills'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(widget.lang == 'cn' ? '按分类筛选：' : 'Filter by category:'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _displaySkills = _skillPrompts.where((s) => s['category'] == '内部').toList();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('内部'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _displaySkills = _skillPrompts.where((s) => s['category'] == '外部').toList();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('外部'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _loadSkills();
                    Navigator.pop(context);
                  },
                  child: Text(widget.lang == 'cn' ? '全部' : 'All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSkillDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '新增技能' : 'Add Skill'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '技能名称' : 'Skill Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '描述' : 'Description',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.lang == 'cn' ? '提示语' : 'Prompt',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.lang == 'cn' ? '技能已添加' : 'Skill added')),
                );
              }
              Navigator.pop(context);
            },
            child: Text(widget.lang == 'cn' ? '确定' : 'OK'),
          ),
        ],
      ),
    );
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Row(
                        children: [
                          Text(
                            '${skill['id']} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(skill['title']),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(skill['category']),
                            backgroundColor: categoryColor,
                            labelStyle: const TextStyle(fontSize: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skill['description'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      skill['prompt'],
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _copyToClipboard(skill['prompt']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF651FFF),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(
                      widget.lang == 'cn' ? '复制' : 'Copy',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
