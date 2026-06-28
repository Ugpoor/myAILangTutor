import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/error_record.dart';
import 'error_record_detail_page.dart';

/// 错题本分组汇总视图 - 按错类→知识点层级显示
/// ErrorType作为目录条目，KnowledgeTag作为二级条目（长条按钮样式），嵌入原始错误记录文本

class ErrorRecordGroupedView extends StatefulWidget {
  final String lang;
  final List<ErrorRecord> allRecords;
  final ErrorRecordDao dao;
  final VoidCallback onHomeTap;
  final VoidCallback onCancel; // 取消视图模式，返回主列表

  const ErrorRecordGroupedView({
    super.key,
    this.lang = 'cn',
    required this.allRecords,
    required this.dao,
    required this.onHomeTap,
    required this.onCancel,
  });

  @override
  State<ErrorRecordGroupedView> createState() => _ErrorRecordGroupedViewState();
}

enum _GroupMode { exerciseTag, knowledgeTag, errorType }

class _ErrorRecordGroupedViewState extends State<ErrorRecordGroupedView> {
  late _GroupMode _groupMode;

  @override
  void initState() {
    super.initState();
    // 默认按错误类别分组
    _groupMode = _GroupMode.errorType;
  }

  String get _groupModeLabel {
    switch (_groupMode) {
      case _GroupMode.exerciseTag:
        return widget.lang == 'cn' ? '习题标签' : 'Exercise Tag';
      case _GroupMode.knowledgeTag:
        return widget.lang == 'cn' ? '知识标签' : 'Knowledge Tag';
      case _GroupMode.errorType:
        return widget.lang == 'cn' ? '错误类别' : 'Error Type';
    }
  }

  /// 获取所有不重复的分组键（去掉null/null string）
  Set<String> get _groupKeys {
    return widget.allRecords
        .map((r) => _getGroupKey(r))
        .where((key) => key.isNotEmpty && key != 'null')
        .toSet();
  }

  String _getGroupKey(ErrorRecord r) {
    switch (_groupMode) {
      case _GroupMode.exerciseTag:
        return r.qid ?? '';
      case _GroupMode.knowledgeTag:
        return r.kid ?? '';
      case _GroupMode.errorType:
        return r.eids.isNotEmpty ? r.eids[0] : '';
    }
  }

