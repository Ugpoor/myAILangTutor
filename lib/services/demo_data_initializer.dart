import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../database/models/skill.dart';
import '../database/models/error_record.dart';
import '../database/models/exercise.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/knowledge_point.dart';

class DemoDataInitializer {
  static final DemoDataInitializer _instance = DemoDataInitializer._internal();
  factory DemoDataInitializer() => _instance;
  DemoDataInitializer._internal();

  bool _initialized = false;

  Future<void> initIfEmpty() async {
    if (_initialized) return;
    final db = await DatabaseHelper().database;

    // 检查是否已有数据
    final skillCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM skills'),
    );
    if (skillCount != null && skillCount > 0) {
      _initialized = true;
      return;
    }

    await _insertSampleSkills(db);
    await _insertSampleErrorRecords(db);
    await _insertSampleExercises(db);
    await _insertSamplePortfolioItems(db);
    await _insertSampleKnowledgePoints(db);
    await _insertSampleEfficiencyRecords(db);
    await _insertSampleScheduleItems(db);

    _initialized = true;
  }

  Future<void> _insertSampleSkills(Database db) async {
    final dao = SkillDao(db);

    // 外部技能1：错误本格式指令
    await dao.insert(Skill(
      skillId: 'S1',
      name: '错误本格式识别',
      category: '外部',
      prerequisite: null,
      promptText: '''请将以下内容按照错误本格式整理输出。格式要求如下：

【题目】（原题内容）
【我的答案】（我写的答案）
【正确答案】（正确答案）
【错在哪里】（具体错在哪个步骤或哪个知识点）
【为什么错】（错误原因分析：概念混淆/计算失误/审题不清/知识遗漏/推理错误）
【如何避免】（预防同类错误的措施）

示例：
输入：小明做了一道题"3/4 + 1/4 = ?"，他写了答案"4/8"。

输出：
【题目】3/4 + 1/4 = ?
【我的答案】4/8
【正确答案】1
【错在哪里】通分后分子直接相加，但忘记了约分；或者没有理解同分母分数加法规则。
【为什么错】概念混淆——将异分母加法的通分思路误用于同分母加法。同分母分数相加时，分母不变，分子相加即可。3/4 + 1/4 = (3+1)/4 = 4/4 = 1。
【如何避免】1. 先判断是同分母还是异分母，再选择对应算法；2. 结果一定要约分为最简分数；3. 做完后用逆运算验证：1 - 3/4 = 1/4 ✓

请严格按照以上格式整理以下内容：''',
      description: '将AI助手的分析结果按照统一格式整理成错误本条目，方便录入学习系统。复制此提示语，粘贴到豆包/元宝等外部AI中，配合答卷照片或题目内容使用。',
      createdAt: DateTime.now(),
      lang: 'cn',
    ));

    // 外部技能2：作品集采集与赏析
    await dao.insert(Skill(
      skillId: 'S2',
      name: '作品集采集与赏析',
      category: '外部',
      prerequisite: null,
      promptText: '''请对以下文章进行采集整理和赏析分析：

第一步：采集整理
- 标题：
- 作者：
- 出处/来源：
- 正文：（完整收录原文）

第二步：赏析分析
1. 内容概述（50字以内概括文章主旨）
2. 写作手法（至少分析3种手法，如比喻、拟人、排比等，引用原文说明）
3. 结构分析（文章层次、过渡、首尾呼应等）
4. 语言特色（遣词造句的特点和效果）
5. 情感表达（作者情感脉络和表达方式）
6. 仿写建议（提供一个基于本文手法的仿写练习方向）

请对以下内容进行分析：''',
      description: '采集文章内容并进行系统化赏析分析，生成结构化的评析报告。复制此提示语，粘贴到豆包/元宝等外部AI中，配合采集的文章内容使用。',
      createdAt: DateTime.now(),
      lang: 'cn',
    ));

    // 内部技能3：练习题批改
    await dao.insert(Skill(
      skillId: 'S3',
      name: '练习题批改',
      category: '内部',
      prerequisite: null,
      internalFunction: '练习题批改',
      parameters: 'exercise_id: 习题ID',
      returnType: 'grading_result',
      description: '批改指定习题的答卷，逐题对答案进行评分并生成批阅结果。',
      createdAt: DateTime.now(),
      lang: 'cn',
    ));

    // 内部技能4：知识点梳理
    await dao.insert(Skill(
      skillId: 'S4',
      name: '知识点梳理',
      category: '内部',
      prerequisite: null,
      internalFunction: '知识点梳理',
      parameters: 'knowledge_tag: 知识标签',
      returnType: 'knowledge_outline',
      description: '根据知识标签梳理相关知识点，生成知识大纲和知识图谱数据。',
      createdAt: DateTime.now(),
      lang: 'cn',
    ));

    // 内部技能5：练习题生成
    await dao.insert(Skill(
      skillId: 'S5',
      name: '练习题生成',
      category: '内部',
      prerequisite: 'S3',
      internalFunction: '练习题生成',
      parameters: 'knowledge_tag: 知识标签, count: 题目数量',
      returnType: 'exercise_list',
      description: '根据知识点标签生成指定数量的练习题，自动创建习题集条目。',
      createdAt: DateTime.now(),
      lang: 'cn',
    ));
  }

  Future<void> _insertSampleErrorRecords(Database db) async {
    final dao = ErrorRecordDao(db);

    await dao.insert(ErrorRecord(
      content: '小学语文四年级形近字辨析',
      errorId: 'T1',
      errorType: '概念混淆',
      exerciseTag: 'T1',
      knowledgeTag: '字形辨析',
      progress: '待订正',
      question: '选择正确的字填空：安静/宁静/平静\n(1) 教室里非常______\n(2) 夜晚的湖面非常______\n(3) 她______地坐在角落看书',
      wrongAnswer: '(1) 宁静 (2) 平静 (3) 安静',
      correctAnswer: '(1) 安静 (2) 平静 (3) 安静',
      wrongWhere: '第(1)题将"安静"和"宁静"混淆',
      whyWrong: '概念混淆——"安静"强调没有声音、不吵闹，用于形容环境；"宁静"更侧重心境平和、环境幽雅',
      howPrevent: '1. 记住三个近义词的程度和用法差异；2. "安静"最常用于日常环境描写；3. "宁静"多用于描写自然环境中的幽静',
      notes: '三个词的区别：安静=没有声响；平静=没有波动；宁静=幽雅安静（程度较深）',
      subject: '语文',
      lesson: '四年级上',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    await dao.insert(ErrorRecord(
      content: '阅读理解主旨归纳偏差',
      errorId: 'T3',
      errorType: '审题不清',
      exerciseTag: 'T3',
      knowledgeTag: '阅读理解',
      progress: '待订正',
      question: '阅读《落花生》一文，概括文章主旨。',
      wrongAnswer: '文章写了一家人种花生、收花生、吃花生的事情。',
      correctAnswer: '文章借落花生"虽然不好看，可是很有用"的特点，表达了"人要做有用的人，不要做只讲体面而对别人没有好处的人"的主旨。',
      wrongWhere: '只概括了表面事件，没有提炼深层主旨',
      whyWrong: '审题不清——只关注了叙事层面，忽略了"借物喻人"的写作手法和作者的议论抒情',
      howPrevent: '1. 阅读理解题先通读全文，重点看议论和抒情段落；2. 注意"借物喻人""托物言志"等手法的识别；3. 主旨通常在结尾议论部分点明',
      subject: '语文',
      lesson: '五年级上',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lang: 'cn',
    ));
  }

  Future<void> _insertSampleExercises(Database db) async {
    final dao = ExerciseDao(db);

    await dao.insert(Exercise(
      question: '四年级上第二单元测试',
      exerciseId: 'T1',
      lessonUnit: '四年级上-第二单元',
      knowledgeTag: '字形辨析,近义词,阅读理解',
      progress: '已批阅',
      category: '单元测试',
      examPaper: '一、选择正确的字填空\n1. 教室里非常______(安静/宁静)\n2. 夜晚的湖面非常______(安静/平静)\n3. 她______地坐在角落看书(安静/宁静)\n\n二、近义词辨析\n4. 美丽和漂亮的区别\n5. 高兴和快乐的区别',
      answerSheet: '1. 宁静 2. 平静 3. 安静\n4. 美丽侧重外表，漂亮侧重好看\n5. 高兴侧重情绪，快乐侧重状态',
      answerKey: '1. 安静 2. 平静 3. 安静\n4. 美丽=外在好看，漂亮=令人赏心悦目\n5. 高兴=一时情绪，快乐=持久状态',
      grading: '第1题错误：应选"安静"。"安静"强调没有声响，"宁静"强调幽雅安静，教室环境用"安静"更合适。\n第4、5题基本正确，但辨析不够深入。',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    await dao.insert(Exercise(
      question: '分数运算专项练习',
      exerciseId: 'T2',
      lessonUnit: '四年级上-第三单元',
      knowledgeTag: '分数运算,约分,通分',
      progress: '未答题',
      category: '专项练习',
      examPaper: '1. 3/4 + 1/4 = ?\n2. 2/5 + 1/10 = ?\n3. 5/6 - 1/3 = ?\n4. 1/2 + 1/3 = ?\n5. 7/8 - 3/4 = ?',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lang: 'cn',
    ));

    await dao.insert(Exercise(
      question: '阅读理解专项测试',
      exerciseId: 'T3',
      lessonUnit: '五年级上-第一单元',
      knowledgeTag: '阅读理解,主旨归纳,借物喻人',
      progress: '未批阅',
      category: '专项练习',
      examPaper: '阅读《落花生》，回答：\n1. 概括文章主旨\n2. 找出文中"借物喻人"的语句\n3. 落花生和苹果、石榴的对比说明了什么？',
      answerSheet: '1. 文章写了一家人种花生、收花生、吃花生的事情。\n2. "所以你们要像花生，它虽然不好看，可是很有用"\n3. 说明了花生虽然外表不好看，但是很有用',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      lang: 'cn',
    ));
  }

  Future<void> _insertSamplePortfolioItems(Database db) async {
    final dao = PortfolioDao(db);

    await dao.insert(PortfolioItem(
      title: '落花生——许地山',
      portfolioId: 'W1',
      type: '课文赏析',
      isOriginal: false,
      knowledgeTag: '借物喻人,阅读理解',
      lessonUnit: '五年级上-第一单元',
      aiReview: '本文运用借物喻人的手法，将花生的品格与人的品格对照，表达朴实无华而有用的价值观。文章结构简洁，对比鲜明，语言朴实而寓意深刻。',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
    ));

    await dao.insert(PortfolioItem(
      title: '我的校园',
      portfolioId: 'W2',
      type: '习作',
      isOriginal: true,
      knowledgeTag: '写景作文,观察描写',
      lessonUnit: '四年级上-第四单元',
      aiReview: null,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lang: 'cn',
    ));

    await dao.insert(PortfolioItem(
      title: '春——朱自清',
      portfolioId: 'W3',
      type: '名篇赏析',
      isOriginal: false,
      knowledgeTag: '写景抒情,比喻拟人',
      lessonUnit: '五年级上-第二单元',
      aiReview: '朱自清以细腻的笔触描绘春天的景象，运用大量比喻和拟人手法，将春天比作"刚落地的娃娃""小姑娘""健壮的青年"，层层递进，富有画面感和生命力。',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      lang: 'cn',
    ));
  }

  Future<void> _insertSampleKnowledgePoints(Database db) async {
    final dao = KnowledgePointDao(db);

    // 根节点:词汇
    await dao.insert(KnowledgePoint(
      title: '近义词辨析方法',
      content: '1. 语素分析法：找出不同的语素，分析其含义\n2. 语境代入法：分别代入具体语境，看哪个更恰当\n3. 搭配习惯法：注意固定搭配和习惯用法\n4. 程度轻重法：辨析近义词程度差异',
      category: '词汇',
      lessonUnit: '四年级上',
      errorType: '概念混淆',
      parentId: null,
      difficulty: 2,
      mastered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
    ));

    // 子节点:语素分析法 (父级为近义词辨析方法)
    await dao.insert(KnowledgePoint(
      title: '语素分析法示例',
      content: '例："美丽"vs"漂亮"\n- "美"指好看、美观\n- "丽"指华丽、绚丽\n- "漂"指漂浮、漂泊\n- "亮"指明亮、清脆\n通过语素分析可以看出两者的侧重点不同',
      category: '词汇',
      lessonUnit: '四年级上',
      errorType: '概念混淆',
      parentId: 1,
      difficulty: 2,
      mastered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
    ));

    // 子节点:语境代入法
    await dao.insert(KnowledgePoint(
      title: '语境代入法示例',
      content: '例：安静/宁静/平静\n- 教室里非常"安静"(强调没有声音)\n- 夜晚的湖面非常"宁静"(侧重幽雅安静)\n- 她"安静"地坐在角落看书(形容环境)',
      category: '词汇',
      lessonUnit: '四年级上',
      errorType: '概念混淆',
      parentId: 1,
      difficulty: 2,
      mastered: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
    ));

    // 根节点:写作手法
    await dao.insert(KnowledgePoint(
      title: '借物喻人写作手法',
      content: '借物喻人：通过描写事物的特征，来比喻人的品格、志向或道理。\n特点：1. 表面写物，实际写人；2. 物与人之间有相似点；3. 多在结尾点明主旨\n经典例子：《落花生》《白杨》《梅花魂》',
      category: '写作手法',
      lessonUnit: '五年级上',
      errorType: '审题不清',
      parentId: null,
      difficulty: 3,
      mastered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    // 子节点:借物喻人识别
    await dao.insert(KnowledgePoint(
      title: '借物喻人的识别方法',
      content: '1. 找出文中被描写的"物"\n2. 分析该物的特征\n3. 寻找物与人的相似点\n4. 关注结尾的议论抒情段落\n5. 确定作者想要表达的"人"的品格或志向',
      category: '写作手法',
      lessonUnit: '五年级上',
      errorType: '审题不清',
      parentId: 4,
      difficulty: 3,
      mastered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    // 子节点:经典篇目
    await dao.insert(KnowledgePoint(
      title: '《落花生》赏析',
      content: '文章通过种花生、收花生、吃花生的过程，描写花生"虽然不好看，可是很有用"的特点，借物喻人，表达"人要做有用的人，不要做只讲体面而对别人没有好处的人"的主旨。',
      category: '写作手法',
      lessonUnit: '五年级上',
      errorType: '审题不清',
      parentId: 4,
      difficulty: 3,
      mastered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));
  }

  Future<void> _insertSampleEfficiencyRecords(Database db) async {
    final now = DateTime.now();
    final records = [
      {'title': '语文复习', 'unit_count': 3, 'unit_efficiency': 0.85},
      {'title': '数学练习', 'unit_count': 2, 'unit_efficiency': 0.72},
      {'title': '阅读理解训练', 'unit_count': 4, 'unit_efficiency': 0.90},
      {'title': '作文练习', 'unit_count': 1, 'unit_efficiency': 0.65},
      {'title': '错题订正', 'unit_count': 5, 'unit_efficiency': 0.88},
    ];

    for (int i = 0; i < records.length; i++) {
      await db.insert('efficiency_records', {
        'record_id': 'E${i + 1}',
        'title': records[i]['title'],
        'unit_count': records[i]['unit_count'],
        'unit_efficiency': records[i]['unit_efficiency'],
        'record_time': now.subtract(Duration(days: records.length - i - 1)).toIso8601String(),
        'created_at': now.subtract(Duration(days: records.length - i - 1)).toIso8601String(),
        'lang': 'cn',
      });
    }
  }

  Future<void> _insertSampleScheduleItems(Database db) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];

    final items = [
      {'schedule_id': 'SC1', 'title': '晨读：古诗词背诵', 'start_time': '07:00', 'end_time': '07:30', 'repeat_type': 'daily', 'completed': 1},
      {'schedule_id': 'SC2', 'title': '语文课后练习', 'start_time': '16:00', 'end_time': '16:45', 'repeat_type': 'weekly', 'repeat_days': '1,3,5', 'completed': 0},
      {'schedule_id': 'SC3', 'title': '数学错题订正', 'start_time': '17:00', 'end_time': '17:30', 'repeat_type': 'daily', 'completed': 0},
      {'schedule_id': 'SC4', 'title': '课外阅读', 'start_time': '20:00', 'end_time': '20:30', 'repeat_type': 'daily', 'completed': 0},
    ];

    for (final item in items) {
      await db.insert('schedule_items', {
        'schedule_id': item['schedule_id'],
        'title': item['title'],
        'start_time': item['start_time'],
        'end_time': item['end_time'],
        'repeat_type': item['repeat_type'],
        'repeat_days': item['repeat_days'],
        'date': todayStr,
        'completed': item['completed'],
        'created_at': today.toIso8601String(),
        'updated_at': today.toIso8601String(),
        'lang': 'cn',
      });
    }
  }
}
