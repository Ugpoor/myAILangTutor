import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/main_screen.dart';
import 'services/demo_data_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // 初始化演示样例数据（仅在数据库为空时插入）
  await DemoDataInitializer().initIfEmpty();

  print('[Main] 启动应用');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的AI语言学习助手',
      theme: ThemeData(primarySwatch: Colors.pink, useMaterial3: true),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
