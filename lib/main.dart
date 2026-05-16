import 'package:flutter/material.dart';
import 'pages/main_screen.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔑 ONE-TIME DB RESET: delete old DB to force fresh onCreate + onUpgrade
  try {
    print('[Main] 重置数据库');
    await deleteDatabase('myAILangTutor.db');
    print('✅ DB RESET: myAILangTutor.db deleted — fresh init on next launch');
  } catch (e) {
    print('[Main] 数据库重置: $e');
  }

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
