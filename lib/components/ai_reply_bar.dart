import 'package:flutter/material.dart';
import 'chat_bubble_list.dart';

/// 统一的 AI 回复栏
/// 
/// 用途：显示在各模块页面（首页、知识点、错题本等）底部，展示 AI 对话状态。
/// 
/// 功能特性：
/// 1. 折叠模式：显示最近一条 AI 消息的摘要（70px 高度）
/// 2. 展开模式：显示完整对话历史列表（复用 ChatBubbleList 组件）
/// 3. 支持通过 onPullDown 切换到全屏聊天模式
/// 4. 兼容旧版本 lastAiMessage 参数（用于 inbox classification 等特殊场景）
class AIReplyBar extends StatefulWidget {
  final String lang;
  
  /// 共享的对话消息列表（与 ChatPage 共用同一份数据）
  final List<ChatMessage>? messages;
  
  /// 旧版参数：单条 AI 消息文本（当 messages 为空或未提供时使用）
  final String lastAiMessage;
  
  final VoidCallback onPullDown;
  final VoidCallback? onAvatarTap;
  
  // Optional: history messages for inbox classification conversations (deprecated, keep for backward compat)
  final List<Map<String, String>>? historyMessages;
  final void Function({required String user, required String ai})? onAddMessage;

  const AIReplyBar({
    super.key,
    this.lang = 'cn',
    this.messages,
    this.lastAiMessage = '',
    required this.onPullDown,
    this.onAvatarTap,
    this.historyMessages,
    this.onAddMessage,
  });

  @override
  State<AIReplyBar> createState() => _AIReplyBarState();
}

class _AIReplyBarState extends State<AIReplyBar> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 获取最新一条 AI 消息文本（用于折叠模式显示）
  String _getLatestAiSummary() {
    // 优先使用 messages 列表
    if (widget.messages != null && widget.messages!.isNotEmpty) {
      for (final msg in widget.messages!.reversed) {
        if (msg.isAI && msg.text.isNotEmpty) {
          return msg.text;
        }
      }
    }
    
    // 降级使用 lastAiMessage
    if (widget.lastAiMessage.isNotEmpty) {
      return widget.lastAiMessage;
    }
    
    // 默认欢迎语
    return widget.lang == 'cn' 
        ? '你好，我是你的语文学习助手！点击下拉进入对话模式' 
        : 'Hello! I am your language learning assistant! Pull down to start chatting.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E9),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(128, 128, 128, 0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ========== 展开模式：显示完整对话历史 ==========
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              if (!_expanded || widget.messages == null || widget.messages!.isEmpty) {
                return const SizedBox.shrink();
              }
              return SizeTransition(
                sizeFactor: _animation,
                axisAlignment: -1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: ChatBubbleList(
                      messages: widget.messages!,
                      lang: widget.lang,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // ========== 折叠模式：显示最新消息摘要 ==========
          if (_expanded == false) ...[
            Container(
              height: 70,
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF90EE90),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _getLatestAiSummary(),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onAvatarTap,
                    child: SizedBox(
                      width: 50,
                      height: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          widget.lang == 'cn'
                              ? 'assets/images/chinese_msg.png'
                              : 'assets/images/english_msg.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFFFE4E9),
                              child: const Icon(
                                Icons.chat_bubble,
                                color: Color(0xFFFF69B4),
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
          
          // ========== 切换按钮（折叠/展开）==========
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
                if (_expanded) {
                  _animationController.forward();
                } else {
                  _animationController.reverse();
                }
              });
            },
            child: Container(
              height: 28,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFFF69B4),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? (widget.lang == 'cn' ? '收起' : 'Collapse')
                          : (widget.lang == 'cn' ? '查看对话历史' : 'View History'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFFFF69B4)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ========== 下拉提示条（进入全屏聊天模式）==========
          GestureDetector(
            onTap: widget.onPullDown,
            child: Container(
              height: 28,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: const Center(
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFFF69B4),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
