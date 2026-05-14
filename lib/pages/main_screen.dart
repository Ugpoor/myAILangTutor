import 'package:flutter/material.dart';
import 'home_page.dart';
import 'chat_page.dart';
import 'inbox_page.dart';
import '../components/chat_bubble_list.dart';
import '../services/llm_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isChatMode = false;
  String _selectedTab = '收件箱';
  String _lang = 'cn';
  bool _isLoading = false;
  String _lastAiMessage = '你好，我是你的语文学习助手！';
  String? _currentPage;

  final List<ChatMessage> _chatMessages = [];

  final LlmService _llmService = LlmService();

  @override
  void initState() {
    super.initState();
    _initLlmService();
  }

  Future<void> _initLlmService() async {
    await _llmService.init();
    
    final welcomeMessage = ChatMessage(
      sender: 'AI',
      text: _lang == 'cn' 
          ? '你好，我是你的语文学习助手，让我帮你进行语文学习规划。' 
          : 'Hello, I am your language learning assistant. Let me help you with your learning plan.',
      reasoningText: _lang == 'cn'
          ? '这是一个语言学习助手，需要先介绍自己然后了解用户需求。'
          : 'This is a language learning assistant. I need to introduce myself and understand user needs.',
      isAI: true,
    );
    
    setState(() {
      _chatMessages.add(welcomeMessage);
      _lastAiMessage = welcomeMessage.text;
    });
  }

  void _toggleChatMode() {
    setState(() {
      _isChatMode = !_isChatMode;
      _currentPage = null;
    });
  }

  void _toggleLang() {
    setState(() {
      _lang = _lang == 'cn' ? 'en' : 'cn';
      _selectedTab = _lang == 'cn' ? '收件箱' : 'Inbox';
      
      if (_chatMessages.isNotEmpty) {
        _lastAiMessage = _chatMessages.last.isAI 
            ? _chatMessages.last.text 
            : (_lang == 'cn' ? '你好，我是你的语文学习助手！' : 'Hello, I\'m your English learning assistant!');
      }
    });
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _updateLastAiMessage(String message) {
    setState(() {
      _lastAiMessage = message;
    });
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _chatMessages.add(message);
      if (message.isAI) {
        _lastAiMessage = message.text;
      }
    });
  }

  void _navigateToPage(String pageName) {
    setState(() {
      _currentPage = pageName;
    });
  }

  void _goBack() {
    setState(() {
      _currentPage = null;
    });
  }

  Future<void> _sendMessage(ChatMessage message) async {
    setState(() {
      _chatMessages.add(message);
      _isLoading = true;
    });

    try {
      final response = await _llmService.generateResponse(message.text);
      
      setState(() {
        _chatMessages.add(ChatMessage(
          sender: 'AI',
          text: response['response'] ?? (_lang == 'cn' ? '收到你的消息！' : 'Received your message!'),
          reasoningText: response['reasoning'] ?? (_lang == 'cn' ? '这是AI推理内容。' : 'This is AI reasoning.'),
          isAI: true,
        ));
        _lastAiMessage = _chatMessages.last.text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage(
          sender: 'AI',
          text: _lang == 'cn' ? '抱歉，网络连接失败，请稍后重试。' : 'Sorry, network error. Please try again later.',
          reasoningText: _lang == 'cn' ? '网络请求失败。' : 'Network request failed.',
          isAI: true,
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage != null) {
      if (_currentPage == 'inbox') {
        return InboxPage(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
        );
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _isChatMode
          ? ChatPage(
              key: const ValueKey('chat'),
              onCollapse: _toggleChatMode,
              onHomeTap: () {
                setState(() {
                  _isChatMode = false;
                });
              },
              messages: _chatMessages,
              selectedTab: _selectedTab,
              onTabSelected: _selectTab,
              lang: _lang,
              onSendMessage: _sendMessage,
              isLoading: _isLoading,
            )
          : HomePage(
              key: const ValueKey('home'),
              onExpandChat: _toggleChatMode,
              selectedTab: _selectedTab,
              onTabSelected: _selectTab,
              lang: _lang,
              onAvatarTap: _toggleLang,
              onHomeTap: () {
                setState(() {
                  _isChatMode = false;
                  _selectedTab = _lang == 'cn' ? '收件箱' : 'Inbox';
                });
              },
              onMenuItemTap: (index) {
                final menuLabels = _lang == 'cn'
                    ? ['收件箱', '错误本', '知识点', '习题集', '作品集', '技能库']
                    : ['Inbox', 'Errors', 'Knowledge', 'Exercises', 'Portfolio', 'Skills'];
                
                if (index == 0) {
                  _navigateToPage('inbox');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_lang == 'cn' ? '点击了' : 'Clicked'} ${menuLabels[index]}')),
                  );
                }
              },
              lastAiMessage: _lastAiMessage,
              onAiMessageChanged: _updateLastAiMessage,
              onMessageAdded: _addMessage,
            ),
    );
  }
}
