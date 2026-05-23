import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../database/models/skill.dart';
import '../database/models/error_record.dart';
import '../database/models/exercise.dart';
import '../database/models/portfolio_item.dart';
import '../database/models/knowledge_point.dart';
import '../database/models/error_type_outline.dart';
import '../database/models/knowledge_outline.dart';

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
    await _insertSampleErrorTypeOutlines(db);
    await _insertSampleKnowledgeOutlines(db);
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
输入：小明写了一道成语填空题："杯（龙）明珠"，他写了答案"杯（明）明珠"。

输出：
【题目】杯（龙）明珠
【我的答案】杯（明）明珠
【正确答案】杯（龙）明珠
【错在哪里】将成语"杯龙明珠"中的"龙"字误写为"明"。
【为什么错】知识遗漏——没有掌握"杯龙明珠"这个成语的正确写法，望文生义地将"杯明"理解成杯子明亮。实际上"杯龙"指酒杯中的龙形倒影，典故出自《晋书》。
【如何避免】1. 积累常见成语典故；2. 对不确定字的成语要查字典确认；3. 建立个人错题本，定期复习易错成语

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
      errorId: 'E001',
      eids: ['1', '1.1'],
      progress: '待订正',
      question: '选择正确的字填空：安静/宁静/平静\n(1) 教室里非常______\n(2) 夜晚的湖面非常______\n(3) 她______地坐在角落看书',
      wrongAnswer: '(1) 宁静 (2) 平静 (3) 安静',
      correctAnswer: '(1) 安静 (2) 平静 (3) 安静',
      wrongWhere: '将"安静"和"宁静"混淆使用',
      whyWrong: '概念混淆——"安静"强调没有声音、不吵闹，用于形容环境；"宁静"更侧重心境平和、环境幽雅',
      howPrevent: '1. 记住三个近义词的程度和用法差异；2. "安静"最常用于日常环境描写；3. "宁静"多用于描写自然环境中的幽静',
      notes: '三个词的区别：安静=没有声响；平静=没有波动；宁静=幽雅安静（程度较深）',
      tid: 'T1',
      qid: 'Q1',
      kid: 'K1',
      unitNumber: '4',
      lessonNumber: '1',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    await dao.insert(ErrorRecord(
      errorId: 'E002',
      eids: ['2'],
      progress: '待订正',
      question: '阅读《落花生》一文，概括文章主旨。',
      wrongAnswer: '文章写了一家人种花生、收花生、吃花生的事情。',
      correctAnswer: '文章借落花生"虽然不好看，可是很有用"的特点，表达了"人要做有用的人，不要做只讲体面而对别人没有好处的人"的主旨。',
      wrongWhere: '只概括表面事件，未提炼深层主旨',
      whyWrong: '审题不清——只关注了叙事层面，忽略了"借物喻人"的写作手法和作者的议论抒情',
      howPrevent: '1. 阅读理解题先通读全文，重点看议论和抒情段落；2. 注意"借物喻人""托物言志"等手法的识别；3. 主旨通常在结尾议论部分点明',
      tid: 'T2',
      qid: 'Q2',
      kid: 'K2',
      unitNumber: '5',
      lessonNumber: '1',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lang: 'cn',
    ));

    await dao.insert(ErrorRecord(
      errorId: 'E003',
      eids: ['3'],
      progress: '已订正',
      question: '解方程：2x + 5 = 15',
      wrongAnswer: 'x = 10',
      correctAnswer: 'x = 5',
      wrongWhere: '移项时符号处理错误',
      whyWrong: '计算失误——移项时忘记改变符号，将+5移到右边应该变成-5，正确应为2x = 15 - 5 = 10，所以x = 5',
      howPrevent: '1. 移项时要注意变号；2. 解方程后要代入检验；3. 书写步骤要清晰，避免跳步',
      notes: '移项规则：移项要变号',
      tid: 'T3',
      qid: 'Q3',
      kid: 'K3',
      unitNumber: '3',
      lessonNumber: '2',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      lang: 'cn',
    ));

    await dao.insert(ErrorRecord(
      errorId: 'E004',
      eids: ['4', '5'],
      progress: '学习中',
      question: '"春风又绿江南岸"中"绿"字好在哪里？',
      wrongAnswer: '用得很好，很生动',
      correctAnswer: '"绿"字是形容词作动词用，把春风吹拂后江南岸一片新绿的景象写活了，既有色彩感又有动态感，表现了春天的生机盎然。',
      wrongWhere: '未能准确分析炼字妙处',
      whyWrong: '知识遗漏——缺乏对古诗炼字手法的理解，不知道形容词动用这一修辞技巧',
      howPrevent: '1. 学习古诗时注意词性活用现象；2. 积累常见的炼字手法；3. 分析诗句时从词性、修辞、表达效果三方面入手',
      tid: 'T4',
      qid: 'Q4',
      kid: 'K4',
      unitNumber: '6',
      lessonNumber: '3',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
    ));

    await dao.insert(ErrorRecord(
      errorId: 'E005',
      eids: ['1', '2'],
      progress: '已掌握',
      question: '选词填空：必须/必需\n(1) 我们______遵守交通规则\n(2) 水是生命______的物质',
      wrongAnswer: '(1) 必需 (2) 必须',
      correctAnswer: '(1) 必须 (2) 必需',
      wrongWhere: '混淆"必须"和"必需"的用法',
      whyWrong: '概念混淆——"必须"是副词，表示一定要；"必需"是形容词，表示不可缺少的',
      howPrevent: '1. 记住词性差异："必须"是副词，修饰动词；"必需"是形容词，修饰名词；2. 通过造句练习巩固',
      notes: '必须=一定要（副词）；必需=不可缺少（形容词）',
      tid: 'T5',
      qid: 'Q5',
      kid: 'K5',
      unitNumber: '2',
      lessonNumber: '4',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
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
      question: '阅读理解专项测试',
      exerciseId: 'T2',
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

    // W1: 落花生 - 许地山 (课文赏析)
    await dao.insert(PortfolioItem(
      title: '落花生——许地山',
      isOriginal: false,
      contentPath: 'portfolio/peanut_analysis',
      brief: '许地山经典散文赏析，借物喻人手法的典范',
      kid: 'K2',
      unitNumber: '5',
      lessonNumber: '1',
      aiReview: '''本文运用借物喻人的手法，将花生的品格与人的品格对照，表达朴实无华而有用的价值观。文章结构简洁，对比鲜明，语言朴实而寓意深刻。

内容赏析：
文章通过写一家人过花生收获节的过程，描写了花生"虽然不好看，可是很有用"的特点。作者许地山以平实的语言，层层递进地引出主旨："人要做有用的人，不要做只讲体面而对别人没有好处的人。"

写作手法：
1. 借物喻人——以花生比喻做人的道理
2. 对话描写——通过母子三人的对话展现不同性格
3. 对比手法——花生与苹果、石榴的对比

建议：学习这种写作手法时，可尝试观察身边普通事物，挖掘其背后的深层含义。''',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
    ));

    // W2: 我的校园 - 原创写景作文
    await dao.insert(PortfolioItem(
      title: '我的校园',
      isOriginal: true,
      contentPath: 'portfolio/my_school',
      brief: '原创写景作文，描写美丽的校园',
      kid: 'K3',
      unitNumber: '4',
      lessonNumber: '4',
      aiReview: '''这篇写景作文结构清晰，按照"校门口→操场→教学楼→小花园"的空间顺序展开，展现了校园的美丽景色。

优点：
1. 空间顺序明确，条理清晰
2. 运用了比喻、拟人等修辞手法，如"春天的花园像一幅五彩斑斓的画卷"形象生动
3. 动词使用准确，如"偷偷地从土里钻出来"赋予小草人的情态

改进建议：
1. 加强细节描写，可以加入更多感官描写（视觉、听觉、嗅觉），如"微风吹过，阵阵桂花香气扑鼻而来，让人心旷神怡"
2. 可在结尾加入抒情段落，表达对校园的喜爱之情，提升文章感染力
3. 注意词语搭配的准确性，避免望文生义的错误

仿写练习：选取校园的一处景物，从不同角度进行细致观察，运用多种感官描写。''',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lang: 'cn',
    ));

    // W3: 春 - 朱自清 (名篇赏析)
    await dao.insert(PortfolioItem(
      title: '春——朱自清',
      isOriginal: false,
      contentPath: 'portfolio/spring_zhu',
      brief: '朱自清经典散文，描绘春天的美好',
      kid: 'K4',
      unitNumber: '5',
      lessonNumber: '2',
      aiReview: '''朱自清以细腻的笔触描绘春天的景象，运用大量比喻和拟人手法，将春天比作"刚落地的娃娃""小姑娘""健壮的青年"，层层递进，富有画面感和生命力。

内容赏析：
全文围绕"盼春—绘春—赞春"的结构展开，先写对春天的盼望，再细致描绘春草、春花、春风、春雨等春日景象，最后赞美春天新、美、力的特点。

修辞手法：
1. 比喻——把春天比作战士，突出其力量
2. 拟人——"小草偷偷地从土里钻出来"，赋予小草人的情态
3. 排比——"山朗润起来了，水涨起来了，太阳的脸红起来了"，增强气势

建议：学习这种层次分明的写景方法，注意抓住每个季节特有的景物进行描写。''',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      lang: 'cn',
    ));

    // W4: 写人作文 - 我的老师
    await dao.insert(PortfolioItem(
      title: '我的老师——写人作文',
      isOriginal: true,
      contentPath: 'portfolio/my_teacher',
      brief: '原创写人作文，刻画老师形象',
      kid: 'K5',
      unitNumber: '7',
      lessonNumber: '1',
      aiReview: '文章通过细致的外貌描写、动作描写和心理描写，塑造了一位慈祥关爱学生的老师形象。\n\n优点：\n1. 外貌描写生动——"她有一双会说话的眼睛"准确传达了老师的温和\n2. 选取典型事例——帮助同学解数学题的事例体现了老师的耐心\n3. 心理活动真实——"我心里暖暖的"表达了真情实感\n\n改进建议：\n1. 加强语言描写的多样性，让对话更生动自然\n2. 可增加一些神态描写，如老师微笑时的表情变化\n3. 结尾可适当升华主题，点明老师对自己的影响\n\n仿写方向：选取身边一个熟悉的人，从外貌、语言、动作、心理四个角度各写一段。',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      lang: 'cn',
    ));

    // W5: 鲁迅散文 - 从百草园到三味书屋
    await dao.insert(PortfolioItem(
      title: '从百草园到三味书屋——鲁迅',
      isOriginal: false,
      contentPath: 'portfolio/b百草园',
      brief: '鲁迅回忆性散文，对比手法运用',
      kid: 'K6',
      unitNumber: '7',
      lessonNumber: '2',
      aiReview: '鲁迅通过百草园的自由快乐与三味书屋的枯燥严肃形成对比，表现儿童天真活泼的天性。\n\n内容概述：\n文章分为两部分，前半部分写百草园的快乐生活——捕鸟、听长妈妈讲故事；后半部分写在三味书屋的读书生活。两部分通过对比，反映儿童天性与成人教育的冲突。\n\n艺术特色：\n1. 对比手法——百草园的自由与书屋的束缚形成强烈对比\n2. 色彩对比——"碧绿的菜畦""黑圆的柏树"增强画面感\n3. 细节生动——"拍雪人的手"等动作描写真实可信\n4. 语言朴实——没有华丽辞藻，却充满童趣\n\n建议：学习对比手法时，可从自己的经历中寻找素材，通过前后场景的变化来表现情感。',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      lang: 'cn',
    ));

    // W6: 记叙文 - 难忘的一件事
    await dao.insert(PortfolioItem(
      title: '难忘的一件事——记叙文',
      isOriginal: true,
      contentPath: 'portfolio/unforgettable',
      brief: '原创记叙文，讲述难忘的运动会经历',
      kid: 'K7',
      unitNumber: '6',
      lessonNumber: '2',
      aiReview: '文章叙述了一次运动会接力赛的经历，结构完整，有起承转合。\n\n优点：\n1. 叙事条理清晰——按"赛前准备—比赛过程—赛后感受"的顺序展开\n2. 细节生动——"咬紧牙关""拼命向前跑"等动作描写传神\n3. 情感真实——"我恨不得自己也上去跑"表达了内心的急切\n\n改进建议：\n1. 开头过于平淡，可用环境描写烘托紧张气氛\n2. 高潮部分节奏偏快，可放慢速度，增加心理和环境的描写\n3. 结尾略显仓促，应点明此事"难忘"的原因，做到首尾呼应\n\n训练重点：掌握记叙文的六要素（时间、地点、人物、起因、经过、结果），学会在关键节点放慢节奏。',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      lang: 'cn',
    ));
  }

  Future<void> _insertSampleKnowledgePoints(Database db) async {
    final dao = KnowledgePointDao(db);

    // 词汇 (cid: 1)
    await dao.insert(KnowledgePoint(
      title: '近义词辨析方法',
      cid: '1',
      contentPath: 'knowledge/synonym_analysis',
      brief: '近义词辨析的四种方法：语素分析、语境代入、搭配习惯、程度轻重',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
      unitNumber: '4',
      lessonNumber: '1',
    ));

    await dao.insert(KnowledgePoint(
      title: '语素分析法示例',
      cid: '1.1',
      contentPath: 'knowledge/morpheme_analysis',
      brief: '通过分析不同语素理解近义词差异',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
      unitNumber: '4',
      lessonNumber: '1',
    ));

    await dao.insert(KnowledgePoint(
      title: '语境代入法示例',
      cid: '1.2',
      contentPath: 'knowledge/context_method',
      brief: '通过语境代入辨析近义词',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      lang: 'cn',
      unitNumber: '4',
      lessonNumber: '1',
    ));

    // 写作手法 (cid: 2)
    await dao.insert(KnowledgePoint(
      title: '借物喻人写作手法',
      cid: '2',
      contentPath: 'knowledge/metaphor_writing',
      brief: '借物喻人：通过描写事物特征来比喻人的品格、志向或道理。',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
      unitNumber: '5',
      lessonNumber: '1',
    ));

    await dao.insert(KnowledgePoint(
      title: '借物喻人的识别方法',
      cid: '2.1',
      contentPath: 'knowledge/metaphor_recognition',
      brief: '识别借物喻人写作手法的五个步骤。',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
      unitNumber: '5',
      lessonNumber: '1',
    ));

    await dao.insert(KnowledgePoint(
      title: '《落花生》赏析',
      cid: '2.2',
      contentPath: 'knowledge/peanut_analysis',
      brief: '《落花生》借物喻人赏析，表达做人要做有用的人。',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
      unitNumber: '5',
      lessonNumber: '1',
    ));
  }

  Future<void> _insertSampleErrorTypeOutlines(Database db) async {
    final dao = ErrorTypeOutlineDao(db);

    await dao.insert(ErrorTypeOutline(
      eid: '1',
      content: '概念混淆',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '1.1',
      content: '近义词辨析错误',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '1.2',
      content: '形近字混淆',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '2',
      content: '审题不清',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '2.1',
      content: '关键词忽略',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '2.2',
      content: '会错题意',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '3',
      content: '计算失误',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '4',
      content: '知识遗漏',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '5',
      content: '推理错误',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(ErrorTypeOutline(
      eid: '6',
      content: '表达错误',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _insertSampleKnowledgeOutlines(Database db) async {
    final dao = KnowledgeOutlineDao(db);

    await dao.insert(KnowledgeOutline(
      cid: '1',
      content: '词汇',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '1.1',
      content: '近义词辨析',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '1.2',
      content: '反义词运用',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '2',
      content: '写作手法',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '2.1',
      content: '借物喻人',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '2.2',
      content: '对比手法',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '3',
      content: '阅读理解',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '3.1',
      content: '主旨归纳',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '3.2',
      content: '推理判断',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '4',
      content: '句法',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '5',
      content: '文章',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));

    await dao.insert(KnowledgeOutline(
      cid: '6',
      content: '阅读',
      lang: 'cn',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _insertSampleEfficiencyRecords(Database db) async {
    final now = DateTime.now();
    final records = [
      {'title': '语文复习', 'unit_count': 3, 'unit_efficiency': 0.85},
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
      {'schedule_id': 'SC3', 'title': '成语积累与仿写', 'start_time': '17:00', 'end_time': '17:30', 'repeat_type': 'daily', 'completed': 0},
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
