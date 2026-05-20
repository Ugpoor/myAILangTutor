import 'package:flutter/material.dart';

/// 统一标签颜色常量 - 全应用通用
class LabelColors {
  // 知识点标签：褐色字黄色底
  static const knowledgeTagColor = Color(0xFF8B4513); // 褐色
  static const knowledgeTagBg = Color(0xFFFFFACD);    // 黄色

  // 习题标签：深绿字淡绿底
  static const exerciseTagColor = Color(0xFF006400);  // 深绿
  static const exerciseTagBg = Color(0xFFF0FFF0);     // 淡绿

  // 错类标签：深红字淡橘色底
  static const errorTypeColor = Color(0xFF8B0000);    // 深红
  static const errorTypeBg = Color(0xFFFFE4E1);       // 淡橘

  // 课内标签：深蓝字淡蓝底
  static const lessonUnitColor = Color(0xFF00008B);   // 深蓝
  static const lessonUnitBg = Color(0xFFE0F0FF);      // 淡蓝
}

/// 紧凑标签 Widget（一行2-3个）
class ColoredLabel extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color bgColor;

  const ColoredLabel._({
    required this.text,
    required this.textColor,
    required this.bgColor,
  });

  /// 知识点标签
  factory ColoredLabel.knowledge(String text) {
    return ColoredLabel._(
      text: text,
      textColor: LabelColors.knowledgeTagColor,
      bgColor: LabelColors.knowledgeTagBg,
    );
  }

  /// 习题标签
  factory ColoredLabel.exercise(String text) {
    return ColoredLabel._(
      text: text,
      textColor: LabelColors.exerciseTagColor,
      bgColor: LabelColors.exerciseTagBg,
    );
  }

  /// 错类标签
  factory ColoredLabel.errorType(String text) {
    return ColoredLabel._(
      text: text,
      textColor: LabelColors.errorTypeColor,
      bgColor: LabelColors.errorTypeBg,
    );
  }

  /// 课内标签
  factory ColoredLabel.lessonUnit(String text) {
    return ColoredLabel._(
      text: text,
      textColor: LabelColors.lessonUnitColor,
      bgColor: LabelColors.lessonUnitBg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// 紧凑标签行容器（支持一行2-3个标签自动换行）
class ColoredLabelRow extends StatelessWidget {
  final List<Widget> labels;

  const ColoredLabelRow({
    super.key,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: labels,
    );
  }
}
