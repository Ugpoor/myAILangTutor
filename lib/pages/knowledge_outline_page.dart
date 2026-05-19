import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';

/// 知识点大纲页面 - 纯 YAML 预设文档，仅加载预览
/// 
/// 从知识点栏目通过 Navigator.push 进入，SubmenuTabs 任意点击均返回知识点栏目

class KnowledgeOutlinePage extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;

  const KnowledgeOutlinePage({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
  });

  @override
  State<KnowledgeOutlinePage> createState() => _KnowledgeOutlinePageState();
}

class _KnowledgeOutlinePageState extends State<KnowledgeOutlinePage> {
  late TextEditingController _outlineController;

  // 预设的 YAML 大纲内容
  static const String _defaultOutline = '''
- 1. 生字读音
  - 1.1. 拼音
  - 1.2. 独体字
  - 1.3. 偏旁部首
- 2. 构词
  - 2.1. 同义词
  - 2.2. 反义词
  - 2.3. 词的形式
- 3. 句法
- 4. 文章
- 5. 阅读
- 6. 协作
- 7. 聆听
- 8. 口头
- 9. 历史人物
  - 9.1. 新文化时期的文学家
  - 9.2. 古代文学名人
- 10. 名胜古迹
- 11. 思想
- 13. 曲艺
''';

  @override
  void initState() {
    super.initState();
    _outlineController = TextEditingController(text: _defaultOutline);
  }

  @override
  void dispose() {
    _outlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn' ? ['取消', '保存'] : ['Cancel', 'Save'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理-知识大纲' : 'My AI Language Tutor - Outline',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'outline',
              onPullDown: widget.onHomeTap,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 大纲头部标识
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book, size: 20, color: Color(0xFFFF69B4)),
                            const SizedBox(width: 8),
                            Text(
                              widget.lang == 'cn' ? '知识点大纲（可编辑）' : 'Knowledge Outline (Editable)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF69B4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _renderOutlineTree(_outlineController.text),
                    ],
                  ),
                ),
              ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: (tab) {
                if (tab == (widget.lang == 'cn' ? '取消' : 'Cancel')) {
                  // 放弃编辑，返回知识点栏目
                  Navigator.of(context).pop(false);
                } else if (tab == (widget.lang == 'cn' ? '保存' : 'Save')) {
                  // 保存大纲内容（目前仅提示）
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.lang == 'cn' ? '大纲已保存' : 'Outline saved'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  Navigator.of(context).pop(true);
                }
              },
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

  /// 将 YAML 大纲文本渲染为分层树形组件
  Widget _renderOutlineTree(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // 跳过空行
      if (line.trim().isEmpty) continue;

      // 计算缩进级别（每2个空格为一级）
      final trimmedLine = line.trimLeft();
      final indentSpaces = line.length - trimmedLine.length;
      final indentLevel = indentSpaces ~/ 2;
      
      // 跳过注释行
      if (trimmedLine.startsWith('#')) continue;

      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            left: indentLevel * 20.0,
            top: 4,
            bottom: 4,
            right: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF69B4),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  trimmedLine,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
