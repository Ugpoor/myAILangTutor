import 'package:flutter/material.dart';
import 'dart:math' show max;

class OutlineNode {
  String id;
  String parentId;
  String content;
  List<OutlineNode> children;
  bool isExpanded;

  OutlineNode({
    required this.id,
    this.parentId = '',
    required this.content,
    List<OutlineNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];

  Map<String, dynamic> toMap() {
    return {'id': id, 'parentId': parentId, 'content': content};
  }

  static OutlineNode fromMap(Map<String, dynamic> map) {
    return OutlineNode(
      id: map['id'] as String,
      parentId: map['parentId'] as String? ?? '',
      content: map['content'] as String,
    );
  }
}

class OutlineEditor extends StatefulWidget {
  final String title;
  final String lang;
  final List<OutlineNode> initialNodes;
  final ValueChanged<List<OutlineNode>> onSave;
  final VoidCallback onCancel;
  final Color accentColor;
  final IconData icon;

  const OutlineEditor({
    super.key,
    required this.title,
    required this.lang,
    required this.initialNodes,
    required this.onSave,
    required this.onCancel,
    this.accentColor = Colors.pink,
    this.icon = Icons.menu_book,
  });

  @override
  State<OutlineEditor> createState() => _OutlineEditorState();

  static void addRootNode(GlobalKey<OutlineEditorState>? key) {
    if (key?.currentState != null) {
      key!.currentState!._addRootNode();
    }
  }

  static List<OutlineNode> getNodes(GlobalKey<OutlineEditorState>? key) {
    if (key?.currentState != null) {
      return key!.currentState!._getNodes();
    }
    return [];
  }
}

abstract class OutlineEditorState extends State<OutlineEditor> {
  void _addRootNode();
  List<OutlineNode> _getNodes();
}

class _OutlineEditorState extends OutlineEditorState {
  late List<OutlineNode> _nodes;
  String? _focusedNodeId;
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _nodes = _deepCopyNodes(widget.initialNodes);
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

  void _addRootNode() {
    final newId = _generateNewId('');
    setState(() {
      _nodes.add(OutlineNode(id: newId, content: ''));
      _focusedNodeId = newId;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNodes[newId]?.requestFocus();
    });
  }

  List<OutlineNode> _getNodes() {
    return _nodes;
  }

  void _addChildNode(String parentId) {
    final newId = _generateNewId(parentId);
    setState(() {
      _addChildToNodes(parentId, newId, _nodes);
      _focusedNodeId = newId;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNodes[newId]?.requestFocus();
    });
  }

  void _addChildToNodes(
    String parentId,
    String newId,
    List<OutlineNode> nodes,
  ) {
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].id == parentId) {
        nodes[i].children.add(
          OutlineNode(id: newId, parentId: parentId, content: ''),
        );
        return;
      }
      _addChildToNodes(parentId, newId, nodes[i].children);
    }
  }

  void _deleteNode(String id) {
    setState(() {
      _deleteFromNodes(id, _nodes);
      _renumberNodes(_nodes, '');
    });
  }

  bool _deleteFromNodes(String id, List<OutlineNode> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].id == id) {
        nodes.removeAt(i);
        return true;
      }
      if (_deleteFromNodes(id, nodes[i].children)) {
        return true;
      }
    }
    return false;
  }

  void _renumberNodes(List<OutlineNode> nodes, String parentPrefix) {
    for (var i = 0; i < nodes.length; i++) {
      String newId = parentPrefix.isEmpty
          ? '${i + 1}'
          : '$parentPrefix.${i + 1}';
      String oldId = nodes[i].id;
      nodes[i].id = newId;

      if (oldId != newId && nodes[i].children.isNotEmpty) {
        _renumberNodes(nodes[i].children, newId);
      }
    }
  }

  void _updateNodeContent(String id, String content) {
    _updateContentInNodes(id, content, _nodes);
  }

  void _updateContentInNodes(
    String id,
    String content,
    List<OutlineNode> nodes,
  ) {
    for (var node in nodes) {
      if (node.id == id) {
        node.content = content;
        return;
      }
      _updateContentInNodes(id, content, node.children);
    }
  }

  void _toggleExpand(String id) {
    _toggleExpandInNodes(id, _nodes);
    setState(() {});
  }

  void _toggleExpandInNodes(String id, List<OutlineNode> nodes) {
    for (var node in nodes) {
      if (node.id == id) {
        node.isExpanded = !node.isExpanded;
        return;
      }
      _toggleExpandInNodes(id, node.children);
    }
  }

  Widget _buildNodeList(List<OutlineNode> nodes, int level) {
    return Column(
      children: nodes.map((node) => _buildNodeItem(node, level)).toList(),
    );
  }

  Widget _buildNodeItem(OutlineNode node, int level) {
    return Column(
      children: [
        Row(
          children: [
            if (node.children.isNotEmpty)
              IconButton(
                icon: Icon(
                  node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: widget.accentColor,
                ),
                onPressed: () => _toggleExpand(node.id),
                padding: EdgeInsets.zero,
              )
            else
              const SizedBox(width: 24),
            Text(
              '${node.id} ',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: TextField(
                focusNode: _focusNodes.putIfAbsent(node.id, () => FocusNode()),
                onChanged: (value) => _updateNodeContent(node.id, value),
                controller: TextEditingController(text: node.content)
                  ..selection = TextSelection.collapsed(
                    offset: node.content.length,
                  ),
                decoration: InputDecoration(
                  hintText: widget.lang == 'cn'
                      ? '输入内容...'
                      : 'Enter content...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: level == 0 ? FontWeight.bold : FontWeight.normal,
                  color: level == 0 ? widget.accentColor : Colors.black87,
                ),
              ),
            ),
            if (node.id.split('.').length < 3)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => _addChildNode(node.id),
                color: Colors.green,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _deleteNode(node.id),
              color: Colors.red,
            ),
          ],
        ),
        if (node.isExpanded && node.children.isNotEmpty)
          _buildNodeList(node.children, level + 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [_buildNodeList(_nodes, 0), const SizedBox(height: 8)],
          ),
        ),
      ],
    );
  }
}
