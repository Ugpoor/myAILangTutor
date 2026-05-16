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

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final message = ChatMessage(sender: '用户', text: text, isAI: false);
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
                  ? '我的AI语言学习助理-聊天'
                  : 'My AI Language Assistant - Chat',
              lang: widget.lang,
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
