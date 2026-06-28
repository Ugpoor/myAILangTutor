import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'main_screen.dart';
import '../database/models/knowledge_outline.dart';
import '../database/models/error_type_outline.dart';
import '../services/config_importer.dart';
import '../services/share_intent_service.dart';
import '../database/db_helper.dart';
import '../database/models/skill.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> with WidgetsBindingObserver {
  bool _isLoading = false;
  String _message = '';
  bool _shareDetected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 延迟检测分享意图，确保 MethodChannel 就绪（冷启动时需要）
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _checkAndNavigateShare();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (mounted && !_shareDetected) {
          await ShareIntentService().init();
          _checkAndNavigateShare();
        }
      });
    }
  }

  /// 检测是否有来自外部的分享意图，如有则自动跳转到主页面处理
  Future<void> _checkAndNavigateShare() async {
    if (_shareDetected) return;
    try {
      await ShareIntentService().init();
      final sharedText = ShareIntentService().sharedText;
      if (sharedText != null && sharedText.isNotEmpty) {
        _shareDetected = true;
        print('[EntryPage] 检测到分享意图，自动跳转主页面');
        if (mounted) _navigateToMainWithShare();
      }
    } catch (e) {
      print('[EntryPage] 分享检测失败: $e');
    }
  }

  /// 携带分享数据跳转到主页面（由 MainScreen 处理下载逻辑）
  void _navigateToMainWithShare() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

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
        final detail = ConfigImporter().lastErrorMessage ?? '配置文件不存在或导入过程出错';
        setState(() {
          _message = '部分导入失败: $detail';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('部分导入失败，详见页面提示'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
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
      
      if (await File(appFilePath).exists()) {
        jsonString = await File(appFilePath).readAsString();
      } else {
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

      if (await File(appFilePath).exists()) {
        jsonString = await File(appFilePath).readAsString();
      } else {
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

  Future<void> _loadSkillsData() async {
    setState(() {
      _isLoading = true;
      _message = '正在加载技能数据...';
    });

    try {
      // 删除应用目录中可能存在的旧 skills.json
      final directory = await getApplicationDocumentsDirectory();
      final appSkillsPath = '${directory.path}/test_data/skills.json';
      final appSkillsFile = File(appSkillsPath);
      if (await appSkillsFile.exists()) {
        await appSkillsFile.delete();
      }

      // 从打包资源中读取 skills.json
      final jsonString = await rootBundle.loadString('assets/test_data/skills.json');
      final data = json.decode(jsonString);
      final skills = data['skills'] as List;

      final db = await DatabaseHelper().database;
      final dao = SkillDao(db);

      // 清除现有技能数据
      await db.delete('skills');

      // 逐条插入
      for (final item in skills) {
        await dao.insert(Skill(
          skillId: item['skillId'],
          name: item['name'],
          category: item['category'],
          prerequisite: item['prerequisite'],
          promptText: item['promptText'],
          internalFunction: item['internalFunction'],
          parameters: item['parameters'],
          returnType: item['returnType'],
          description: item['description'],
          createdAt: DateTime.now(),
          lang: item['lang'] ?? 'cn',
        ));
      }

      setState(() {
        _message = '技能数据加载成功！共 ${skills.length} 条';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('技能数据加载成功！共 ${skills.length} 条')),
        );
      }
    } catch (e) {
      print('[EntryPage] 加载技能数据异常: $e');
      setState(() {
        _message = '加载失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showClearDataDialog() async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => const ClearDataDialog(),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      _isLoading = true;
      _message = '正在清除历史数据...';
    });

    try {
      final db = await DatabaseHelper().database;
      int totalDeleted = 0;
      List<String> deletedTables = [];

      if (result['all'] == true) {
        // 全部清除
        await db.delete('inbox_items');
        await db.delete('error_records');
        await db.delete('tests');
        await db.delete('questions');
        await db.delete('portfolio_items');
        await db.delete('knowledge_points');
        await db.delete('move_records');
        await db.delete('chat_messages');
        await db.delete('skills');
        deletedTables = ['全部数据'];
        totalDeleted = -1;
      } else {
        // 按栏目清除
        if (result['inbox'] == true) {
          final count = await db.delete('inbox_items');
          totalDeleted += count;
          deletedTables.add('收件箱($count条)');
        }
        if (result['errorRecords'] == true) {
          final count = await db.delete('error_records');
          totalDeleted += count;
          deletedTables.add('错题本($count条)');
        }
        if (result['tests'] == true) {
          final count1 = await db.delete('tests');
          final count2 = await db.delete('questions');
          totalDeleted += count1 + count2;
          deletedTables.add('习题集($count1条)');
        }
        if (result['portfolio'] == true) {
          final count = await db.delete('portfolio_items');
          totalDeleted += count;
          deletedTables.add('作品集($count条)');
        }
        if (result['knowledge'] == true) {
          final count = await db.delete('knowledge_points');
          totalDeleted += count;
          deletedTables.add('知识点($count条)');
        }
        if (result['chat'] == true) {
          final count = await db.delete('chat_messages');
          totalDeleted += count;
          deletedTables.add('聊天记录($count条)');
        }
        if (result['skills'] == true) {
          final count = await db.delete('skills');
          totalDeleted += count;
          deletedTables.add('技能库($count条)');
        }
      }

      setState(() {
        _message = '清除完成：${deletedTables.join("、")}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除完成：${deletedTables.join("、")}')),
        );
      }
    } catch (e) {
      setState(() {
        _message = '清除失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e'), backgroundColor: Colors.red),
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
                label: '加载技能数据',
                icon: Icons.extension,
                onPressed: _loadSkillsData,
                color: Colors.purple,
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
              const SizedBox(height: 16),
              _buildButton(
                label: '清除历史数据',
                icon: Icons.delete_forever,
                onPressed: _showClearDataDialog,
                color: Colors.red,
              ),
              const SizedBox(height: 32),
              if (_message.isNotEmpty)
                Text(
                  _message,
                  style: TextStyle(
                    color: _message.contains('完成') || _message.contains('成功') ? Colors.green : Colors.red,
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

class ClearDataDialog extends StatefulWidget {
  const ClearDataDialog({super.key});

  @override
  State<ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<ClearDataDialog> {
  bool _selectAll = false;
  bool _inbox = false;
  bool _errorRecords = false;
  bool _tests = false;
  bool _portfolio = false;
  bool _knowledge = false;
  bool _chat = false;
  bool _skills = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('清除历史数据'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请选择要清除的数据栏目：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('全选'),
              value: _selectAll,
              onChanged: (value) {
                setState(() {
                  _selectAll = value ?? false;
                  _inbox = _selectAll;
                  _errorRecords = _selectAll;
                  _tests = _selectAll;
                  _portfolio = _selectAll;
                  _knowledge = _selectAll;
                  _chat = _selectAll;
                  _skills = _selectAll;
                });
              },
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('收件箱'),
              subtitle: const Text('inbox_items 表'),
              value: _inbox,
              onChanged: (value) {
                setState(() {
                  _inbox = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            CheckboxListTile(
              title: const Text('错题本'),
              subtitle: const Text('error_records 表'),
              value: _errorRecords,
              onChanged: (value) {
                setState(() {
                  _errorRecords = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            CheckboxListTile(
              title: const Text('习题集'),
              subtitle: const Text('tests + questions 表'),
              value: _tests,
              onChanged: (value) {
                setState(() {
                  _tests = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            CheckboxListTile(
              title: const Text('作品集'),
              subtitle: const Text('portfolio_items 表'),
              value: _portfolio,
              onChanged: (value) {
                setState(() {
                  _portfolio = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            CheckboxListTile(
              title: const Text('知识点'),
              subtitle: const Text('knowledge_points 表'),
              value: _knowledge,
              onChanged: (value) {
                setState(() {
                  _knowledge = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            CheckboxListTile(
              title: const Text('聊天记录'),
              subtitle: const Text('chat_messages 表'),
              value: _chat,
              onChanged: (value) {
                setState(() {
                  _chat = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            CheckboxListTile(
              title: const Text('技能库'),
              subtitle: const Text('skills 表'),
              value: _skills,
              onChanged: (value) {
                setState(() {
                  _skills = value ?? false;
                  _updateSelectAll();
                });
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('全部清除', style: TextStyle(color: Colors.red)),
              leading: const Icon(Icons.warning, color: Colors.red),
              onTap: () {
                Navigator.pop(context, {'all': true});
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _hasSelection ? () => _confirmClear() : null,
          child: const Text('确认清除'),
        ),
      ],
    );
  }

  void _updateSelectAll() {
    _selectAll = _inbox && _errorRecords && _tests && _portfolio && _knowledge && _chat && _skills;
  }

  bool get _hasSelection =>
      _inbox || _errorRecords || _tests || _portfolio || _knowledge || _chat || _skills;

  void _confirmClear() {
    Navigator.pop(context, {
      'inbox': _inbox,
      'errorRecords': _errorRecords,
      'tests': _tests,
      'portfolio': _portfolio,
      'knowledge': _knowledge,
      'chat': _chat,
      'skills': _skills,
    });
  }
}
