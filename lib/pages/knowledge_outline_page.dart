import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../components/app_title_bar.dart';
import '../components/ai_reply_bar.dart';
import '../components/submenu_tabs.dart';
import '../components/input_area.dart';
import '../components/outline_editor.dart';
import '../database/db_helper.dart';
import '../database/models/knowledge_outline.dart';
import '../services/config_importer.dart';
import 'main_screen.dart';

class KnowledgeOutlinePage extends StatefulWidget {
  final String lang;

  const KnowledgeOutlinePage({super.key, this.lang = 'cn'});

  @override
  State<KnowledgeOutlinePage> createState() => _KnowledgeOutlinePageState();
}

class _KnowledgeOutlinePageState extends State<KnowledgeOutlinePage> {
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
      await ConfigImporter().syncKnowledgeOutlinesFromConfig();

      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);
      final outlines = await dao.getAll(lang: widget.lang);

      _nodes = _convertToOutlineNodes(outlines);
    } catch (e) {
      print('[KnowledgeOutlinePage] 加载大纲失败: $e');
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

  List<OutlineNode> _convertToOutlineNodes(List<KnowledgeOutline> outlines) {
    Map<String, OutlineNode> nodeMap = {};
    List<OutlineNode> roots = [];

    for (var outline in outlines) {
      nodeMap[outline.cid] = OutlineNode(
        id: outline.cid,
        parentId: _getParentId(outline.cid) ?? '',
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
        content: '词汇',
        children: [
          OutlineNode(id: '1.1', parentId: '1', content: '近义词辨析'),
          OutlineNode(id: '1.2', parentId: '1', content: '反义词运用'),
          OutlineNode(id: '1.3', parentId: '1', content: '词的形式'),
        ],
      ),
      OutlineNode(
        id: '2',
        content: '写作手法',
        children: [
          OutlineNode(id: '2.1', parentId: '2', content: '借物喻人'),
          OutlineNode(id: '2.2', parentId: '2', content: '对比手法'),
          OutlineNode(id: '2.3', parentId: '2', content: '拟人手法'),
        ],
      ),
      OutlineNode(
        id: '3',
        content: '阅读理解',
        children: [
          OutlineNode(id: '3.1', parentId: '3', content: '主旨归纳'),
          OutlineNode(id: '3.2', parentId: '3', content: '推理判断'),
        ],
      ),
      OutlineNode(id: '4', content: '句法'),
      OutlineNode(id: '5', content: '文章'),
      OutlineNode(id: '6', content: '阅读'),
      OutlineNode(id: '7', content: '协作'),
      OutlineNode(id: '8', content: '聆听'),
      OutlineNode(id: '9', content: '口头'),
      OutlineNode(
        id: '10',
        content: '历史人物',
        children: [
          OutlineNode(id: '10.1', parentId: '10', content: '新文化时期的文学家'),
          OutlineNode(id: '10.2', parentId: '10', content: '古代文学名人'),
        ],
      ),
      OutlineNode(id: '11', content: '名胜古迹'),
      OutlineNode(id: '12', content: '思想'),
      OutlineNode(id: '13', content: '曲艺'),
    ];
  }

  Future<void> _saveOutline(List<OutlineNode> nodes) async {
    try {
      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);

      await db.delete(
        'knowledge_outlines',
        where: 'lang = ?',
        whereArgs: [widget.lang],
      );

      List<KnowledgeOutline> outlines = [];
      _flattenNodes(nodes, outlines);

      for (var outline in outlines) {
        await dao.insert(outline);
      }

      await ConfigImporter().exportKnowledgeOutlinesToConfig();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lang == 'cn' ? '大纲已保存' : 'Outline saved'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      setState(() {
        _nodes = _deepCopyNodes(nodes);
      });
    } catch (e) {
      print('[KnowledgeOutlinePage] 保存大纲失败: $e');
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

  void _flattenNodes(List<OutlineNode> nodes, List<KnowledgeOutline> result) {
    for (var node in nodes) {
      result.add(
        KnowledgeOutline(
          cid: node.id,
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
        title: Text(widget.lang == 'cn' ? '导入大纲' : 'Import Outline'),
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
          ? 'id,content\n1,词汇\n1.1,近义词辨析\n1.2,反义词运用\n2,写作手法\n2.1,借物喻人\n'
          : 'id,content\n1,Vocabulary\n1.1,Synonym Analysis\n1.2,Antonym Usage\n2,Writing Techniques\n2.1,Metaphor\n';

      Directory directory;
      try {
        // 优先使用外部存储的公共 Documents 目录（Android）
        directory = Directory('/storage/emulated/0/Documents');
        if (!await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        // 如果外部存储不可用，回退到应用私有目录
        directory = await getApplicationDocumentsDirectory();
      }
      final filePath = '${directory.path}/knowledge_outline_template.csv';
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
      print('[KnowledgeOutlinePage] 下载模板失败: $e');
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
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn'
                  ? '我的AI语言学习助手-知识大纲'
                  : 'My AI Language Tutor - Knowledge Outline',
            ),
            AIReplyBar(
              lang: widget.lang,
              topic: 'outline',
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
                              ? '知识点大纲'
                              : 'Knowledge Outline',
                          lang: widget.lang,
                          initialNodes: _nodes,
                          onSave: _saveOutline,
                          onCancel: _cancel,
                          accentColor: const Color(0xFFFF69B4),
                          icon: Icons.menu_book,
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
