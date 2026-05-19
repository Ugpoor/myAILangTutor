#!/usr/bin/env dart

/// 习题集数学题清理脚本
/// 
/// 使用方法：需要 Flutter SDK 支持
/// 运行方式：flutter pub run scripts/clean_math_exercises.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  print('========================================');
  print('     习题集数学题清理工具');
  print('========================================\n');

  try {
    // 获取数据库路径
    final dbPath = await getDatabasesPath();
    final databasePath = '$dbPath/myAILangTutor.db';
    
    print('📁 数据库路径: $databasePath\n');

    final file = File(databasePath);
    if (!await file.exists()) {
      print('❌ 错误：数据库文件不存在！\n');
      exit(1);
    }

    // 打开数据库
    final db = await openDatabase(databasePath);
    print('✅ 数据库连接成功\n');

    // 1. 显示清理前统计
    print('【步骤 1/5】清理前统计');
    print('----------------------------------------');
    final beforeCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    print('总习题数: $beforeCount\n');

    // 2. 预览数学相关习题
    print('【步骤 2/5】扫描数学相关习题');
    print('----------------------------------------');
    
    const mathKeywords = [
      '分数', '计算', '运算', '加减', '乘除', '方程', '几何', '代数',
      '函数', '三角', '面积', '周长', '整数', '小数', '百分',
      '3/4', '1/4', '2/5', '5/6', '1/2', '7/8', 'π', '勾股', '二次',
    ];

    int totalMathCount = 0;
    Map<String, int> keywordCounts = {};

    for (final keyword in mathKeywords) {
      final results = await db.rawQuery(
        "SELECT id, exercise_id, question, knowledge_tag FROM exercises WHERE "
        "(question LIKE ? OR exam_paper LIKE ? OR knowledge_tag LIKE ?)",
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      
      if (results.isNotEmpty) {
        keywordCounts[keyword] = results.length;
        totalMathCount += results.length;
        
        if (totalMathCount <= 50) {
          print('\n关键词 "$keyword" (${results.length}条):');
          for (final r in results.take(5)) {
            final exId = r['exercise_id'] as String? ?? '';
            final question = r['question'] as String? ?? '';
            print('  [$exId] $question');
          }
          if (results.length > 5) {
            print('  ... 还有 ${results.length - 5} 条');
          }
        }
      }
    }

    print('\n------------------------');
    print('匹配到的数学题记录数: $totalMathCount (可能重复)\n');

    // 3. 检查重复习题
    print('【步骤 3/5】检查重复习题');
    print('----------------------------------------');
    
    final duplicateById = await db.rawQuery(
      """
      SELECT COUNT(*) as count
      FROM exercises
      WHERE exercise_id IS NOT NULL AND exercise_id != ''
      GROUP BY exercise_id
      HAVING COUNT(*) > 1
      """,
    );
    final dupByIdCount = Sqflite.firstIntValue(duplicateById) ?? 0;
    print('exercise_id 重复组数: $dupByIdCount');

    final duplicateByContent = await db.rawQuery(
      """
      SELECT COUNT(*) as count
      FROM exercises
      WHERE exam_paper IS NOT NULL AND exam_paper != ''
      GROUP BY exam_paper
      HAVING COUNT(*) > 1
      """,
    );
    final dupByContentCount = Sqflite.firstIntValue(duplicateByContent) ?? 0;
    print('exam_paper 内容重复组数: $dupByContentCount\n');

    // 4. 执行删除
    print('【步骤 4/5】执行删除操作');
    print('----------------------------------------');
    
    int deletedMath = 0;
    for (final keyword in mathKeywords) {
      final result = await db.rawDelete(
        "DELETE FROM exercises WHERE "
        "(question LIKE ? OR exam_paper LIKE ? OR knowledge_tag LIKE ?)",
        ['%$keyword%', '%$keyword%', '%$keyword%'],
      );
      deletedMath += result;
    }
    print('✅ 已删除数学相关习题: $deletedMath 条');

    int deletedDupById = 0;
    final dupRowsById = await db.rawQuery(
      """
      SELECT MIN(id) as keep_id, GROUP_CONCAT(id) as all_ids
      FROM exercises
      WHERE exercise_id IS NOT NULL AND exercise_id != ''
      GROUP BY exercise_id
      HAVING COUNT(*) > 1
      """,
    );
    for (final row in dupRowsById) {
      final keepId = Sqflite.firstIntValue(row['keep_id'] as List? ?? []);
      final allIdsStr = row['all_ids'] as String?;
      if (keepId != null && allIdsStr != null) {
        final ids = (allIdsStr as String).split(',').map(int.parse)
            .where((id) => id != keepId).toList();
        for (final id in ids) {
          await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
          deletedDupById++;
        }
      }
    }
    print('✅ 已删除 exercise_id 重复: $deletedDupById 条');

    int deletedDupByContent = 0;
    final dupRowsByContent = await db.rawQuery(
      """
      SELECT MIN(id) as keep_id, GROUP_CONCAT(id) as all_ids
      FROM exercises
      WHERE exam_paper IS NOT NULL AND exam_paper != ''
      GROUP BY exam_paper
      HAVING COUNT(*) > 1
      """,
    );
    for (final row in dupRowsByContent) {
      final keepId = Sqflite.firstIntValue(row['keep_id'] as List? ?? []);
      final allIdsStr = row['all_ids'] as String?;
      if (keepId != null && allIdsStr != null) {
        final ids = (allIdsStr as String).split(',').map(int.parse)
            .where((id) => id != keepId).toList();
        for (final id in ids) {
          await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
          deletedDupByContent++;
        }
      }
    }
    print('✅ 已删除 exam_paper 重复: $deletedDupByContent 条');

    // 5. 清理后统计
    print('\n------------------------');
    print('【步骤 5/5】清理完成统计');
    print('----------------------------------------');
    
    final afterCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    
    print('清理后剩余习题数: $afterCount');
    print('总计删除: ${beforeCount - afterCount} 条');
    print('  - 数学题: $deletedMath 条');
    print('  - exercise_id 重复: $deletedDupById 条');
    print('  - exam_paper 重复: $deletedDupByContent 条');

    await db.close();
    
    print('\n========================================');
    print('✅ 清理完成！');
    print('========================================\n');
  } catch (e) {
    print('\n❌ 错误: $e');
    exit(1);
  }
}
