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
  String _lastAiMessage = '你好，我是你的语文学习助手！';
  String? _currentPage;
  final List<String> _pageHistory = [];

  final List<ChatMessage> _chatMessages = [];
  final LlmService _llmService = LlmService();
  final InboxService _inboxService = InboxService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _showClipboardDialog = false;
  String? _detectedClipboardContent;
  String _lastClipboardContent = '';

  @override
  void initState() {
    super.initState();
    print('[MainScreen] ========== initState 开始 ==========');
    WidgetsBinding.instance.addObserver(this);
    print('[MainScreen] 添加生命周期监听器');
    _initLlmService();
    print('[MainScreen] 初始化 LLM 服务');
    _checkClipboard();
    print('[MainScreen] initState 完成');
  }

  @override
  void dispose() {
    print('[MainScreen] ========== dispose 开始 ==========');
    WidgetsBinding.instance.removeObserver(this);
    print('[MainScreen] 移除生命周期监听器');
    super.dispose();
    print('[MainScreen] dispose 完成');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[MainScreen] ========== 生命周期状态变化 ==========');
    print('[MainScreen] 当前状态: $state');

    if (state == AppLifecycleState.resumed) {
      print('[MainScreen] 应用恢复前台，延迟检查剪贴板');
      // 延迟执行，避免阻塞主线程
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
      _lastAiMessage = welcomeMessage.text;
    });
  }

  Future<void> _checkClipboard() async {
    print('[Clipboard] ========== 开始检查剪贴板 ==========');

    try {
      print('[Clipboard] 读取剪贴板...');
      final clipboardData = await Clipboard.getData('text/plain');
      final clipboardText = clipboardData?.text ?? '';

      print('[Clipboard] 剪贴板文本长度: ${clipboardText.length}');

      // 检查是否为HTTP链接
      final urlRegExp = RegExp(r'https?://[^\s]+');
      final hasUrl = urlRegExp.hasMatch(clipboardText);
      print('[Clipboard] 是否包含URL: $hasUrl');

      // 只要包含HTTP链接就弹窗（每次都弹）
      if (clipboardText.isNotEmpty && hasUrl) {
        print('[Clipboard] ✅ 检测到HTTP链接，显示对话框');
        setState(() {
          _detectedClipboardContent = clipboardText;
        });
        // 使用 showDialog 确保在任何页面都能显示
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _detectedClipboardContent != null) {
            _showClipboardDialogAsDialog();
          }
        });
        print('[Clipboard] 对话框状态已设置');
      } else {
        print('[Clipboard] 不包含URL或内容为空');
      }
    } catch (e, stackTrace) {
      print('[Clipboard] ❌ 读取剪贴板出错');
      print('[Clipboard] 错误: $e');
      print('[Clipboard] 堆栈: $stackTrace');
    }
    print('[Clipboard] ========== 检查完成 ==========');
  }

  Future<void> _saveClipboardContent() async {
    print('[SaveClipboard] ========== 开始保存 ==========');
    if (_detectedClipboardContent == null ||
        _detectedClipboardContent!.isEmpty) {
      print('[SaveClipboard] 没有内容，直接返回');
      return;
    }

    try {
      print('[SaveClipboard] 关闭对话框');
      setState(() {
        _showClipboardDialog = false;
      });

      // 提取URL
      final urlRegExp = RegExp(r'https?://[^\s]+');
      final match = urlRegExp.firstMatch(_detectedClipboardContent!);
      final url = match?.group(0) ?? '';

      if (url.isEmpty) {
        // 如果没有URL，直接保存文本
        print('[SaveClipboard] 没有检测到URL，保存文本内容');
        await _inboxService.saveClipboardContent(_detectedClipboardContent!);
        _handleSaveComplete();
        return;
      }

      // 先创建一个处理中的条目
      print('[SaveClipboard] 创建处理中条目');
      final pendingItem = await _inboxService.createPendingClipboardItem(url);

      if (pendingItem != null) {
        _lastClipboardContent = _detectedClipboardContent!;
        setState(() {
          _detectedClipboardContent = null;
        });

        // 打开WebViewExtractor来加载和保存页面
        print('[SaveClipboard] 打开WebViewExtractor');
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WebViewExtractor(
                url: url,
                onContentExtracted: (result) async {
                  Navigator.of(context).pop();

                  if (result != null) {
                    print('[SaveClipboard] WebView提取成功，更新条目');
                    await _inboxService.updateClipboardItemWithContent(
                      pendingItem.id!,
                      result,
                    );
                  } else {
                    print('[SaveClipboard] WebView提取失败');
                    // 更新为失败状态
                    await _inboxService.updateItemStatus(
                      pendingItem.id!,
                      'error',
                    );
                  }

                  _handleSaveComplete();
                },
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('[SaveClipboard] ❌ 保存失败');
      print('[SaveClipboard] 错误: $e');
      print('[SaveClipboard] 堆栈: $stackTrace');

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
    print('[SaveClipboard] 保存完成');

    // 如果当前在收件箱页面，重新加载数据
    if (_currentPage == 'inbox') {
      print('[SaveClipboard] 当前在收件箱页面，触发刷新');
      _navigateToPage('inbox');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lang == 'cn' ? '内容已保存到收件箱' : 'Content saved to inbox'),
        ),
      );
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
      // 进入聊天模式前记录当前页面
      _pageHistory.add(_currentPage!);
    }

    setState(() {
      _isChatMode = !_isChatMode;
      if (_isChatMode) {
        _currentPage = null;
      } else if (_pageHistory.isNotEmpty) {
        // 从聊天模式退出，返回上一页
        _currentPage = _pageHistory.removeLast();
      }
    });
  }

  void _toggleLang() {
    setState(() {
      _lang = _lang == 'cn' ? 'en' : 'cn';
      _selectedTab = _lang == 'cn' ? '收件箱' : 'Inbox';

      if (_chatMessages.isNotEmpty) {
        _lastAiMessage = _chatMessages.last.isAI
            ? _chatMessages.last.text
            : (_lang == 'cn'
                  ? '你好，我是你的语文学习助手！'
                  : 'Hello, I\'m your English learning assistant!');
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
    // 保存当前页面（如果有）
    if (_currentPage != null) {
      _pageHistory.add(_currentPage!);
    }

    setState(() {
      _currentPage = pageName;
    });
  }

  void _goBack() {
    if (_pageHistory.isNotEmpty) {
      // 返回上一页
      setState(() {
        _currentPage = _pageHistory.removeLast();
      });
    } else {
      // 没有历史记录，返回首页
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
        _lastAiMessage = _chatMessages.last.text;
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
    print(
      '[MainScreen] build - currentPage: $_currentPage, showClipboardDialog: $_showClipboardDialog',
    );

    if (_currentPage != null) {
      if (_currentPage == 'inbox') {
        return InboxPage(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'knowledge') {
        return KnowledgePointPageSimple(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'error') {
        return ErrorRecordPageSimple(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'exercise') {
        return ExercisesPageSimple(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'portfolio') {
        return PortfolioPageSimple(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'skills') {
        return SkillsPageSimple(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
          onPullDown: _toggleChatMode,
        );
      } else if (_currentPage == 'efficiency') {
        return EfficiencyRecordPage(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
          onHomeTap: _goBack,
        );
      } else if (_currentPage == 'schedule') {
        return SchedulePage(
          lang: _lang,
          lastAiMessage: _lastAiMessage,
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
                  lastAiMessage: _lastAiMessage,
                  onAiMessageChanged: _updateLastAiMessage,
                  onMessageAdded: _addMessage,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
}
