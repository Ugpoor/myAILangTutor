import 'package:flutter/material.dart';

/// 通用动态标签选择器 - 下拉选择+支持新增
/// 
/// Usage:
/// ```dart
/// DynamicTagSelector(
///   label: widget.lang == 'cn' ? '知识点标签' : 'Knowledge Tags',
///   currentTags: _filterKnowledgeTags, // Set<String> of selected
///   availableOptions: _allAvailableTags, // Set<String> of all options from data
///   onTagsChanged: (newTags) {
///     setState(() => _filterKnowledgeTags = newTags);
///   },
/// )
/// ```
class DynamicTagSelector extends StatefulWidget {
  final String label;
  final Set<String> currentTags;
  final Set<String> availableOptions;
  final Function(Set<String>) onTagsChanged;
  final Color? accentColor;

  const DynamicTagSelector({
    super.key,
    required this.label,
    required this.currentTags,
    required this.availableOptions,
    required this.onTagsChanged,
    this.accentColor = const Color(0xFFFF69B4),
  });

  @override
  State<DynamicTagSelector> createState() => _DynamicTagSelectorState();
}

class _DynamicTagSelectorState extends State<DynamicTagSelector> {
  final TextEditingController _newTagController = TextEditingController();

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _showAddNewTagDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.label),
        content: TextField(
          controller: _newTagController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.label,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              final newSet = Set<String>.from(widget.currentTags)..add(value.trim());
              widget.onTagsChanged(newSet);
              Navigator.pop(context);
              _newTagController.clear();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newTagController.clear();
            },
            child: Text(widget.label == '知识点标签' || widget.label == 'Knowledge Tags' 
                ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_newTagController.text.trim().isNotEmpty) {
                final newSet = Set<String>.from(widget.currentTags)..add(_newTagController.text.trim());
                widget.onTagsChanged(newSet);
                Navigator.pop(context);
                _newTagController.clear();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor),
            child: Text(widget.label == '知识点标签' || widget.label == 'Knowledge Tags' 
                ? '添加' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        // Display selected tags as chips with remove button
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: widget.currentTags.map((tag) {
            return Chip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                final newSet = Set<String>.from(widget.currentTags)..remove(tag);
                widget.onTagsChanged(newSet);
              },
              backgroundColor: widget.accentColor?.withOpacity(0.15) ?? Colors.grey.withOpacity(0.15),
              labelStyle: TextStyle(color: widget.accentColor),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        if (widget.currentTags.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                children: widget.availableOptions.where((opt) => !widget.currentTags.contains(opt)).map((opt) {
                  return ActionChip(
                    label: Text(opt, style: const TextStyle(fontSize: 11)),
                    avatar: const CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(0xFFE0E0E0),
                      child: Icon(Icons.add, size: 14, color: Colors.grey),
                    ),
                    onPressed: () {
                      final newSet = Set<String>.from(widget.currentTags)..add(opt);
                      widget.onTagsChanged(newSet);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        if (widget.availableOptions.length > 8) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAddNewTagDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加新标签', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ] else if (widget.availableOptions.isEmpty) ...[
          const SizedBox(height: 4),
          Text('暂无数据', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ],
    );
  }
}
