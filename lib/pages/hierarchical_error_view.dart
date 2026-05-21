import 'dart:convert';

import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../components/submenu_tabs.dart';
import '../database/models/error_record.dart';
import '../database/models/exercise.dart';
import '../database/models/chat_message.dart';
import '../database/db_helper.dart';
import '../services/llm_service.dart';
import '../services/app_service.dart';
import 'error_detail_page.dart';

/// 分层层级视图（错类→知识点→题目）
class HierarchicalErrorView extends StatefulWidget {
  final String lang;
  final Map<String, Map<String, List<ErrorRecord>>> groupedData;
  final List<ErrorRecord> allRecords;
  final ErrorRecordDao dao;
  final VoidCallback onHomeTap;
  final VoidCallback onUpdate;

  const HierarchicalErrorView({
    super.key,
    required this.lang,
    required this.groupedData,
    required this.allRecords,
    required this.dao,
    required this.onHomeTap,
    required this.onUpdate,
  });

  @override
  State<HierarchicalErrorView> createState() => _HierarchicalErrorViewState();
}

class _HierarchicalErrorViewState extends State<HierarchicalErrorView> {
  final Set<int> _selectedIds = {};
  
  /// 安全截断文本，避免 range error
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  Future<void> _navigateToDetail(ErrorRecord record) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ErrorDetailPage(
          lang: widget.lang,
          record: record,
          errorRecordDao: widget.dao,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
    if (result == true) {
      widget.onUpdate();
    }
  }
  
