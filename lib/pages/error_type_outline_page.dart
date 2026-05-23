import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import '../components/outline_editor.dart';
import '../database/db_helper.dart';
import '../database/models/error_type_outline.dart';
import '../services/config_importer.dart';
import 'main_screen.dart';

class ErrorTypeOutlinePage extends StatefulWidget {
  final String lang;

  const ErrorTypeOutlinePage({super.key, this.lang = 'cn'});

  @override
  State<ErrorTypeOutlinePage> createState() => _ErrorTypeOutlinePageState();
}

class _ErrorTypeOutlinePageState extends State<ErrorTypeOutlinePage> {
  List<OutlineNode> _nodes = [];
  bool _isLoading = true;
  final GlobalKey<OutlineEditorState> _outlineEditorKey =
      GlobalKey<OutlineEditorState>();

  void _goHome() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOutline();
  }

  Future<void> _loadOutline() async {
    try {
      // 先从配置文件同步到数据库（双向同步）
      await ConfigImporter().syncErrorTypeOutlinesFromConfig();

      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);
      final outlines = await dao.getAll(lang: widget.lang);

      _nodes = _convertToOutlineNodes(outlines);
    } catch (e) {
      print('[ErrorTypeOutlinePage] 加载错类大纲失败: $e');
      _nodes = _getDefaultNodes();
    }
    setState(() => _isLoading = false);
  }

  String? _getParentId(String id) {
    final parts = id.split('.');
    if (parts.length <= 1) {
      return null;
    }
    return parts.sublist(0, parts.length - 1).join('.');
  }

  List<OutlineNode> _convertToOutlineNodes(List<ErrorTypeOutline> outlines) {
    Map<String, OutlineNode> nodeMap = {};
    List<OutlineNode> roots = [];

    for (var outline in outlines) {
      nodeMap[outline.eid] = OutlineNode(
        id: outline.eid,
        parentId: _getParentId(outline.eid) ?? '',
        content: outline.content,
      );
    }

    for (var node in nodeMap.values) {
      if (node.parentId.isEmpty) {
        roots.add(node);
      } else if (nodeMap.containsKey(node.parentId)) {
        nodeMap[node.parentId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }

    roots.sort((a, b) => a.id.compareTo(b.id));
    for (var node in roots) {
      node.children.sort((a, b) => a.id.compareTo(b.id));
    }

    return roots;
  }

  List<OutlineNode> _getDefaultNodes() {
    return [
      OutlineNode(
        id: '1',
        content: '概念混淆',
        children: [
          OutlineNode(id: '1.1', parentId: '1', content: '近义词辨析错误'),
          OutlineNode(id: '1.2', parentId: '1', content: '形近字混淆'),
          OutlineNode(id: '1.3', parentId: '1', content: '概念理解偏差'),
        ],
      ),
      OutlineNode(
        id: '2',
        content: '审题不清',
        children: [
          OutlineNode(id: '2.1', parentId: '2', content: '关键词忽略'),
          OutlineNode(id: '2.2', parentId: '2', content: '会错题意'),
          OutlineNode(id: '2.3', parentId: '2', content: '条件遗漏'),
        ],
      ),
      OutlineNode(
        id: '3',
        content: '计算失误',
        children: [
          OutlineNode(id: '3.1', parentId: '3', content: '计算错误'),
          OutlineNode(id: '3.2', parentId: '3', content: '步骤跳失'),
        ],
      ),
      OutlineNode(
        id: '4',
        content: '知识遗漏',
        children: [
          OutlineNode(id: '4.1', parentId: '4', content: '知识点遗忘'),
          OutlineNode(id: '4.2', parentId: '4', content: '知识点混淆'),
        ],
      ),
      OutlineNode(
        id: '5',
        content: '推理错误',
        children: [
          OutlineNode(id: '5.1', parentId: '5', content: '逻辑错误'),
          OutlineNode(id: '5.2', parentId: '5', content: '归纳不当'),
        ],
      ),
      OutlineNode(
        id: '6',
        content: '表达错误',
        children: [
          OutlineNode(id: '6.1', parentId: '6', content: '语法错误'),
          OutlineNode(id: '6.2', parentId: '6', content: '用词不当'),
        ],
      ),
    ];
  }

  Future<void> _saveOutline(List<OutlineNode> nodes) async {
    try {
      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);

      await db.delete(
        'error_type_outlines',
        where: 'lang = ?',
        whereArgs: [widget.lang],
      );

      List<ErrorTypeOutline> outlines = [];
      _flattenNodes(nodes, outlines);

      for (var outline in outlines) {
        await dao.insert(outline);
      }

      await ConfigImporter().exportErrorTypeOutlinesToConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' ? '错类大纲已保存' : 'Error Type Outline saved',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      setState(() {
        _nodes = _deepCopyNodes(nodes);
      });
    } catch (e) {
      print('[ErrorTypeOutlinePage] 保存错类大纲失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lang == 'cn' ? '保存失败: $e' : 'Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<OutlineNode> _deepCopyNodes(List<OutlineNode> nodes) {
    return nodes
        .map(
          (node) => OutlineNode(
            id: node.id,
            parentId: node.parentId,
            content: node.content,
            children: _deepCopyNodes(node.children),
            isExpanded: node.isExpanded,
          ),
        )
        .toList();
  }

  void _flattenNodes(List<OutlineNode> nodes, List<ErrorTypeOutline> result) {
    for (var node in nodes) {
      result.add(
        ErrorTypeOutline(
          eid: node.id,
          content: node.content,
          lang: widget.lang,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _flattenNodes(node.children, result);
    }
  }

  void _cancel() {
    Navigator.of(context).pop(false);
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  Future<void> _showImportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.lang == 'cn' ? '导入错类大纲' : 'Import Error Type Outline',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lang == 'cn'
                  ? '从其他应用（如微信）转发CSV文件到本程序，文件将在收件箱中收到。'
                  : 'Forward CSV files from other apps (e.g., WeChat) to this app. Files will be received in the inbox.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _downloadTemplate();
              },
              child: Text(widget.lang == 'cn' ? '分享模板' : 'Share Template'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang == 'cn' ? '关闭' : 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      final String csvContent = widget.lang == 'cn'
          ? 'id,content\n1,概念混淆\n1.1,近义词辨析错误\n1.2,形近字混淆\n2,审题不清\n2.1,关键词忽略\n'
          : 'id,content\n1,Concept Confusion\n1.1,Synonym Error\n1.2,Character Confusion\n2,Misunderstanding\n2.1,Keyword Ignored\n';

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/error_type_outline_template.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent);

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                widget.lang == 'cn' ? '模板下载成功' : 'Template Downloaded',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lang == 'cn' ? '模板文件已保存到：' : 'Template saved to:',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    filePath,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.lang == 'cn' ? '你可以：' : 'You can:'),
                  const SizedBox(height: 4),
                  Text(
                    widget.lang == 'cn'
                        ? '• 复制上方路径到文件管理器打开'
                        : '• Copy the path above to open in file manager',
                  ),
                  Text(
                    widget.lang == 'cn'
                        ? '• 通过文件管理器分享模板文件'
                        : '• Share the template via file manager',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(widget.lang == 'cn' ? '确定' : 'OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('[ErrorTypeOutlinePage] 下载模板失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' ? '下载失败: $e' : 'Download failed: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addRootNode() {
    OutlineEditor.addRootNode(_outlineEditorKey);
  }

  String _generateNewId(String parentId) {
    if (parentId.isEmpty) {
      int maxNum = 0;
      for (var node in _nodes) {
        if (node.parentId.isEmpty) {
          final match = RegExp(r'^(\d+)$').firstMatch(node.id);
          if (match != null) {
            maxNum = max(maxNum, int.parse(match.group(1)!));
          }
        }
      }
      return '${maxNum + 1}';
    } else {
      List<OutlineNode> children = [];
      _findDirectChildren(parentId, _nodes, children);
      int maxNum = 0;
      for (var child in children) {
        final expectedId = '$parentId.';
        if (child.id.startsWith(expectedId)) {
          final suffix = child.id.substring(expectedId.length);
          if (int.tryParse(suffix) != null) {
            maxNum = max(maxNum, int.parse(suffix));
          }
        }
      }
      return '$parentId.${maxNum + 1}';
    }
  }

  void _findDirectChildren(
    String parentId,
    List<OutlineNode> nodes,
    List<OutlineNode> result,
  ) {
    for (var node in nodes) {
      if (node.parentId == parentId) {
        result.add(node);
      }
      _findDirectChildren(parentId, node.children, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.lang == 'cn'
        ? ['返回', '导入', '添加', '保存']
        : ['Back', 'Import', 'Add', 'Save'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助手-错类大纲'
                  : 'My AI Language Tutor - Error Type Outline',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'error_type',
              onPullDown: _goHome,
              onAvatarTap: _goHome,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlineEditor(
                          key: _outlineEditorKey,
                          title: widget.lang == 'cn'
                              ? '错类大纲'
                              : 'Error Type Outline',
                          lang: widget.lang,
                          initialNodes: _nodes,
                          onSave: _saveOutline,
                          onCancel: _cancel,
                          accentColor: Colors.orange,
                          icon: Icons.category,
                        ),
                      ),
                    ),
            ),
            SubmenuTabs(
              tabs: tabs,
              selectedTab: '',
              onTabSelected: (tab) {
                if (tab == (widget.lang == 'cn' ? '返回' : 'Back')) {
                  _goBack();
                } else if (tab == (widget.lang == 'cn' ? '导入' : 'Import')) {
                  _showImportDialog();
                } else if (tab == (widget.lang == 'cn' ? '添加' : 'Add')) {
                  _addRootNode();
                } else if (tab == (widget.lang == 'cn' ? '保存' : 'Save')) {
                  final editorNodes = OutlineEditor.getNodes(_outlineEditorKey);
                  _saveOutline(editorNodes);
                }
              },
              onHomeTap: _goHome,
              lang: widget.lang,
            ),
            InputArea(lang: widget.lang),
          ],
        ),
      ),
    );
  }
}
