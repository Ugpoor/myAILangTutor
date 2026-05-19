import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'chat_page.dart';
import 'inbox_page.dart';
import 'knowledge_point_page_simple.dart';
import 'error_record_page_simple.dart';
import 'exercises_page_simple.dart';
import 'portfolio_page_simple.dart';
import 'skills_page_simple.dart';
import 'efficiency_record_page.dart';
import 'schedule_page.dart';
import '../components/chat_bubble_list.dart';
import '../components/webview_extractor.dart';
import '../services/llm_service.dart';
import '../services/inbox_service.dart';
import '../database/models/inbox_item.dart';
import '../database/db_helper.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _isChatMode = false;
  String _selectedTab = '收件箱';
  String _lang = 'cn';
  bool _isLoading = false;
  String? _currentPage;
  final List<String> _pageHistory = [];

  final List<ChatMessage> _chatMessages = [];
  final LlmService _llmService = LlmService();
  final InboxService _inboxService = InboxService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _showClipboardDialog = false;
  String? _detectedClipboardContent;
  String _lastClipboardContent = '';
  
  final GlobalKey<InboxPageState> inboxPageKey = GlobalKey<InboxPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLlmService();
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _checkClipboard();
        }
      });
    }
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
    });
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final clipboardText = clipboardData?.text ?? '';

      final urlRegExp = RegExp(r'https?://[^\s]+');
      final hasUrl = urlRegExp.hasMatch(clipboardText);

      // 只在有新内容时才提示（避免重复提示）
      if (clipboardText.isNotEmpty &&
          hasUrl &&
          clipboardText != _lastClipboardContent) {
        setState(() {
          _detectedClipboardContent = clipboardText;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _detectedClipboardContent != null) {
            _showClipboardDialogAsDialog();
          }
        });
      }
    } catch (e, stackTrace) {
      print('[Clipboard] 读取剪贴板出错: $e');
    }
  }

  Future<void> _saveClipboardContent() async {
    if (_detectedClipboardContent == null ||
        _detectedClipboardContent!.isEmpty) {
      return;
    }

    try {
      setState(() {
        _showClipboardDialog = false;
      });

      final urlRegExp = RegExp(r'https?://[^\s]+');
      final match = urlRegExp.firstMatch(_detectedClipboardContent!);
      final url = match?.group(0) ?? '';

      if (url.isEmpty) {
        _handleSaveComplete();
        return;
      }

      final pendingItem = await _inboxService.createPendingClipboardItem(url);

      if (pendingItem != null) {
        _lastClipboardContent = _detectedClipboardContent!;
        setState(() {
          _detectedClipboardContent = null;
        });

        final itemId = pendingItem.id!;

        if (mounted) {
          final navigator = Navigator.of(context);
          navigator.push(
            MaterialPageRoute(
              builder: (ctx) => WebViewExtractor(
                url: url,
                targetDirectory: pendingItem.filePath,
                onContentExtracted: (result) async {
                  navigator.pop();

                  if (result != null) {
                    try {
                      await _inboxService.updateClipboardItemWithContent(
                        itemId,
                        result,
                      );
                    } catch (e) {
                      print('[SaveClipboard] 更新条目失败: $e');
                    }
                  } else {
                    await _inboxService.updateItemStatusWithCleanup(
                      itemId,
                      'error',
                    );
                  }

                  _handleSaveComplete();
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lang == 'cn' ? '创建条目失败' : 'Failed to create item'),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('[SaveClipboard] 保存失败: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_lang == 'cn' ? '保存失败' : 'Save failed'}: $e'),
          ),
        );
      }
    }
  }

  void _handleSaveComplete() {
    if (_currentPage == 'inbox') {
      // Refresh inbox data before navigating
      inboxPageKey.currentState?.loadItems();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lang == 'cn' ? '内容已保存到收件箱' : 'Content saved to inbox'),
        ),
      );
    }

    // 清空粘贴板避免重复提示
    try {
      Clipboard.setData(const ClipboardData(text: ''));
    } catch (e) {
      print('[Clipboard] 清空粘贴板失败: $e');
    }
  }

  void _showClipboardDialogAsDialog() {
    if (!mounted || _detectedClipboardContent == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _lang == 'cn' ? '检测到剪贴板新内容' : 'New Clipboard Content Detected',
          ),
          content: SingleChildScrollView(
            child: Container(
              width: 300,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _detectedClipboardContent ?? '',
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _detectedClipboardContent = null;
                });
              },
              child: Text(_lang == 'cn' ? '取消' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveClipboardContent();
              },
              child: Text(_lang == 'cn' ? '保存到收件箱' : 'Save to Inbox'),
            ),
          ],
        );
      },
    );
  }

  void _dismissClipboardDialog() {
    setState(() {
      _showClipboardDialog = false;
      _detectedClipboardContent = null;
    });
  }

  void _toggleChatMode() {
    if (!_isChatMode && _currentPage != null) {
      _pageHistory.add(_currentPage!);
    }

    setState(() {
      _isChatMode = !_isChatMode;
      if (_isChatMode) {
        _currentPage = null;
      } else if (_pageHistory.isNotEmpty) {
        _currentPage = _pageHistory.removeLast();
      }
    });
  }

  void _toggleLang() {
    setState(() {
      _lang = _lang == 'cn' ? 'en' : 'cn';
      _selectedTab = _lang == 'cn' ? '收件箱' : 'Inbox';
    });
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _navigateToPage(String pageName) {
    if (_currentPage != null) {
      _pageHistory.add(_currentPage!);
    }

    setState(() {
      _currentPage = pageName;
    });
  }

  void _goBack() {
    if (_pageHistory.isNotEmpty) {
      setState(() {
        _currentPage = _pageHistory.removeLast();
      });
    } else {
      setState(() {
        _currentPage = null;
      });
    }
  }

  Future<void> _sendMessage(ChatMessage message) async {
    setState(() {
      _chatMessages.add(message);
      _isLoading = true;
    });

    try {
      final response = await _llmService.generateResponse(message.text);

      setState(() {
        _chatMessages.add(
          ChatMessage(
            sender: 'AI',
            text:
                response['response'] ??
                (_lang == 'cn' ? '收到你的消息！' : 'Received your message!'),
            reasoningText:
                response['reasoning'] ??
                (_lang == 'cn' ? '这是AI推理内容。' : 'This is AI reasoning.'),
            isAI: true,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add(
          ChatMessage(
            sender: 'AI',
            text: _lang == 'cn'
                ? '抱歉，网络连接失败，请稍后重试。'
                : 'Sorry, network error. Please try again later.',
            reasoningText: _lang == 'cn'
                ? '网络请求失败。'
                : 'Network request failed.',
            isAI: true,
          ),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage != null) {
      if (_currentPage == 'inbox') {
        return InboxPage(
          key: inboxPageKey,
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'knowledge') {
        return KnowledgePointPageSimple(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'error') {
        return ErrorRecordPageSimple(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'exercise') {
        return ExercisesPageSimple(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'portfolio') {
        return PortfolioPageSimple(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'skills') {
        return SkillsPageSimple(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'efficiency') {
        return EfficiencyRecordPage(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
        );
      } else if (_currentPage == 'schedule') {
        return SchedulePage(
          lang: _lang,
          messages: _chatMessages,
          onHomeTap: _goBack,
        );
      }
    }

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
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
                        : [
                            'Inbox',
                            'Errors',
                            'Knowledge',
                            'Exercises',
                            'Portfolio',
                            'Skills',
                          ];

                    final pageMapping = {
                      0: 'inbox',
                      1: 'error',
                      2: 'knowledge',
                      3: 'exercise',
                      4: 'portfolio',
                      5: 'skills',
                    };

                    if (pageMapping.containsKey(index)) {
                      _navigateToPage(pageMapping[index]!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_lang == 'cn' ? '点击了' : 'Clicked'} ${menuLabels[index]}',
                          ),
                        ),
                      );
                    }
                  },
                  onEfficiencyTap: () => _navigateToPage('efficiency'),
                  onScheduleTap: () => _navigateToPage('schedule'),
                ),
        ),
        if (_showClipboardDialog) _buildClipboardDialog(),
      ],
    );
  }

  Widget _buildClipboardDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _lang == 'cn' ? '检测到剪贴板新内容' : 'New Clipboard Content Detected',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 300,
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _detectedClipboardContent ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismissClipboardDialog,
                    child: Text(_lang == 'cn' ? '取消' : 'Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveClipboardContent,
                    child: Text(_lang == 'cn' ? '保存到收件箱' : 'Save to Inbox'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
