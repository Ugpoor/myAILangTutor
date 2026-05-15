import 'package:flutter/material.dart';
import 'pages/widget_gallery.dart';
import 'services/share_intent_service.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ShareIntentService().init();

  // 🔑 ONE-TIME DB RESET: delete old DB to force fresh onCreate + onUpgrade
  try {
    await deleteDatabase('myAILangTutor.db');
    print('✅ DB RESET: myAILangTutor.db deleted — fresh init on next launch');
  } catch (e) {
    print('ℹ️  DB not found or already deleted — proceeding normally');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的AI语言学习助手',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),
      home: const WidgetGallery(),
      debugShowCheckedModeBanner: false,
    );
  }
}
