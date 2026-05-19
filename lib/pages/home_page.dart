import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/menu_grid.dart';
import '../components/efficiency_section.dart';
import '../components/input_area.dart';
import '../services/llm_service.dart';
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
  /// 共享的对话消息列表（与 ChatPage 共用）
  final List<ChatMessage>? messages;
  final VoidCallback? onPullDown;

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
    this.messages,
    this.onPullDown,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _textController = TextEditingController();
  final LlmService _llmService = LlmService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _llmService.init();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userMessage = ChatMessage(
        sender: '用户',
        text: text,
        isAI: false,
      );
      widget.messages!.add(userMessage);

      final response = await _llmService.generateResponse(text);
      
      final aiMessage = ChatMessage(
        sender: 'AI',
        text: response['response'] ?? (widget.lang == 'cn' ? '收到你的消息！' : 'Received your message!'),
        reasoningText: response['reasoning'] ?? (widget.lang == 'cn' ? '这是AI推理内容。' : 'This is AI reasoning.'),
        isAI: true,
      );
      widget.messages!.add(aiMessage);

      _textController.clear();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
              messages: widget.messages ?? [],
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
