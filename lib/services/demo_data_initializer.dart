import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../database/models/skill.dart';
import '../database/models/error_record.dart';
import '../database/models/question.dart';
import '../database/models/test.dart';
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
      // 表非空，但仍需确保 8 个预置技能都存在（旧版安装可能缺少）
      await _ensurePresetSkills(db);
      _initialized = true;
      return;
    }

    // 表为空，首次启动，插入全部示例数据
    await _insertSampleSkills(db);
    await _insertSampleErrorTypeOutlines(db);
    await _insertSampleKnowledgeOutlines(db);
    
    _initialized = true;
  }

  /// 检查 8 个预置技能是否都在数据库中，缺失的逐个补入
  Future<void> _ensurePresetSkills(Database db) async {
    final presetIds = ['s1', 's2', 's3', 's4', 's5', 's6', 's7', 's8'];
    final dao = SkillDao(db);

    for (final id in presetIds) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM skills WHERE skill_id = ?', [id],
      );
      final count = Sqflite.firstIntValue(result);
      if (count == null || count == 0) {
        print('[DemoInit] 预置技能 $id 缺失，补入');
        await _insertSingleSkill(dao, id);
      }
    }
  }

  /// 按 ID 插入单个预置技能
  Future<void> _insertSingleSkill(SkillDao dao, String skillId) async {
    switch (skillId) {
      case 's1':
        await dao.insert(Skill(
          skillId: 's1', name: '获取错误本', category: '外部',
          promptText: '请将以上试卷和答卷、批改内容的图片，识别并按如下结构整理：{"correctAnswer": "正确答案", "errorId": "错误编号", "eids": ["关联错类ID列表，使用点分ID，如1、1.1"], "progress": "处理进度（待订正、已订正、已掌握、学习中）", "question": "题目内容", "wrongAnswer": "错误答案", "wrongWhere": "错在哪里（错误原因的概括描述）", "whyWrong": "错误原因", "howPrevent": "预防方法", "notes": "备注", "images": "图片路径列表（JSON格式）", "tid": "关联试卷ID（格式：T+数字）", "qid": "关联题目ID", "gradeMemo": "批改备注", "correction": "订正内容", "kid": "关联知识点ID（格式：K+数字）", "unitNumber": "单元号", "lessonNumber": "课号", "cid": "知识点大纲分类ID"}。请只要回复json格式，不要其它内容',
          description: '与AI对话时，新开一个主题，避免话题混淆，将审批后的答题卷拍照上传，注意试卷顺序。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's2':
        await dao.insert(Skill(
          skillId: 's2', name: '获取习题集', category: '外部',
          promptText: '请将以上试卷和练习题内容的图片，识别并按如下结构整理：{"test": {"tid": "试卷ID（格式：T+数字）", "title": "试卷标题", "lessonUnitList": ["课时单元标识列表"], "kids": ["关联知识点ID列表"], "status": "状态（未开始、进行中、已完成）", "images": ["图片路径列表"]}, "questions": [{"question": "题目内容", "correctAnswer": "正确答案", "explanation": "答案解析", "category": "题目分类（填空题、选择题、判断题、简答题、作文题）", "difficulty": "难度级别（1-5）", "exerciseId": "题目唯一标识", "tid": "关联试卷ID", "lessonNumber": "单元号", "unitNumber": "课号", "kid": "关联知识点ID", "progress": "答题进度（未答题、已答题、已批阅、已订正）", "grading": "批阅意见", "answer": "用户答题结果"}]}。请只要回复json格式，不要其它内容',
          description: '与AI对话时，新开一个主题，避免话题混淆，将试卷拍照上传，注意题目顺序。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's3':
        await dao.insert(Skill(
          skillId: 's3', name: '获取作品集', category: '外部',
          promptText: '请将以上对话内容，识别为作品记录，若有图片，请ocr识别文字，再整理。内容按如下结构整理：{"title": "作品标题", "contentPath": "内容目录路径", "isOriginal": "是否原创（true/false）", "aiReview": "AI评语/分析报告", "brief": "作品摘要/简介", "kid": "关联知识点ID（格式：K+数字）", "unitNumber": "单元号", "lessonNumber": "课号", "testRecs": "生成练习记录（逗号分隔的tid列表）", "content": "全文搜索内容"}。请只要回复json格式，不要其它内容',
          description: '与AI对话时，新开一个主题，避免话题混淆，将作品内容或图片上传。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。注意aiReview字段需要AI给出内容的评析。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's4':
        await dao.insert(Skill(
          skillId: 's4', name: '获取知识点', category: '外部',
          promptText: '请将以上对话内容，识别为知识点，若有图片，请ocr识别文字，再整理。内容按如下结构整理：{"kid": "知识点唯一标识（格式：K+数字）", "title": "知识点标题", "unitNumber": "单元号", "lessonNumber": "课号", "cid": "知识点大纲分类ID", "contentPath": "内容文件路径", "knowledgeTag": "知识标签", "testTimes": "测试次数", "errorTimes": "错误次数", "brief": "知识点摘要/简介", "content": "全文搜索内容"}。请只要回复json格式，不要其它内容',
          description: '与AI对话时，新开一个主题，避免话题混淆，将知识内容或图片上传。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's5':
        await dao.insert(Skill(
          skillId: 's5', name: '收件箱区分练习类打分', category: '内部',
          internalFunction: '_firstStageClassification',
          parameters: r'题目|(第\d+题)|测试|test|TEST|Question|填空|选择|是非|简答|_[^_\s]*|\bA\b|\bB\b|\bC\b|\bD\b|\ba\b|\bb\b|\bc\b|\bd\b|错在哪|为何错|如何防|错误分析|批阅|正确答案是|得分|^错误|^\d[、.）]\s*',
          returnType: '数值',
          description: '收件箱第一次根据关键词和llm模型分类条目，将符合练习类与不符合练习类的作二分。用户修改参数内容，即可改变final keywords的取值。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's6':
        await dao.insert(Skill(
          skillId: 's6', name: '收件箱错题本分类', category: '内部',
          internalFunction: '_classifyExerciseType',
          parameters: '错误|得分|错在哪|为何错|如何防|批阅|正确答案|我的答案|批改|订正|错解|正误分析',
          returnType: '文本',
          description: '收件箱第二次分类，在被分为符合练习类的条目中继续判断，进一步分为"错题本"或者"习题集"。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's7':
        await dao.insert(Skill(
          skillId: 's7', name: '收件箱作品集分类', category: '内部',
          internalFunction: '_classifyNonExerciseType',
          parameters: '作者|作品欣赏|原创|小说|节选|散文|诗歌|杂文|读后感|作文|范文|文学作品',
          returnType: '文本',
          description: '收件箱第二次分类，在被分为非练习类的条目中继续判断，进一步分为"作品集"或者"知识点"。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
      case 's8':
        await dao.insert(Skill(
          skillId: 's8', name: '单元标签打标', category: '内部',
          internalFunction: 'allocateUnitLesson',
          parameters: '- unit: 1\n  title: 春天\n  lessons:\n    - lesson: 1\n      title: 燕子来了\n    - lesson: 2\n      title: 北国的春天\n- unit: 2\n  title: 夏天\n  lessons:\n    - lesson: 1\n      title: 荷塘月色\n    - lesson: 2\n      title: 夏日绝句\n- unit: 3\n  title: 秋天\n  lessons:\n    - lesson: 1\n      title: 秋天的怀念\n    - lesson: 2\n      title: 秋思',
          returnType: '无',
          description: '收件箱完成分类后，给各条目打上单元标签，广泛用于四大栏目条目的课内标签打标。',
          createdAt: DateTime.now(), lang: 'cn',
        ));
        break;
    }
  }

  Future<void> _insertSampleSkills(Database db) async {
    final dao = SkillDao(db);

    // === 外部技能 s1-s4：提示语模板，用户复制到外部 AI 使用 ===

    await dao.insert(Skill(
      skillId: 's1', name: '获取错误本', category: '外部',
      promptText: '请将以上试卷和答卷、批改内容的图片，识别并按如下结构整理：{"correctAnswer": "正确答案", "errorId": "错误编号", "eids": ["关联错类ID列表，使用点分ID，如1、1.1"], "progress": "处理进度（待订正、已订正、已掌握、学习中）", "question": "题目内容", "wrongAnswer": "错误答案", "wrongWhere": "错在哪里（错误原因的概括描述）", "whyWrong": "错误原因", "howPrevent": "预防方法", "notes": "备注", "images": "图片路径列表（JSON格式）", "tid": "关联试卷ID（格式：T+数字）", "qid": "关联题目ID", "gradeMemo": "批改备注", "correction": "订正内容", "kid": "关联知识点ID（格式：K+数字）", "unitNumber": "单元号", "lessonNumber": "课号", "cid": "知识点大纲分类ID"}。请只要回复json格式，不要其它内容',
      description: '与AI对话时，新开一个主题，避免话题混淆，将审批后的答题卷拍照上传，注意试卷顺序。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    await dao.insert(Skill(
      skillId: 's2', name: '获取习题集', category: '外部',
      promptText: '请将以上试卷和练习题内容的图片，识别并按如下结构整理：{"test": {"tid": "试卷ID（格式：T+数字）", "title": "试卷标题", "lessonUnitList": ["课时单元标识列表"], "kids": ["关联知识点ID列表"], "status": "状态（未开始、进行中、已完成）", "images": ["图片路径列表"]}, "questions": [{"question": "题目内容", "correctAnswer": "正确答案", "explanation": "答案解析", "category": "题目分类（填空题、选择题、判断题、简答题、作文题）", "difficulty": "难度级别（1-5）", "exerciseId": "题目唯一标识", "tid": "关联试卷ID", "lessonNumber": "单元号", "unitNumber": "课号", "kid": "关联知识点ID", "progress": "答题进度（未答题、已答题、已批阅、已订正）", "grading": "批阅意见", "answer": "用户答题结果"}]}。请只要回复json格式，不要其它内容',
      description: '与AI对话时，新开一个主题，避免话题混淆，将试卷拍照上传，注意题目顺序。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    await dao.insert(Skill(
      skillId: 's3', name: '获取作品集', category: '外部',
      promptText: '请将以上对话内容，识别为作品记录，若有图片，请ocr识别文字，再整理。内容按如下结构整理：{"title": "作品标题", "contentPath": "内容目录路径", "isOriginal": "是否原创（true/false）", "aiReview": "AI评语/分析报告", "brief": "作品摘要/简介", "kid": "关联知识点ID（格式：K+数字）", "unitNumber": "单元号", "lessonNumber": "课号", "testRecs": "生成练习记录（逗号分隔的tid列表）", "content": "全文搜索内容"}。请只要回复json格式，不要其它内容',
      description: '与AI对话时，新开一个主题，避免话题混淆，将作品内容或图片上传。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。注意aiReview字段需要AI给出内容的评析。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    await dao.insert(Skill(
      skillId: 's4', name: '获取知识点', category: '外部',
      promptText: '请将以上对话内容，识别为知识点，若有图片，请ocr识别文字，再整理。内容按如下结构整理：{"kid": "知识点唯一标识（格式：K+数字）", "title": "知识点标题", "unitNumber": "单元号", "lessonNumber": "课号", "cid": "知识点大纲分类ID", "contentPath": "内容文件路径", "knowledgeTag": "知识标签", "testTimes": "测试次数", "errorTimes": "错误次数", "brief": "知识点摘要/简介", "content": "全文搜索内容"}。请只要回复json格式，不要其它内容',
      description: '与AI对话时，新开一个主题，避免话题混淆，将知识内容或图片上传。然后将该提示语复制到AI对话软件，要求回复。检查结构无误后，复制粘贴链接或者转发回收件箱。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    // === 内部技能 s5-s8：收件箱分类器参数 ===

    await dao.insert(Skill(
      skillId: 's5', name: '收件箱区分练习类打分', category: '内部',
      internalFunction: '_firstStageClassification',
      parameters: r'题目|(第\d+题)|测试|test|TEST|Question|填空|选择|是非|简答|_[^_\s]*|\bA\b|\bB\b|\bC\b|\bD\b|\ba\b|\bb\b|\bc\b|\bd\b|错在哪|为何错|如何防|错误分析|批阅|正确答案是|得分|^错误|^\d[、.）]\s*',
      returnType: '数值',
      description: '收件箱第一次根据关键词和llm模型分类条目，将符合练习类与不符合练习类的作二分。用户修改参数内容，即可改变final keywords的取值。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    await dao.insert(Skill(
      skillId: 's6', name: '收件箱错题本分类', category: '内部',
      internalFunction: '_classifyExerciseType',
      parameters: '错误|得分|错在哪|为何错|如何防|批阅|正确答案|我的答案|批改|订正|错解|正误分析',
      returnType: '文本',
      description: '收件箱第二次分类，在被分为符合练习类的条目中继续判断，进一步分为"错题本"或者"习题集"。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    await dao.insert(Skill(
      skillId: 's7', name: '收件箱作品集分类', category: '内部',
      internalFunction: '_classifyNonExerciseType',
      parameters: '作者|作品欣赏|原创|小说|节选|散文|诗歌|杂文|读后感|作文|范文|文学作品',
      returnType: '文本',
      description: '收件箱第二次分类，在被分为非练习类的条目中继续判断，进一步分为"作品集"或者"知识点"。',
      createdAt: DateTime.now(), lang: 'cn',
    ));

    await dao.insert(Skill(
      skillId: 's8', name: '单元标签打标', category: '内部',
      internalFunction: 'allocateUnitLesson',
      parameters: '- unit: 1\n  title: 春天\n  lessons:\n    - lesson: 1\n      title: 燕子来了\n    - lesson: 2\n      title: 北国的春天\n- unit: 2\n  title: 夏天\n  lessons:\n    - lesson: 1\n      title: 荷塘月色\n    - lesson: 2\n      title: 夏日绝句\n- unit: 3\n  title: 秋天\n  lessons:\n    - lesson: 1\n      title: 秋天的怀念\n    - lesson: 2\n      title: 秋思',
      returnType: '无',
      description: '收件箱完成分类后，给各条目打上单元标签，广泛用于四大栏目条目的课内标签打标。',
      createdAt: DateTime.now(), lang: 'cn',
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
    final testDao = TestDao(db);
    final questionDao = QuestionDao(db);

    // 插入试卷 T1
    await testDao.insert(Test(
      tid: 'T1',
      title: '四年级上第二单元测试',
      lessonUnitList: ['四年级上-第二单元'],
      kids: ['字形辨析', '近义词', '阅读理解'],
      status: '已批阅',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    // 插入对应的题目
    await questionDao.insert(Question(
      tid: 'T1',
      question: '一、选择正确的字填空\n1. 教室里非常______(安静/宁静)\n2. 夜晚的湖面非常______(安静/平静)\n3. 她______地坐在角落看书(安静/宁静)\n\n二、近义词辨析\n4. 美丽和漂亮的区别\n5. 高兴和快乐的区别',
      correctAnswer: '1. 安静 2. 平静 3. 安静\n4. 美丽=外在好看，漂亮=令人赏心悦目\n5. 高兴=一时情绪，快乐=持久状态',
      grading: '第1题错误：应选"安静"。"安静"强调没有声响，"宁静"强调幽雅安静，教室环境用"安静"更合适。\n第4、5题基本正确，但辨析不够深入。',
      progress: '已批阅',
      kid: 'K1',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lang: 'cn',
    ));

    // 插入试卷 T2
    await testDao.insert(Test(
      tid: 'T2',
      title: '阅读理解专项测试',
      lessonUnitList: ['五年级上-第一单元'],
      kids: ['阅读理解', '主旨归纳', '借物喻人'],
      status: '未批阅',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      lang: 'cn',
    ));

    // 插入对应的题目
    await questionDao.insert(Question(
      tid: 'T2',
      question: '阅读《落花生》，回答：\n1. 概括文章主旨\n2. 找出文中"借物喻人"的语句\n3. 落花生和苹果、石榴的对比说明了什么？',
      correctAnswer: null,
      grading: null,
      progress: '未批阅',
      kid: 'K2',
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