  /// 根据选中错误记录，使用 LLM 生成练习题
  Future<void> _generateExercisesWithLLM() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'cn' ? '请先选择错误条目' : 'Select error records first')),
      );
      return;
    }

    final db = await DatabaseHelper().database;
    
    // 声明在外层，以便在 catch 块中也能访问
    late int loadingMsgId;
    
    try {
      // 插入"习题生成中"的AI消息（直接使用数据库，不依赖 AppService）
      final chatMsgDao = ChatMessageDao(db);
      loadingMsgId = await chatMsgDao.insert(ChatMessage(
        content: widget.lang == 'cn' ? '习题生成中...' : 'Generating exercises...',
        isUser: false,
        createdAt: DateTime.now(),
        lang: widget.lang,
      ));

      final exerciseDao = ExerciseDao(db);
      final llmService = LlmService();
      await llmService.init();

      final selectedRecords = widget.allRecords.where((r) => _selectedIds.contains(r.id)).toList();

      setState(() {}); // 显示加载状态
      
      // 构建错题内容（只使用关键信息）
      final errorContent = selectedRecords.map((r) {
        return '''【题目】${r.question ?? r.content}
【我的答案】${r.wrongAnswer ?? ''}
【正确答案】${r.correctAnswer ?? ''}
【错因分析】${r.whyWrong ?? ''}''';
      }).join('\n\n---\n\n');

      // 简洁统一的提示语
      final prompt = '''你是一位语文教育专家。请根据以下{错题条目内容}，出一组同样知识点考点的练习题，填空题2题；选择题5题。并提供答案和解析。

请以如下 JSON 数组格式回复（只返回 JSON，不要其他文字）：
[
  {
    "question": "完整题目内容",
    "options": null 或 ["A. 选项1", "B. 选项2", "C. 选项3", "D. 选项4"],
    "correctAnswer": "答案",
    "explanation": "解析"
  },
  ...
]

注意：
- 填空题的 options 设为 null
- correctAnswer 是简短答案
- explanation 是解题思路
- 共输出 7 道题（2 填空 + 5 选择）

{错题条目内容}：
$errorContent
''';

      final response = await llmService.generateResponse(prompt);
      
      if (response['success'] != true || response['response'] == null) {
        throw Exception('LLM 响应失败');
      }

      final jsonResponse = response['response'] as String;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonResponse);
      if (jsonMatch == null) {
        throw Exception('未找到 JSON 数组');
      }

      final List<dynamic> exercisesJson = json.decode(jsonMatch.group(0)!);
      int createdCount = 0;

      for (final exData in exercisesJson) {
        final nextNum = await exerciseDao.nextExerciseIdNumber();
        
        // 判断题型
        final optionsStr = exData['options'];
        final isFillBlank = optionsStr == null || 
            (optionsStr is List && optionsStr.isEmpty);
        
        final exercise = Exercise(
          question: exData['question'] ?? '',
          options: isFillBlank 
              ? null
              : (optionsStr as List).join('\n'),
          correctAnswer: exData['correctAnswer'] as String?,
          explanation: exData['explanation'] as String?,
          category: isFillBlank ? '填空题' : '选择题',
          difficulty: 2,
          knowledgeTag: selectedRecords.first.kid ?? '综合',
          progress: '未答题',
          source: '错误本自动生成',
          exerciseId: 'T$nextNum',
          contentPath: selectedRecords.first.contentPath,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );

        await exerciseDao.insert(exercise);
        createdCount++;
      }

      // 更新AI消息为"已完成习题生成"
      if (mounted) {
        final chatMsgDao = ChatMessageDao(db);
        final completedMsg = ChatMessage(
          id: loadingMsgId,
          content: widget.lang == 'cn' 
              ? '已完成习题生成！已从${selectedRecords.length}条错题生成$createdCount道练习题并添加到习题集'
              : 'Exercise generation complete! Generated $createdCount exercises from ${selectedRecords.length} error records.',
          isUser: false,
          createdAt: DateTime.now(),
          lang: widget.lang,
        );
        await chatMsgDao.update(completedMsg);

        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' 
                  ? '成功从${selectedRecords.length}条错题生成$createdCount道练习题！'
                  : 'Successfully generated $createdCount exercises!',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('[GenerateExercises] 生成失败: $e');
      // 更新AI消息为错误信息
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lang == 'cn' ? '生成练习失败: ${e.toString()}' : 'Failed: ${e.toString()}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _selectedIds.clear());
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: widget.lang == 'cn' ? '错误本 - 层次视图' : 'Error Book - Hierarchical View',
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: widget.groupedData.isEmpty
                    ? Center(
                        child: Text(widget.lang == 'cn' ? '暂无错误记录' : 'No error records'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.groupedData.length,
                        itemBuilder: (context, index) {
                          final entry = widget.groupedData.entries.elementAt(index);
                          final errorType = entry.key;
                          final knowledgeMap = entry.value;
                          
                          return _buildErrorTypeSection(errorType, knowledgeMap);
                        },
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: _selectedIds.isEmpty 
                  ? [widget.lang == 'cn' ? '返回' : 'Back']
                  : [
                      widget.lang == 'cn' ? '返回' : 'Back',
                      '${widget.lang == 'cn' ? '练习' : 'Practice'} (${_selectedIds.length})',
                    ],
              selectedTab: _selectedIds.isEmpty ? '' : (widget.lang == 'cn' ? '练习' : 'Practice'),
              onTabSelected: (tab) {
                if (tab.contains('练习') || tab.contains('Practice')) {
                  _generateExercisesWithLLM();
                } else {
                  Navigator.pop(context);
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
  
  Widget _buildErrorTypeSection(String errorType, Map<String, List<ErrorRecord>> knowledgeMap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.category, color: Colors.orange[700]),
        title: Text(
          errorType,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        children: knowledgeMap.entries.map((kgEntry) {
          final knowledgeTag = kgEntry.key;
          final records = kgEntry.value;
          
          return _buildKnowledgeTagSection(knowledgeTag, records);
        }).toList(),
      ),
    );
  }
  
  Widget _buildKnowledgeTagSection(String knowledgeTag, List<ErrorRecord> records) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(Icons.menu_book, size: 20, color: Colors.blue[700]),
        title: Text(
          '$knowledgeTag ($records)',
          style: const TextStyle(fontSize: 13),
        ),
        children: records.map((record) {
          return _buildRecordItem(record);
        }).toList(),
      ),
    );
  }
  
  Widget _buildRecordItem(ErrorRecord record) {
    final isSelected = _selectedIds.contains(record.id);
    
    return InkWell(
      onTap: () => _navigateToDetail(record),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[100] : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.add(record.id!);
                    } else {
                      _selectedIds.remove(record.id!);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _truncateText(record.errorId ?? "", 10) + ' ' + _truncateText(record.question ?? record.content, 30),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: record.progress == '已订正' ? Colors.green[100] : Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            record.progress,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
