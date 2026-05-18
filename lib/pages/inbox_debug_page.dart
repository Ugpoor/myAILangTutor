import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../database/models/inbox_item.dart';
import '../services/inbox_service.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';

class InboxDebugPage extends StatefulWidget {
  final String lang;
  final VoidCallback onHomeTap;

  const InboxDebugPage({
    super.key,
    this.lang = 'cn',
    required this.onHomeTap,
  });

  @override
  State<InboxDebugPage> createState() => _InboxDebugPageState();
}

class _InboxDebugPageState extends State<InboxDebugPage> {
  final InboxService _inboxService = InboxService();
  List<InboxItem> _databaseItems = [];
  List<String> _localDirectories = [];
  bool _isLoading = true;
  String? _inboxDirPath;
  String? _debugLog;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbItems = await _inboxService.getAllInboxItems();
      final appDocDir = await getApplicationDocumentsDirectory();
      final inboxDir = Directory('${appDocDir.path}/inbox');
      _inboxDirPath = inboxDir.path;

      List<String> dirs = [];
      if (await inboxDir.exists()) {
        final entities = inboxDir.listSync();
        for (final entity in entities) {
          if (entity is Directory) {
            dirs.add(entity.path);
          }
        }
        dirs.sort();
      }

      setState(() {
        _databaseItems = dbItems;
        _localDirectories = dirs;
        _isLoading = false;
        _generateDebugLog();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugLog = '加载失败: $e';
      });
    }
  }

  void _generateDebugLog() {
    final buffer = StringBuffer();
    
    buffer.writeln('========== 收件箱调试日志 ==========');
    buffer.writeln('生成时间: ${DateTime.now().toLocal()}');
    buffer.writeln();
    
    buffer.writeln('【收件箱目录】');
    buffer.writeln('路径: $_inboxDirPath');
    buffer.writeln();
    
    buffer.writeln('【数据库记录】');
    buffer.writeln('总数: ${_databaseItems.length}');
    buffer.writeln();
    for (int i = 0; i < _databaseItems.length; i++) {
      final item = _databaseItems[i];
      buffer.writeln('--- 记录 ${i + 1} ---');
      buffer.writeln('ID: ${item.id}');
      buffer.writeln('标题: ${item.title}');
      buffer.writeln('来源: ${item.source}');
      buffer.writeln('分类: ${item.category}');
      buffer.writeln('状态: ${item.status}');
      buffer.writeln('URL: ${item.url}');
      buffer.writeln('文件路径: ${item.filePath}');
      buffer.writeln('创建时间: ${item.createdAt}');
      buffer.writeln();
    }
    
    buffer.writeln('【本地目录】');
    buffer.writeln('总数: ${_localDirectories.length}');
    buffer.writeln();
    for (int i = 0; i < _localDirectories.length; i++) {
      buffer.writeln('目录 ${i + 1}: ${_localDirectories[i]}');
      final dirName = _localDirectories[i].split('/').last;
      final htmlFile = File('${_localDirectories[i]}/index.html');
      buffer.writeln('  - HTML文件存在: ${htmlFile.existsSync()}');
      if (htmlFile.existsSync()) {
        try {
          final size = htmlFile.lengthSync();
          buffer.writeln('  - 文件大小: ${_formatSize(size)}');
        } catch (e) {
          buffer.writeln('  - 文件大小: 无法读取');
        }
      }
      buffer.writeln();
    }
    
    buffer.writeln('【匹配检查】');
    final dbPaths = _databaseItems
        .map((item) => item.filePath)
        .where((path) => path != null && path.isNotEmpty)
        .cast<String>()
        .toSet();
    final localPaths = _localDirectories.toSet();
    
    final missingLocal = dbPaths.difference(localPaths);
    final missingDb = localPaths.difference(dbPaths);
    
    buffer.writeln('数据库有但本地没有: ${missingLocal.length} 条');
    for (final path in missingLocal) {
      buffer.writeln('  - $path');
    }
    buffer.writeln();
    
    buffer.writeln('本地有但数据库没有: ${missingDb.length} 条');
    for (final path in missingDb) {
      buffer.writeln('  - $path');
    }
    buffer.writeln();
    
    buffer.writeln('完全匹配: ${dbPaths.intersection(localPaths).length} 条');
    
    setState(() {
      _debugLog = buffer.toString();
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _copyToClipboard() async {
    final log = _debugLog;
    if (log != null) {
      await Clipboard.setData(ClipboardData(text: log));
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '收件箱调试页面' : 'Inbox Debug Page',
            ),
            AIReplyBar(
              lang: widget.lang,
              lastAiMessage: widget.lang == 'cn' 
                  ? '显示详细调试信息，点击复制按钮复制日志' 
                  : 'Show detailed debug info, click copy button to copy log',
              onPullDown: () {},
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadDebugInfo,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.lang == 'cn' ? '调试日志' : 'Debug Log',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _copyToClipboard,
                                child: Text(_copied 
                                    ? (widget.lang == 'cn' ? '已复制!' : 'Copied!') 
                                    : (widget.lang == 'cn' ? '复制日志' : 'Copy Log')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _debugLog ?? '无法生成日志',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontFamily: 'Courier New',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            SubmenuTabs(
              tabs: widget.lang == 'cn' ? ['返回首页'] : ['Home'],
              selectedTab: widget.lang == 'cn' ? '返回首页' : 'Home',
              onTabSelected: (_) => widget.onHomeTap(),
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }
}