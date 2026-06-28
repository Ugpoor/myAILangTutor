import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/entry_page.dart';
import 'services/inbox_service.dart';
import 'services/demo_data_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // 立即启动 UI，不做任何阻塞初始化
  runApp(const MyApp());

  // 所有重初始化推迟到首帧渲染之后
  Future.delayed(Duration.zero, () async {
    await DemoDataInitializer().initIfEmpty();
    await SkillConfig.loadFromSkills();
    // ShareIntentService 由 MainScreen 自行管理（冷/热启动统一处理）
    print('[Main] 后台初始化完成');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的AI语言学习助手',
      theme: ThemeData(primarySwatch: Colors.pink, useMaterial3: true),
      home: const EntryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
