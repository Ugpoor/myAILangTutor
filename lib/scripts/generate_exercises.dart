import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../database/models/exercise.dart';

/// 手动生成10道语文练习题的脚本
/// 使用方法：在终端运行 flutter run lib/scripts/generate_exercises.dart
void main() async {
  // 获取数据库路径
  final dbPath = await getApplicationDocumentsDirectory();
  final path = join(dbPath.path, 'my_lang_tutor.db');
  
  print('数据库路径: $path');
  
  final db = await openDatabase(path, version: 10);
  
  try {
    // 1. 删除所有现有习题
    print('正在删除所有现有习题...');
    await db.delete('exercises');
    print('已清除所有习题！\n');
    
    // 2. 插入10道精心设计的语文练习题
    final exercises = [
      // 第1题：填空题 - 古诗文默写
      Exercise(
        question: '补全王勃《送杜少府之任蜀州》中的诗句："海内存______，天涯若比邻。"',
        correctAnswer: '知己',
        explanation: '"海内存知己"意思是四海之内有知心朋友，表达了诗人对友人的深情厚谊。这是唐代诗人王勃的名句。',
        category: '填空题',
        difficulty: 2,
        exerciseId: 'Y1',
        lessonUnit: '八年级下册',
        knowledgeTag: '古诗文默写',
        source: '语文教材',
        progress: '未答题',
      ),
      
      // 第2题：填空题 - 成语填空
      Exercise(
        question: '请填写正确的字完成成语：画龙点______',
        options: null,
        correctAnswer: '晴',
        explanation: '"画龙点睛"原指画龙时使用睛彩点睛，使整条龙栩栩如生。比喻作文或说话时在关键地方加上精辟的语句，使内容更加生动传神。出自唐代张僧繇的故事。',
        category: '填空题',
        difficulty: 1,
        exerciseId: 'Y2',
        lessonUnit: '三年级上册',
        knowledgeTag: '成语运用',
        source: '语文教材',
        progress: '未答题',
      ),
      
      // 第3题：选择题 - 字形辨析
    Exercise(
      question: '下列词语中书写正确的是：',
      options: 'A. 杯龙明珠\nB. 杯笼明珠\nC. 杯茏明珠\nD. 杯胧明珠',
      correctAnswer: 'A',
      explanation: '"杯龙明珠"是一个成语，指酒杯中的龙形倒影，形容虚幻不实的事物。典故出自《晋书·周处传》。其他选项中的"笼""茏""胧"都是形近误用。',
      category: '选择题',
      difficulty: 2,
      exerciseId: 'Y3',
      lessonUnit: '四年级上册',
      knowledgeTag: '字形辨析,成语运用',
      source: '语文教材',
      progress: '未答题',
    ),
    
    // 第4题：选择题 - 修辞手法识别
    Exercise(
      question: '下列句子使用了比喻修辞手法的是：',
      options: 'A. 小草偷偷地从土里钻出来\nB. 春风像母亲的手轻轻地抚摸着你\nC. 红的太阳、白的雪、绿的草地\nD. 你在哪里，亲人你在哪里？',
      correctAnswer: 'B',
      explanation: '选项B将"春风"比作"母亲的手"，运用了比喻的修辞手法，形象地写出了春风的柔和温暖。这句话出自朱自清的散文《春》。A项使用拟人，C项使用排比，D项使用反复。',
      category: '选择题',
      difficulty: 2,
      exerciseId: 'Y4',
      lessonUnit: '七年级上册',
      knowledgeTag: '修辞手法',
      source: '语文教材',
      progress: '未答题',
    ),
    
    // 第5题：填空题 - 古诗文理解
    Exercise(
      question: '杜甫《望岳》中蕴含"站得高看得远"哲理的诗句是："会当凌绝顶，______。"',
      correctAnswer: '一览众山小',
      explanation: '"会当凌绝顶，一览众山小"表达了诗人敢于攀登顶峰、俯视一切的雄心壮志。只有登上最高点，才能看到群山显得渺小，蕴含了站得高看得远的哲理。',
      category: '填空题',
      difficulty: 3,
      exerciseId: 'Y5',
      lessonUnit: '七年级下册',
      knowledgeTag: '古诗文默写,诗歌鉴赏',
      source: '语文教材',
      progress: '未答题',
    ),
    
    // 第6题：选择题 - 文学常识
    Exercise(
      question: '《落花生》一文的作者是：',
      options: 'A. 鲁迅\nB. 许地山\nC. 老舍\nD. 巴金',
      correctAnswer: 'B',
      explanation: '《落花生》是现代作家许地山的代表作之一。文章借花生"虽然不好看，可是很有用"的特点，表达做人要做有用的人的道理。许地山又名许地，是中国现代文学早期的重要作家。',
      category: '选择题',
      difficulty: 1,
      exerciseId: 'Y6',
      lessonUnit: '五年级上册',
      knowledgeTag: '文学常识',
      source: '语文教材',
      progress: '未答题',
    ),
    
    // 第7题：选择题 - 阅读理解
    Exercise(
      question: '"春天的花园像一幅五彩斑斓的画卷"这句话使用的修辞手法及其表达效果是：',
      options: 'A. 拟人——让花朵具有人的情态\nB. 比喻——将花园美景形象化\nC. 夸张——强调花园很大\nD. 排比——增强语言气势',
      correctAnswer: 'B',
      explanation: '该句将"春天的花园"比作"五彩斑斓的画卷"，是典型的明喻。通过这个比喻，生动形象地描绘出春天花园繁花似锦、色彩缤纷的美丽景象，给读者以强烈的画面感。',
      category: '选择题',
      difficulty: 2,
      exerciseId: 'Y7',
      lessonUnit: '四年级上册',
      knowledgeTag: '修辞手法,阅读理解',
      source: '拓展训练',
      progress: '未答题',
    ),
    
    // 第8题：填空题 - 近义词辨析
    Exercise(
      question: '根据语境选择合适的近义词填空：\n教室里非常______（安静/宁静），同学们都在认真看书。\n夜晚的湖边非常______（安静/宁静），只有偶尔传来的虫鸣声。',
      correctAnswer: '安静；宁静',
      explanation: '"安静"强调没有声音、不吵闹，多用于形容环境或场所；"宁静"更侧重环境的幽雅和心境的平和，程度较深。"教室"常用"安静"来形容，而"夜晚的湖面"则更适合用"宁静"来表现其幽静的氛围。',
      category: '填空题',
      difficulty: 2,
      exerciseId: 'Y8',
      lessonUnit: '四年级上册',
      knowledgeTag: '近义词辨析,词汇运用',
      source: '拓展训练',
      progress: '未答题',
    ),
    
    // 第9题：选择题 - 写作手法
    Exercise(
      question: '《白杨》一文运用的主要写作手法是：',
      options: 'A. 借景抒情\nB. 借物喻人\nC. 对比反衬\nD. 先抑后扬',
      correctAnswer: 'B',
      explanation: '《白杨》是袁鹰的作品，采用"借物喻人"的手法，通过描写戈壁滩上高大挺秀的白杨树，象征那些扎根边疆、建设边疆的建设者们的崇高品格。这种手法托物言志，将物的特征与人的品格相对应。',
      category: '选择题',
      difficulty: 3,
      exerciseId: 'Y9',
      lessonUnit: '五年级下册',
      knowledgeTag: '写作手法,阅读理解',
      source: '语文教材',
      progress: '未答题',
    ),
    
    // 第10题：填空题 - 成语积累
    Exercise(
      question: '请写出三个带有数字的四字成语：______、______、______。',
      correctAnswer: '三心二意、五湖四海、七上八下（答案不唯一）',
      explanation: '汉语中有大量含有数字的成语，这些成语往往凝练有趣，易于记忆。如"三心二意"表示意志不坚定，"五湖四海"泛指全国各地，"七上八下"形容心情不安定等。注意数字在成语中不一定是确数，有时是虚指。',
      category: '填空题',
      difficulty: 1,
      exerciseId: 'Y10',
      lessonUnit: '三年级上册',
      knowledgeTag: '成语积累,词汇运用',
      source: '拓展训练',
      progress: '未答题',
    ),
    ];
    
    // 修复第3题语法 - 它已经是Exercise对象但之前定义有误
    // 重新创建完整的exercise list
    
    int createdCount = 0;
    
    for (final ex in exercises) {
      final map = ex.toMap();
      await db.insert('exercises', map);
      createdCount++;
      print('已插入: ${ex.exerciseId} - ${ex.question.substring(0, ex.question.length > 30 ? 30 : ex.question.length)}...');
    }
    
    print('\n成功插入 $createdCount 道语文练习题！');
    print('当前习题集数据已更新。\n');
    
  } catch (e) {
    print('错误: $e');
    StackTrace.trace(current).toString().split('\n').forEach(print);
  } finally {
    await db.close();
  }
}

// 补充Exercise导入
import 'lib/database/models/exercise.dart';
