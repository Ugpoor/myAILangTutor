import 'package:flutter/material.dart';
import '../../components/app_title_bar.dart';
import '../../components/submenu_tabs.dart';
import '../../database/models/exam_paper.dart';
import '../../database/models/exercise.dart';
import '../../database/db_helper.dart';
import 'exercise_detail_page.dart';

/// 试卷详情页面（显示该试卷下的所有试题）
class PaperDetailPage extends StatefulWidget {
  final String lang;
  final ExamPaper paper;
  final VoidCallback onHomeTap;

  const PaperDetailPage({
    super.key,
    this.lang = 'cn',
    required this.paper,
    required this.onHomeTap,
  });

  @override
  State<PaperDetailPage> createState() => _PaperDetailPageState();
}

class _PaperDetailPageState extends State<PaperDetailPage> {
  late ExamPaper _paper;
  List<Exercise> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _paper = widget.paper;
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final db = await DatabaseHelper().database;
    final exerciseDao = ExerciseDao(db);
    final exercises = await exerciseDao.getExercisesByPaperId(_paper.paperId);
    setState(() {
      _exercises = exercises;
      _isLoading = false;
    });
  }

  void _navigateToExerciseDetail(Exercise exercise) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailPage(
          lang: widget.lang,
          exercise: exercise,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
    if (result == true) {
      _loadExercises(); // 重新加载
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          children: [
            AppTitleBar(
              title: '${widget.lang == 'cn' ? '试卷' : 'Paper'} ${_paper.paperId}',
              onHomeTap: widget.onHomeTap,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 试卷信息卡片
                            _buildPaperInfoCard(),
                            const SizedBox(height: 20),
                            
                            // 试题列表标题
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.lang == 'cn' ? '【试题列表】' : 'Questions',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_exercises.length} ${widget.lang == 'cn' ? '题' : 'questions'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // 试题列表
                            if (_exercises.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Text(
                                    widget.lang == 'cn' ? '暂无试题' : 'No questions yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(_exercises.length, (index) {
                                final exercise = _exercises[index];
                                return _buildExerciseItem(exercise, index);
                              }),
                          ],
                        ),
                      ),
              ),
            ),
            SubmenuTabs(
              tabs: [widget.lang == 'cn' ? '返回' : 'Back'],
              selectedTab: '',
              onTabSelected: (tab) {
                Navigator.of(context).pop();
              },
              onHomeTap: widget.onHomeTap,
              lang: widget.lang,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _paper.paperId,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _paper.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_paper.subject != null)
                _buildInfoChip('${widget.lang == 'cn' ? '科目' : 'Subject'}: ${_paper.subject}'),
              if (_paper.lessonUnit != null)
                _buildInfoChip('${widget.lang == 'cn' ? '单元' : 'Unit'}: ${_paper.lessonUnit}'),
              if (_paper.knowledgeTag != null)
                _buildInfoChip('${widget.lang == 'cn' ? '知识' : 'Knowledge'}: ${_paper.knowledgeTag}'),
              if (_paper.totalScore != null)
                _buildInfoChip('${widget.lang == 'cn' ? '总分' : 'Score'}: ${_paper.totalScore}'),
              if (_paper.duration != null)
                _buildInfoChip('${widget.lang == 'cn' ? '时长' : 'Duration'}: ${_paper.duration}min'),
              _buildInfoChip(
                '${widget.lang == 'cn' ? '状态' : 'Status'}: ${_paper.status}',
                color: _getStatusColor(_paper.status),
              ),
              if (_paper.examDate != null)
                _buildInfoChip(
                  '${widget.lang == 'cn' ? '考试日期' : 'Exam Date'}: ${_paper.examDate!.toString().split('T')[0]}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFFE3F2FD)).withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color != null ? Colors.black : const Color(0xFF1976D2),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '未开始':
        return Colors.grey;
      case '进行中':
        return Colors.orange;
      case '已完成':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildExerciseItem(Exercise exercise, int index) {
    final progressColor = _getProgressColor(exercise.progress);
    
    return InkWell(
      onTap: () => _navigateToExerciseDetail(exercise),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            // 题号圆圈
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // 题目信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        exercise.exerciseId ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF651FFF),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.question,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: progressColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exercise.progress,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      if (exercise.knowledgeTag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF87CEEB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            exercise.knowledgeTag!,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 箭头图标
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(String progress) {
    switch (progress) {
      case '未答题':
        return const Color(0xFFD3D3D3);
      case '已答题':
        return const Color(0xFFFFE4E9);
      case '已批阅':
        return const Color(0xFFFFA07A);
      case '已订正':
        return const Color(0xFF90EE90);
      default:
        return Colors.grey;
    }
  }
}
