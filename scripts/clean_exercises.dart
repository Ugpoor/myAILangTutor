import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 习题集清理脚本：删除数学题 + 排重
/// 
/// 使用方法：在任意地方调用 [main()] 即可执行清理

Future<void> main() async {
  print('=== 习题集数据清理工具 ===\n');

  try {
    // 获取数据库路径
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/myAILangTutor.db';
    print('数据库路径: $path\n');

    final file = File(path);
    if (!await file.exists()) {
      print('错误：数据库文件不存在！\n');
      return;
    }

    // 打开数据库
    final db = await openDatabase(path);

    // 1. 显示当前所有习题统计
    print('【清理前统计】');
    final beforeCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    print('总习题数: $beforeCount\n');

    // 2. 显示数学相关习题（清理前预览）
    const mathKeywords = [
      '分数', '计算', '运算', '加减', '乘除', '方程', '几何', '代数',
      '函数', '三角', '面积', '周长', '整数', '小数', '百分',
      '3/4', '1/4', '2/5', '5/6', '1/2', '7/8',
    ];

    int mathCount = 0;
    for (final keyword in mathKeywords) {
      final results = await db.rawQuery(
        "SELECT id, exercise_id, question, knowledge_tag FROM exercises WHERE "
        "(question LIKE ? OR exam_paper LIKE ? OR knowledge_tag LIKE ?)",
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      if (results.isNotEmpty) {
        mathCount += results.length;
        print('匹配关键词 "$keyword" 的习题 (${results.length}条):');
        for (final r in results) {
          print('  [${r['exercise_id']}] ${r['question']}');
          if (r['knowledge_tag'] != null) print('    知识标签: ${r['knowledge_tag']}');
        }
        print('');
      }
    }
    print('数学相关习题总数: $mathCount\n');

    // 3. 检查重复习题
    print('【重复习题检查】');
    
    // 基于 exercise_id 的重复
    final duplicateById = await db.rawQuery(
      """
      SELECT exercise_id, GROUP_CONCAT(id || ' (' || exercise_id || ')') as ids
      FROM exercises
      WHERE exercise_id IS NOT NULL AND exercise_id != ''
      GROUP BY exercise_id
      HAVING COUNT(*) > 1
      """,
    );

    int dupByIdCount = 0;
    for (final row in duplicateById) {
      final idStr = row['ids'] as String? ?? '';
      final count = idStr.split(',').length;
      if (count > 1) {
        dupByIdCount++;
        print('  exercise_id="${row['exercise_id']}" 有 $count 条重复');
      }
    }

    // 基于 exam_paper 内容的重复
    final duplicateByContent = await db.rawQuery(
      """
      SELECT SUBSTR(exam_paper, 1, 50) as preview, GROUP_CONCAT(id || ' (' || exercise_id || ')') as ids
      FROM exercises
      WHERE exam_paper IS NOT NULL AND exam_paper != ''
      GROUP BY exam_paper
      HAVING COUNT(*) > 1
      """,
    );

    int dupByContentCount = 0;
    for (final row in duplicateByContent) {
      final idStr = row['ids'] as String? ?? '';
      final count = idStr.split(',').length;
      if (count > 1) {
        dupByContentCount++;
        print('  exam_paper 内容相同: "${row['preview']}..." 有 $count 条');
      }
    }
    print('共发现 $dupByIdCount 组 exercise_id 重复，$dupByContentCount 组内容重复\n');

    // 4. 确认是否执行清理
    print('准备执行清理...');
    print('- 将删除 $mathCount 条数学相关习题');
    print('- 将删除重复习题');
    print('');

    // 实际执行删除
    print('【执行清理】');

    // 删除数学相关习题
    int deletedMath = 0;
    for (final keyword in mathKeywords) {
      final result = await db.rawDelete(
        "DELETE FROM exercises WHERE "
        "(question LIKE ? OR exam_paper LIKE ? OR knowledge_tag LIKE ?)",
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      deletedMath += result;
    }
    print('已删除 $deletedMath 条数学相关习题');

    // 删除重复习题（基于 exercise_id）
    int deletedDupById = 0;
    for (final row in duplicateById) {
      final keepId = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT MIN(id) FROM exercises WHERE exercise_id = ?",
          [row['exercise_id']],
        ),
      );
      if (keepId != null) {
        final deleted = await db.delete(
          'exercises',
          where: 'exercise_id = ? AND id != ?',
          whereArgs: [row['exercise_id'], keepId],
        );
        deletedDupById += deleted;
      }
    }

    // 删除重复习题（基于 exam_paper 内容）
    int deletedDupByContent = 0;
    for (final row in duplicateByContent) {
      final keepId = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT MIN(id) FROM exercises WHERE exam_paper = ?",
          [row['preview']],
        ),
      );
      if (keepId != null) {
        final deleted = await db.delete(
          'exercises',
          where: 'exam_paper = ? AND id != ?',
          whereArgs: [row['preview'], keepId],
        );
        deletedDupByContent += deleted;
      }
    }

    print('已删除 $deletedDupById 条 exercise_id 重复习题');
    print('已删除 $deletedDupByContent 条 exam_paper 内容重复习题');

    // 5. 清理后统计
    print('\n【清理后统计】');
    final afterCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    print('剩余习题数: $afterCount');
    print('总计删除: ${beforeCount - afterCount} 条');

    await db.close();
    print('\n=== 清理完成 ===');
  } catch (e) {
    print('错误: $e');
  }
}
