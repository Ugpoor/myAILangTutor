import 'package:flutter/material.dart';
import '../../components/app_title_bar.dart';
import '../../components/submenu_tabs.dart';
import '../../database/models/test.dart';
import '../../database/models/question.dart';
import '../../database/db_helper.dart';
import 'question_detail_page.dart';

class PaperDetailPage extends StatefulWidget {
  final String lang;
  final Test paper;
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
  late Test _paper;
  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _paper = widget.paper;
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final db = await DatabaseHelper().database;
    final questionDao = QuestionDao(db);
    final questions = await questionDao.getQuestionsByTid(_paper.tid);
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _navigateToQuestionDetail(Question question) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionDetailPage(
          lang: widget.lang,
          question: question,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
    if (result == true) {
      _loadQuestions();
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
              title: '${widget.lang == 'cn' ? '试卷' : 'Paper'} ${_paper.tid}',
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
                            _buildPaperInfoCard(),
                            const SizedBox(height: 20),
                            
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
                                  '${_questions.length} ${widget.lang == 'cn' ? '题' : 'questions'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            if (_questions.isEmpty)
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
                              ...List.generate(_questions.length, (index) {
                                final question = _questions[index];
                                return _buildQuestionItem(question, index);
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
                  _paper.tid,
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
              if (_paper.lessonUnitList.isNotEmpty)
                _buildInfoChip('${widget.lang == 'cn' ? '单元' : 'Unit'}: ${_paper.lessonUnitList.join(', ')}'),
              if (_paper.kids.isNotEmpty)
                _buildInfoChip('${widget.lang == 'cn' ? '知识' : 'Knowledge'}: ${_paper.kids.join(', ')}'),
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
              if (_paper.gradeDate != null)
                _buildInfoChip(
                  '${widget.lang == 'cn' ? '批阅日期' : 'Grade Date'}: ${_paper.gradeDate!.toString().split('T')[0]}',
                ),
              if (_paper.images.isNotEmpty)
                _buildInfoChip(
                  '${widget.lang == 'cn' ? '图片' : 'Images'}: ${_paper.images.length}张',
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
        color: color ?? Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color != null ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已完成':
        return const Color(0xFF4CAF50);
      case '进行中':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  Widget _buildQuestionItem(Question question, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _navigateToQuestionDetail(question),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question.exerciseId ?? widget.lang == 'cn' ? '未编号' : 'Unnumbered',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getQuestionStatusColor(question.progress),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      question.progress,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                question.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getQuestionStatusColor(String status) {
    switch (status) {
      case '已批阅':
        return const Color(0xFFFF9800);
      case '已订正':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }
}