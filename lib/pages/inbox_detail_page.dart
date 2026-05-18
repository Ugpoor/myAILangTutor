import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import '../services/llm_service.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/html_preview.dart';

class InboxDetailPage extends StatefulWidget {
  final InboxItem item;
  final String lang;
  final VoidCallback onUpdate;

  const InboxDetailPage({
    super.key,
    required this.item,
    this.lang = 'cn',
    required this.onUpdate,
  });

  @override
  State<InboxDetailPage> createState() => _InboxDetailPageState();
}

class _InboxDetailPageState extends State<InboxDetailPage> {
  final InboxService _inboxService = InboxService();
  bool _isProcessing = false;

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '确认删除' : 'Confirm Delete'),
        content: Text(widget.lang == 'cn'
            ? '确定要删除这条记录吗？这个操作无法撤销。'
            : 'Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.lang == 'cn' ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(widget.lang == 'cn' ? '删除' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await _inboxService.deleteInboxItem(widget.item.id!);
        if (mounted) {
          widget.onUpdate();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.lang == 'cn' ? '删除失败: $e' : 'Delete failed: $e')),
          );
        }
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _organizeItem() async {
    setState(() => _isProcessing = true);

    try {
      // 1. 读取HTML文件并提取h标签
      final htmlPath = '${widget.item.filePath}/index.html';
      final file = File(htmlPath);
      if (!await file.exists()) {
        throw Exception('HTML文件不存在');
      }

      final htmlContent = await file.readAsString(encoding: utf8);
      final extractedTitles = _extractHeadings(htmlContent);
      extractedTitles.add(widget.item.title);
      final uniqueTitles = extractedTitles.toSet().toList();

      // 2. 提取HTML文本内容
      final textContent = _extractTextFromHtml(htmlContent);

      if (uniqueTitles.length < 2) {
        // 如果没有足够的标题可选择，跳过标题优化
        await _performClassification(textContent);
        return;
      }

      // 3. 调用LLM选择最佳标题
      final titlePrompt = _buildTitlePrompt(uniqueTitles, textContent);
      final titleResponse = await LlmService().generateResponse(titlePrompt);

      String selectedTitle = widget.item.title;
      if (titleResponse['success'] == true) {
        final response = titleResponse['response'] as String;
        final selectedIndex = _parseNumberResponse(response);
        if (selectedIndex >= 1 && selectedIndex <= uniqueTitles.length) {
          selectedTitle = uniqueTitles[selectedIndex - 1];
        }
      }

      // 4. 调用LLM进行分类
      await _performClassification(textContent, selectedTitle);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.lang == 'cn' ? '整理失败: $e' : 'Organize failed: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  List<String> _extractHeadings(String html) {
    final List<String> headings = [];
    final regex = RegExp(r'<h([1-6])[^>]*>(.*?)</h[1-6]>', caseSensitive: false);
    
    for (final match in regex.allMatches(html)) {
      final text = match.group(2)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (text.isNotEmpty && text.length > 2) {
        headings.add(text);
      }
    }
    return headings;
  }

  String _extractTextFromHtml(String html) {
    // 移除脚本和样式
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // 限制长度
    if (text.length > 5000) {
      text = text.substring(0, 5000) + '...';
    }
    return text;
  }

  String _buildTitlePrompt(List<String> titles, String content) {
    final titlesList = titles.asMap().entries
        .map((entry) => '${entry.key + 1}、"${entry.value}"')
        .join('\n');

    return '''请选择最能反映以下内容的标题，只需回复序号（如：1、2、3等）。

内容摘要：
$content

可选标题：
$titlesList

请只回复序号。''';
  }

  int _parseNumberResponse(String response) {
    final match = RegExp(r'(\d+)').firstMatch(response);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  Future<void> _performClassification(String content, [String? newTitle]) async {
    // 分类提示语
    final categoryPrompt = '''请对以下内容进行分类，选择最合适的栏目标签，只需回复分类名称。

可选分类：知识点、错题本、习题、作品集、无法分类、未知归类

内容摘要：
$content

请只回复分类名称。''';

    final categoryResponse = await LlmService().generateResponse(categoryPrompt);
    String category = '未知归类';
    final validCategories = ['知识点', '错题本', '习题', '作品集', '无法分类', '未知归类'];

    if (categoryResponse['success'] == true) {
      final response = categoryResponse['response'] as String;
      for (final cat in validCategories) {
        if (response.contains(cat)) {
          category = cat;
          break;
        }
      }
    }

    // 更新条目
    final updatedItem = widget.item.copyWith(
      title: newTitle ?? widget.item.title,
      category: category,
      status: '已处理',
    );

    await _inboxService.updateInboxItem(updatedItem);

    if (mounted) {
      widget.onUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '整理完成！' : 'Organized successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '我的AI语言学习助理 - 查看文档' : 'My AI Language Assistant - View Document',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lang == 'cn' ? '正在查看文档' : 'Viewing the document',
              onPullDown: () {},
            ),
            Expanded(
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    _buildLabelValue('来源', widget.item.source, const Color(0xFFFF69B4), const Color(0xFFFFE4E9)),
                                    _buildLabelValue('分类', widget.item.category, Colors.blue, const Color(0xFF87CEEB)),
                                    _buildLabelValue('状态', widget.item.status, Colors.green, _getStatusColor(widget.item.status)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: HtmlPreview(filePath: widget.item.filePath, showAppBar: false),
                          ),
                        ),
                      ],
                    ),
            ),
            SubmenuTabs(
              tabs: widget.lang == 'cn' ? ['返回', '整理', '删除'] : ['Back', 'Organize', 'Delete'],
              selectedTab: widget.lang == 'cn' ? '返回' : 'Back',
              onTabSelected: (tab) async {
                if (tab == (widget.lang == 'cn' ? '返回' : 'Back')) {
                  Navigator.of(context).pop();
                } else if (tab == (widget.lang == 'cn' ? '整理' : 'Organize')) {
                  await _organizeItem();
                } else if (tab == (widget.lang == 'cn' ? '删除' : 'Delete')) {
                  await _deleteItem();
                }
              },
              onHomeTap: () => Navigator.of(context).pop(),
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelValue(String label, String value, Color labelColor, Color bgColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(3)),
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已处理':
      case '已整理':
        return const Color(0xFF90EE90);
      case '处理中':
        return const Color(0xFFFFA500);
      case 'error':
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFFFFE4E9);
    }
  }
}
