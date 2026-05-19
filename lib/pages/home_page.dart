import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/menu_grid.dart';
import '../components/efficiency_section.dart';
import '../components/input_area.dart';
import '../components/chat_bubble_list.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onExpandChat;
  final String selectedTab;
  final Function(String) onTabSelected;
  final String lang;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onHomeTap;
  final void Function(int)? onMenuItemTap;
  final VoidCallback? onEfficiencyTap;
  final VoidCallback? onScheduleTap;
  final VoidCallback? onPullDown;
  
  /// 统一的消息发送回调（委托给 MainScreen）
  final void Function(ChatMessage)? onSendMessage;

  const HomePage({
    super.key,
    required this.onExpandChat,
    required this.selectedTab,
    required this.onTabSelected,
    this.lang = 'cn',
    this.onAvatarTap,
    this.onHomeTap,
    this.onMenuItemTap,
    this.onEfficiencyTap,
    this.onScheduleTap,
    this.onPullDown,
    this.onSendMessage,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _textController = TextEditingController();

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || widget.onSendMessage == null) return;

    final userMessage = ChatMessage(
      sender: '用户',
      text: text,
      isAI: false,
      topic: 'home',
    );

    // 委托给 MainScreen 统一处理
    widget.onSendMessage!(userMessage);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理' : 'My AI Language Tutor',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'home',
              onPullDown: widget.onExpandChat,
              onAvatarTap: widget.onAvatarTap,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MenuGrid(
                      lang: widget.lang,
                      onItemTap: widget.onMenuItemTap,
                    ),
                    const SizedBox(height: 24),
                    EfficiencySection(
                      onEfficiencyTap: widget.onEfficiencyTap,
                      onScheduleTap: widget.onScheduleTap,
                    ),
                  ],
                ),
              ),
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
