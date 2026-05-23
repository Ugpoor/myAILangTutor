import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'main_screen.dart';
import '../database/db_helper.dart';
import '../database/models/knowledge_outline.dart';
import '../database/models/error_type_outline.dart';
import '../services/config_importer.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  bool _isLoading = false;
  String _message = '';

  Future<void> _enterMainApp() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  Future<void> _importTestData() async {
    setState(() {
      _isLoading = true;
      _message = '正在导入测试数据...';
    });

    try {
      final success = await ConfigImporter().importAllConfig(clearExisting: true);
      
      if (success) {
        setState(() {
          _message = '测试数据导入成功！';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('测试数据导入成功')),
          );
        }
      } else {
        setState(() {
          _message = '导入失败: 配置文件不存在或导入过程出错';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('导入失败: 配置文件不存在'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('[EntryPage] 导入测试数据异常: $e');
      setState(() {
        _message = '导入失败: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importKnowledgeOutline() async {
    setState(() {
      _isLoading = true;
      _message = '正在导入知识点大纲...';
    });

    try {
      String? jsonString;
      final directory = await getApplicationDocumentsDirectory();
      final appFilePath = '${directory.path}/knowledge_outlines.json';
      
      // 优先从应用目录读取
      if (await File(appFilePath).exists()) {
        jsonString = await File(appFilePath).readAsString();
      } else {
        // 从资源文件读取
        try {
          jsonString = await rootBundle.loadString('lib/pages/knowledge_outlines.json');
        } catch (e) {
          throw Exception('知识点大纲文件不存在: $e');
        }
      }

      final data = json.decode(jsonString!);
      final outlines = data['knowledge_outlines'] as List;

      final db = await DatabaseHelper().database;
      final dao = KnowledgeOutlineDao(db);
      
      await db.delete('knowledge_outlines');

      for (final item in outlines) {
        await dao.insert(KnowledgeOutline(
          cid: item['cid'],
          content: item['content'],
          lang: item['lang'] ?? 'cn',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      await ConfigImporter().exportKnowledgeOutlinesToConfig();

      setState(() {
        _message = '知识点大纲导入成功！共 ${outlines.length} 条';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('知识点大纲导入成功！共 ${outlines.length} 条')),
        );
      }
    } catch (e) {
      setState(() {
        _message = '导入失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importErrorTypeOutline() async {
    setState(() {
      _isLoading = true;
      _message = '正在导入错类大纲...';
    });

    try {
      String? jsonString;
      final directory = await getApplicationDocumentsDirectory();
      final appFilePath = '${directory.path}/error_type_outlines.json';

      // 优先从应用目录读取
      if (await File(appFilePath).exists()) {
        jsonString = await File(appFilePath).readAsString();
      } else {
        // 从资源文件读取
        try {
          jsonString = await rootBundle.loadString('lib/pages/error_type_outlines.json');
        } catch (e) {
          throw Exception('错类大纲文件不存在: $e');
        }
      }

      final data = json.decode(jsonString!);
      final outlines = data['error_type_outlines'] as List;

      final db = await DatabaseHelper().database;
      final dao = ErrorTypeOutlineDao(db);

      await db.delete('error_type_outlines');

      for (final item in outlines) {
        await dao.insert(ErrorTypeOutline(
          eid: item['eid'],
          content: item['content'],
          lang: item['lang'] ?? 'cn',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      await ConfigImporter().exportErrorTypeOutlinesToConfig();

      setState(() {
        _message = '错类大纲导入成功！共 ${outlines.length} 条';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错类大纲导入成功！共 ${outlines.length} 条')),
        );
      }
    } catch (e) {
      setState(() {
        _message = '导入失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school,
                size: 80,
                color: Color(0xFFFF69B4),
              ),
              const SizedBox(height: 24),
              const Text(
                '我的AI语言学习助手',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF69B4),
                ),
              ),
              const SizedBox(height: 48),
              _buildButton(
                label: '进入主程序',
                icon: Icons.home,
                onPressed: _enterMainApp,
                color: const Color(0xFFFF69B4),
              ),
              const SizedBox(height: 16),
              _buildButton(
                label: '导入测试数据',
                icon: Icons.download,
                onPressed: _importTestData,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildButton(
                label: '导入知识点大纲',
                icon: Icons.list,
                onPressed: _importKnowledgeOutline,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildButton(
                label: '导入错类大纲',
                icon: Icons.tag,
                onPressed: _importErrorTypeOutline,
                color: Colors.orange,
              ),
              const SizedBox(height: 32),
              if (_message.isNotEmpty)
                Text(
                  _message,
                  style: TextStyle(
                    color: _message.contains('成功') ? Colors.green : Colors.red,
                    fontSize: 14,
                  ),
                ),
              if (_isLoading)
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
