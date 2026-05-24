import 'package:flutter/material.dart';
import '../components/app_title_bar.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
import '../database/db_helper.dart';
import 'question_detail_page.dart';

class TestPaperDetailPage extends StatefulWidget {
  final String lang;
  final Test test;
  final VoidCallback onHomeTap;

  const TestPaperDetailPage({
    super.key,
    this.lang = 'cn',
    required this.test,
    required this.onHomeTap,
  });

  @override
  State<TestPaperDetailPage> createState() => _TestPaperDetailPageState();
}

class _TestPaperDetailPageState extends State<TestPaperDetailPage> {
  late Test _test;
  List<Question> _questions = [];
  late QuestionDao _questionDao;

  @override
  void initState() {
    super.initState();
    _test = widget.test;
    _initDao();
  }

  Future<void> _initDao() async {
    final db = await DatabaseHelper().database;
    _questionDao = QuestionDao(db);
    await _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await _questionDao.getQuestionsByTid(_test.tid);
    setState(() {
      _questions = questions;
    });
  }

  void _openQuestionDetail(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionDetailPage(
          lang: widget.lang,
          question: question,
          onHomeTap: widget.onHomeTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFF69B4),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onHomeTap,
                    child: const Icon(Icons.home, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.lang == 'cn' ? '试卷详情' : 'Test Paper Detail',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lang == 'cn' ? '试卷标题' : 'Test Title',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _test.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildInfoTag(widget.lang == 'cn' ? '试卷ID' : 'Test ID', _test.tid),
                                  const SizedBox(width: 12),
                                  if (_test.lessonUnitList.isNotEmpty)
                                    _buildInfoTag(widget.lang == 'cn' ? '单元' : 'Unit', _test.lessonUnitList.join(', ')),
                                  const SizedBox(width: 12),
                                  if (_test.status.isNotEmpty)
                                    _buildInfoTag(widget.lang == 'cn' ? '状态' : 'Status', _test.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_test.kids.isNotEmpty)
                                _buildInfoTag(widget.lang == 'cn' ? '知识点' : 'Knowledge', _test.kids.join(', ')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.lang == 'cn' ? '题目清单' : 'Question List',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuestionList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList() {
    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(widget.lang == 'cn' ? '暂无题目' : 'No questions'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          child: ListTile(
            onTap: () => _openQuestionDetail(question),
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              '${index + 1}. ${_truncateText(question.question, 100)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildQuestionTag(question.category ?? '其他'),
                    const SizedBox(width: 8),
                    _buildQuestionTag(widget.lang == 'cn' ? '难度${question.difficulty}' : 'Difficulty ${question.difficulty}'),
                    const SizedBox(width: 8),
                    _buildQuestionTag(question.progress),
                  ],
                ),
                if (question.kid != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.lang == 'cn' ? '知识点' : 'Knowledge'}: ${question.kid}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
          ),
        );
      },
    );
  }

  Widget _buildQuestionTag(String text) {
    Color bgColor;
    Color textColor;
    
    switch (text) {
      case '已批阅':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case '已订正':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        break;
      case '未答题':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      case '未批阅':
        bgColor = const Color(0xFFFCE4EC);
        textColor = const Color(0xFFC2185B);
        break;
      case '填空题':
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        break;
      case '选择题':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case '判断题':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      case '简答题':
        bgColor = const Color(0xFFFCE4EC);
        textColor = const Color(0xFFC2185B);
        break;
      case '作文题':
        bgColor = const Color(0xFFF3E5F5);
        textColor = const Color(0xFF7B1FA2);
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }
}
