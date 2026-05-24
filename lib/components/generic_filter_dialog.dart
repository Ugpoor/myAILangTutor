import 'package:flutter/material.dart';

enum MatchMode {
  hierarchical,    // 下包含关系（点ID系统）
  contains,        // 全包含关系
  equals,          // 严格等于关系
  greaterThan,     // 大于
  lessThan,        // 小于
  greaterOrEqual,  // 大于等于
  lessOrEqual,     // 小于等于
}

class FilterOption {
  final String value;
  final String label;

  FilterOption({required this.value, required this.label});
}

class FilterTypeConfig {
  final List<FilterOption> options;
  final Set<String> initialValues;
  final String label;
  final String hintText;
  final MatchMode defaultMatchMode;
  final bool isNumeric;

  FilterTypeConfig({
    required this.options,
    required this.initialValues,
    required this.label,
    required this.hintText,
    this.defaultMatchMode = MatchMode.contains,
    this.isNumeric = false,
  });
}

class FilterConfig {
  final List<String> filterTypes;
  final Map<String, FilterTypeConfig> typeConfigs;

  FilterConfig({
    required this.filterTypes,
    required this.typeConfigs,
  });
}

class GenericFilterDialog extends StatefulWidget {
  final FilterConfig config;
  final String lang;

  const GenericFilterDialog({
    super.key,
    required this.config,
    this.lang = 'cn',
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required FilterConfig config,
    String lang = 'cn',
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => GenericFilterDialog(
        config: config,
        lang: lang,
      ),
    );
  }

  @override
  State<GenericFilterDialog> createState() => _GenericFilterDialogState();
}

class _GenericFilterDialogState extends State<GenericFilterDialog> {
  late Map<String, Set<String>> selectedValues;
  late Map<String, MatchMode> selectedMatchModes;
  String? selectedFilterType;
  String searchKeyword = '';

  @override
  void initState() {
    super.initState();
    selectedValues = {};
    selectedMatchModes = {};
    widget.config.filterTypes.forEach((type) {
      final config = widget.config.typeConfigs[type];
      if (config != null) {
        selectedValues[type] = Set<String>.from(config.initialValues);
        selectedMatchModes[type] = config.defaultMatchMode;
      }
    });
  }

  String getHintText() {
    if (selectedFilterType == null) {
      return widget.lang == 'cn' ? '请先选择筛选类型' : 'Please select filter type first';
    }
    final config = widget.config.typeConfigs[selectedFilterType!];
    return config?.hintText ?? '';
  }

  List<String> getSuggestions() {
    if (searchKeyword.isEmpty || selectedFilterType == null) return [];
    final config = widget.config.typeConfigs[selectedFilterType!];
    if (config == null) return [];
    
    return config.options
        .where((o) => o.value.contains(searchKeyword) || o.label.contains(searchKeyword))
        .map((o) => o.value)
        .take(3)
        .toList();
  }

  void addTag(String tag) {
    if (selectedFilterType != null) {
      setState(() {
        selectedValues[selectedFilterType!]?.add(tag);
      });
    }
  }

  void removeTag(String tag, String type) {
    setState(() {
      selectedValues[type]?.remove(tag);
    });
  }

  void updateMatchMode(String type, MatchMode mode) {
    setState(() {
      selectedMatchModes[type] = mode;
    });
  }

  void clearAll() {
    setState(() {
      widget.config.filterTypes.forEach((type) {
        selectedValues[type]?.clear();
        final config = widget.config.typeConfigs[type];
        if (config != null) {
          selectedMatchModes[type] = config.defaultMatchMode;
        }
      });
      selectedFilterType = null;
      searchKeyword = '';
    });
  }

  String _matchModeLabel(MatchMode mode) {
    switch (mode) {
      case MatchMode.hierarchical:
        return widget.lang == 'cn' ? '下包含' : 'Hierarchical';
      case MatchMode.contains:
        return widget.lang == 'cn' ? '包含' : 'Contains';
      case MatchMode.equals:
        return widget.lang == 'cn' ? '等于' : 'Equals';
      case MatchMode.greaterThan:
        return widget.lang == 'cn' ? '大于' : '>';
      case MatchMode.lessThan:
        return widget.lang == 'cn' ? '小于' : '<';
      case MatchMode.greaterOrEqual:
        return widget.lang == 'cn' ? '大于等于' : '>=';
      case MatchMode.lessOrEqual:
        return widget.lang == 'cn' ? '小于等于' : '<=';
    }
  }

