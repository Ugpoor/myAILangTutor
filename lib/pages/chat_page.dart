import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/chat_bubble_list.dart';
import '../components/pull_up_control.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback onCollapse;
  final VoidCallback onHomeTap;
  final List<ChatMessage> messages;
  final String currentTopic;
  final ValueChanged<String> onTopicChanged;
  final String selectedTab;
  final Function(String) onTabSelected;
  final String lang;
  final Future<void> Function(ChatMessage) onSendMessage;
  final bool isLoading;

  const ChatPage({
    super.key,
    required this.onCollapse,
    required this.onHomeTap,
    required this.messages,
    required this.currentTopic,
    required this.onTopicChanged,
    required this.selectedTab,
    required this.onTabSelected,
    required this.lang,
    required this.onSendMessage,
    this.isLoading = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();

  // 所有可用主题
  late final List<Map<String, String>> _topics;

  @override
  void initState() {
    super.initState();
    _topics = [
      {'label': widget.lang == 'cn' ? '综合' : 'General', 'value': 'general'},
      {'label': widget.lang == 'cn' ? '收件箱' : 'Inbox', 'value': 'inbox'},
      {'label': widget.lang == 'cn' ? '首页' : 'Home', 'value': 'home'},
      {'label': widget.lang == 'cn' ? '知识点' : 'Knowledge', 'value': 'knowledge'},
      {'label': widget.lang == 'cn' ? '错误本' : 'Errors', 'value': 'error'},
      {'label': widget.lang == 'cn' ? '习题集' : 'Exercises', 'value': 'exercise'},
      {'label': widget.lang == 'cn' ? '作品集' : 'Portfolio', 'value': 'portfolio'},
      {'label': widget.lang == 'cn' ? '技能库' : 'Skills', 'value': 'skills'},
      {'label': widget.lang == 'cn' ? '效率记录' : 'Efficiency', 'value': 'efficiency'},
      {'label': widget.lang == 'cn' ? '日程安排' : 'Schedule', 'value': 'schedule'},
      {'label': widget.lang == 'cn' ? '知识大纲' : 'Outline', 'value': 'outline'},
      {'label': widget.lang == 'cn' ? '计时器' : 'Timer', 'value': 'timer'},
    ];
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final message = ChatMessage(sender: '用户', text: text, isAI: false, topic: widget.currentTopic);
      widget.onSendMessage(message);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> chatTabs = widget.lang == 'cn' ? ['筛选'] : ['Filter'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助理 - 聊天'
                  : 'My AI Language Assistant - Chat',
              lang: widget.lang,
            ),
            // ========== 主题下拉选择器 ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.topic, size: 18, color: Color(0xFFFF69B4)),
                    const SizedBox(width: 8),
                    Text(
                      widget.lang == 'cn' ? '当前主题:' : 'Current Topic:',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.currentTopic,
                          isExpanded: true,
                          items: _topics.map((topic) {
                            return DropdownMenuItem(
                              value: topic['value'],
                              child: Text(
                                topic['label']!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && value != widget.currentTopic) {
                              widget.onTopicChanged(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ChatBubbleList(messages: widget.messages, lang: widget.lang),
                  if (widget.isLoading)
                    const Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFFFF69B4),
                                strokeWidth: 2,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'AI正在思考...',
                                style: TextStyle(
                                  color: Color(0xFFFF69B4),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PullUpControl(onPullUp: widget.onCollapse),
            SubmenuTabs(
              tabs: chatTabs,
              selectedTab: widget.selectedTab == chatTabs[0]
                  ? widget.selectedTab
                  : chatTabs[0],
              onTabSelected: widget.onTabSelected,
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
            InputArea(
              lang: widget.lang,
              controller: _textController,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