  Future<void> _navigateToDetail(ErrorRecord record) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ErrorRecordDetailPage(
          lang: widget.lang,
          record: record,
          dao: widget.dao,
          onHomeTap: widget.onHomeTap,
          fromGroupedView: true,
        ),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _showGroupModeDialog() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(widget.lang == 'cn' ? '选择分组方式' : 'Select Grouping'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<_GroupMode>(
                value: _GroupMode.exerciseTag,
                groupValue: _groupMode,
                onChanged: (v) {
                  setState(() => _groupMode = v!);
                  Navigator.pop(context);
                },
              ),
              title: Text(widget.lang == 'cn' ? '按照习题标签分组' : 'By Exercise Tag'),
              subtitle: Text('(T1, T2...)'),
            ),
            ListTile(
              leading: Radio<_GroupMode>(
                value: _GroupMode.knowledgeTag,
                groupValue: _groupMode,
                onChanged: (v) {
                  setState(() => _groupMode = v!);
                  Navigator.pop(context);
                },
              ),
              title: Text(widget.lang == 'cn' ? '按照知识标签分组' : 'By Knowledge Tag'),
              subtitle: Text('(知识点标题)'),
            ),
            ListTile(
              leading: Radio<_GroupMode>(
                value: _GroupMode.errorType,
                groupValue: _groupMode,
                onChanged: (v) {
                  setState(() => _groupMode = v!);
                  Navigator.pop(context);
                },
              ),
              title: Text(widget.lang == 'cn' ? '按照错误类别分组' : 'By Error Type'),
              subtitle: Text('(审题不清/概念混淆/知识遗漏...)'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _groupKeys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: '${widget.lang == 'cn' ? '错题本-' : 'Error Records - '}$_groupModeLabel',
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: keys.isEmpty
                    ? Center(child: Text(widget.lang == 'cn' ? '暂无错题数据' : 'No data'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: keys.length,
                        itemBuilder: (context, index) {
                          final key = keys[index];
                          final records = _getRecordsInGroup(key);
                          return _buildGroupCard(key, records);
                        },
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: [
                widget.lang == 'cn' ? '切换分组' : 'Switch',
                widget.lang == 'cn' ? '取消' : 'Cancel',
              ],
              selectedTab: '',
              onTabSelected: (tab) {
                if (tab == (widget.lang == 'cn' ? '切换分组' : 'Switch')) {
                  _showGroupModeDialog();
                } else {
                  widget.onCancel();
                }
              },
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  List<ErrorRecord> _getRecordsInGroup(String groupKey) {
    return widget.allRecords.where((r) {
      return _getGroupKey(r) == groupKey;
    }).toList()..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2020);
        final bTime = b.createdAt ?? DateTime(2020);
        return bTime.compareTo(aTime);
      });
  }

  Widget _buildGroupCard(String groupKey, List<ErrorRecord> records) {
    // 根据分组模式决定如何渲染
    if (_groupMode == _GroupMode.errorType) {
      // 错类作为目录条目，知识点作为二级条目（长条按钮样式）
      return _buildErrorTypeWithNestedKnowledge(groupKey, records);
    } else if (_groupMode == _GroupMode.knowledgeTag) {
      return _buildExpansionTile(groupKey, records, showInnerTags: true);
    } else {
      return _buildExpansionTile(groupKey, records, showInnerTags: false);
    }
  }

  /// 错类→知识点→错误的三级层级显示
  Widget _buildErrorTypeWithNestedKnowledge(String errorTypeKey, List<ErrorRecord> records) {
    // 按知识点分组
    final Map<String, List<ErrorRecord>> knowledgeGroups = {};
    for (final record in records) {
      final kt = record.kid ?? (widget.lang == 'cn' ? '未分类' : 'Uncategorized');
      knowledgeGroups.putIfAbsent(kt, () => []);
      knowledgeGroups[kt]!.add(record);
    }

    final knowledgeKeys = knowledgeGroups.keys.toList()..sort();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: const Color(0xFFFF5252),
        collapsedIconColor: const Color(0xFF9E9E9E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                errorTypeKey,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${knowledgeKeys.length}个知识点/${records.length}条错误',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        children: knowledgeKeys.map((kt) {
          final ktRecords = knowledgeGroups[kt]!;
          return _buildKnowledgeButton(kt, ktRecords);
        }).toList(),
      ),
    );
  }

  /// 知识点作为二级条目——长条按钮样式
  Widget _buildKnowledgeButton(String knowledgeTag, List<ErrorRecord> records) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          // 点击知识点时导航到第一个错误记录详情
          if (records.isNotEmpty) {
            _navigateToDetail(records.first);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 知识点标题行
              Row(
                children: [
                  Icon(Icons.menu_book, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      knowledgeTag,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${records.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 展示该知识点下的前3条错误记录预览
              ...records.take(3).map((record) {
                return _buildErrorPreviewCard(record, excludeErrorType: true);
              }),
              if (records.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${records.length - 3} more',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 错误记录预览卡片（不含被筛选的错类标签）
  Widget _buildErrorPreviewCard(ErrorRecord record, {bool excludeErrorType = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: record.progress == '待订正' ? Colors.white : Colors.green[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: record.progress == '待订正' 
              ? Colors.orange[200]! 
              : Colors.green[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: record.progress == '待订正' 
                  ? const Color(0xFFFFA07A) 
                  : const Color(0xFF90EE90),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Extract question to avoid null promotion issue with public field
                Text(
                  (() {
                    final title = record.wrongWhere ?? record.question ?? record.errorId ?? '';
                    return title.length > 40 ? '${title.substring(0, 40)}...' : title;
                  })(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  children: [
                    // 知识点标签
                    if (record.kid != null)
                      Chip(
                        label: Text(record.kid!, style: const TextStyle(fontSize: 9)),
                        backgroundColor: Colors.blue[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        side: BorderSide.none,
                      ),
                    // 错误类型标签（可选排除）
                    if (!excludeErrorType && record.eids.isNotEmpty)
                      Chip(
                        label: Text(record.eids.join(','), style: const TextStyle(fontSize: 9)),
                        backgroundColor: Colors.orange[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        side: BorderSide.none,
                      ),
                    // 题目标签
                    if (record.qid != null)
                      Chip(
                        label: Text(record.qid!, style: const TextStyle(fontSize: 9)),
                        backgroundColor: Colors.purple[100],
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _navigateToDetail(record),
            icon: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// 普通展开式卡片（单级分组）
  Widget _buildExpansionTile(String groupKey, List<ErrorRecord> records,
      {bool showInnerTags = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: const Color(0xFFFF69B4),
        collapsedIconColor: const Color(0xFF9E9E9E),
        title: Row(
          children: [
            Text(
              groupKey,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF69B4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${records.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: records.map((record) {
                return InkWell(
                  onTap: () => _navigateToDetail(record),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: record.progress == '待订正'
                                ? const Color(0xFFFFA07A)
                                : const Color(0xFF90EE90),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (() {
                                  final title = record.wrongWhere ?? record.question ?? record.errorId ?? '';
                                  return title.length > 60 ? '${title.substring(0, 60)}...' : title;
                                })(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (showInnerTags) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (record.kid != null)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Chip(
                                          label: Text(record.kid!,
                                              style: const TextStyle(fontSize: 10)),
                                          backgroundColor: Colors.blue[100],
                                          labelStyle: const TextStyle(fontSize: 10),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    if (record.eids.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Chip(
                                          label: Text(record.eids.join(','),
                                              style: const TextStyle(fontSize: 10)),
                                          backgroundColor: Colors.orange[100],
                                          labelStyle: const TextStyle(fontSize: 10),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
