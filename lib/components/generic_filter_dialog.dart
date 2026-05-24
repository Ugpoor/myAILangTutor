import 'package:flutter/material.dart';

class FilterOption {
  final String value;
  final String label;

  FilterOption({required this.value, required this.label});
}

class FilterConfig {
  final List<String> filterTypes;
  final Map<String, List<FilterOption>> optionsByType;
  final Map<String, Set<String>> initialValues;
  final Map<String, String> typeLabels;
  final Map<String, String> hintTexts;

  FilterConfig({
    required this.filterTypes,
    required this.optionsByType,
    required this.initialValues,
    required this.typeLabels,
    required this.hintTexts,
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

  static Future<Map<String, Set<String>>?> show(
    BuildContext context, {
    required FilterConfig config,
    String lang = 'cn',
  }) {
    return showDialog<Map<String, Set<String>>>(
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
  String? selectedFilterType;
  String searchKeyword = '';

  @override
  void initState() {
    super.initState();
    selectedValues = Map.fromEntries(
      widget.config.initialValues.entries
          .map((e) => MapEntry(e.key, Set<String>.from(e.value))),
    );
  }

  String getHintText() {
    if (selectedFilterType == null) {
      return widget.lang == 'cn' ? '请先选择筛选类型' : 'Please select filter type first';
    }
    return widget.config.hintTexts[selectedFilterType!] ?? '';
  }

  List<String> getSuggestions() {
    if (searchKeyword.isEmpty || selectedFilterType == null) return [];
    final options = widget.config.optionsByType[selectedFilterType!] ?? [];
    return options
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

  void clearAll() {
    setState(() {
      widget.config.filterTypes.forEach((type) {
        selectedValues[type]?.clear();
      });
      selectedFilterType = null;
      searchKeyword = '';
    });
  }

  Widget _buildSelectedTagsPool() {
    List<Widget> chips = [];

    widget.config.filterTypes.forEach((type) {
      final tags = selectedValues[type] ?? {};
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
                  ...widget.config.filterTypes.map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(widget.config.typeLabels[type] ?? type),
                      )),
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
            Navigator.pop(context, Map.fromEntries(
              widget.config.filterTypes.map((type) => MapEntry(
                type,
                Set<String>.from(selectedValues[type] ?? {}),
              )),
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF69B4)),
          child: Text(widget.lang == 'cn' ? '确定' : 'Confirm'),
        ),
      ],
    );
  }
}