  List<MatchMode> _availableMatchModes(String type) {
    final config = widget.config.typeConfigs[type];
    if (config == null) return [];
    
    if (config.isNumeric) {
      return [
        MatchMode.equals,
        MatchMode.greaterThan,
        MatchMode.lessThan,
        MatchMode.greaterOrEqual,
        MatchMode.lessOrEqual,
      ];
    }
    
    return [
      MatchMode.hierarchical,
      MatchMode.contains,
      MatchMode.equals,
    ];
  }

  Widget _buildSelectedTagsPool() {
    List<Widget> chips = [];

    widget.config.filterTypes.forEach((type) {
      final tags = selectedValues[type] ?? {};
      if (tags.isEmpty) return;

      final config = widget.config.typeConfigs[type];
      Color bgColor;
      Color textColor;
      switch (type) {
        case 'errorType':
          bgColor = const Color(0xFFFFCDD2);
          textColor = const Color(0xFFC62828);
          break;
        case 'knowledge':
          bgColor = const Color(0xFFE3F2FD);
          textColor = const Color(0xFF1565C0);
          break;
        case 'exercise':
          bgColor = const Color(0xFFE8F5E9);
          textColor = const Color(0xFF1B5E20);
          break;
        case 'progress':
          bgColor = const Color(0xFFFFF3E0);
          textColor = const Color(0xFFE65100);
          break;
        default:
          bgColor = Colors.grey[200]!;
          textColor = Colors.grey[800]!;
      }

      chips.addAll(tags.map((tag) => Chip(
            label: Text(tag),
            backgroundColor: bgColor,
            labelStyle: TextStyle(color: textColor),
            onDeleted: () => removeTag(tag, type),
            deleteIconColor: textColor,
          )));
    });

    if (chips.isEmpty) {
      return Text(widget.lang == 'cn' ? '暂无选中标签' : 'No tags selected');
    }

    return Wrap(
      spacing: 8,
      children: chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lang == 'cn' ? '筛选记录' : 'Filter Records'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lang == 'cn' ? '选择筛选类型：' : 'Select filter type:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonFormField<String?>(
                value: selectedFilterType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(widget.lang == 'cn' ? '请选择筛选类型' : 'Please select'),
                  ),
                  ...widget.config.filterTypes.map((type) {
                    final config = widget.config.typeConfigs[type];
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(config?.label ?? type),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFilterType = value;
                    searchKeyword = '';
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            
            if (selectedFilterType != null) ...[
              Text(
                widget.lang == 'cn' ? '匹配模式：' : 'Match mode:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<MatchMode>(
                  value: selectedMatchModes[selectedFilterType!],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  isExpanded: true,
                  items: _availableMatchModes(selectedFilterType!).map((mode) => DropdownMenuItem<MatchMode>(
                    value: mode,
                    child: Text(_matchModeLabel(mode)),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      updateMatchMode(selectedFilterType!, value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Text(
              widget.lang == 'cn' ? '搜索：' : 'Search:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => setState(() => searchKeyword = value),
              enabled: selectedFilterType != null,
              decoration: InputDecoration(
                hintText: getHintText(),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.search),
              ),
            ),
            if (getSuggestions().isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: getSuggestions().map((item) => ActionChip(
                      label: Text(item),
                      onPressed: () => addTag(item),
                      backgroundColor: Colors.grey[200],
                    )).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              widget.lang == 'cn' ? '已选标签：' : 'Selected tags:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
              child: SingleChildScrollView(
                child: _buildSelectedTagsPool(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: clearAll,
          child: Text(widget.lang == 'cn' ? '清空' : 'Clear'),
        ),
        ElevatedButton(
          onPressed: () {
            Map<String, dynamic> result = {};
            widget.config.filterTypes.forEach((type) {
              result[type] = {
                'values': Set<String>.from(selectedValues[type] ?? {}),
                'matchMode': selectedMatchModes[type]?.index ?? 0,
              };
            });
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF69B4)),
          child: Text(widget.lang == 'cn' ? '确定' : 'Confirm'),
        ),
      ],
    );
  }
}