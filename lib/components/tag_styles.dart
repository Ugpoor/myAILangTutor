import 'package:flutter/material.dart';

class TagStyles {
  static const Color knowledgeBg = Color(0xFFE3F2FD);
  static const Color knowledgeText = Color(0xFF1565C0);
  
  static const Color errorTypeBg = Color(0xFFFFE4E4);
  static const Color errorTypeText = Color(0xFFC62828);
  
  static const Color exerciseBg = Color(0xFFE8F5E9);
  static const Color exerciseText = Color(0xFF1B5E20);
  
  static const Color lessonUnitBg = Color(0xFFFFF3E0);
  static const Color lessonUnitText = Color(0xFF8D6E63);
  
  static const Color statusPendingBg = Color(0xFF424242);
  static const Color statusPendingText = Colors.white;
  
  static const Color statusCompletedBg = Color(0xFF2E7D32);
  static const Color statusCompletedText = Colors.white;
  
  static const Color statusErrorBg = Color(0xFFC62828);
  static const Color statusErrorText = Colors.white;

  static TextStyle tagTextStyle = const TextStyle(fontSize: 11);
  
  static Widget buildTag({
    required String text,
    required Color bgColor,
    required Color textColor,
    TextStyle? style,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: style ?? tagTextStyle.copyWith(color: textColor),
      ),
    );
  }
  
  static Widget knowledgeTag(String text) {
    return buildTag(
      text: text,
      bgColor: knowledgeBg,
      textColor: knowledgeText,
    );
  }
  
  static Widget errorTypeTag(String text) {
    return buildTag(
      text: text,
      bgColor: errorTypeBg,
      textColor: errorTypeText,
    );
  }
  
  static Widget exerciseTag(String text) {
    return buildTag(
      text: text,
      bgColor: exerciseBg,
      textColor: exerciseText,
    );
  }
  
  static Widget lessonUnitTag(String text) {
    return buildTag(
      text: text,
      bgColor: lessonUnitBg,
      textColor: lessonUnitText,
    );
  }
  
  static Widget statusTag(String text, String status) {
    Color bgColor;
    Color textColor;
    
    switch (status) {
      case '已订正':
      case 'completed':
      case '已批阅':
      case '已完成':
        bgColor = statusCompletedBg;
        textColor = statusCompletedText;
        break;
      case '待订正':
      case 'pending':
      case '未开始':
      case '未批阅':
        bgColor = statusPendingBg;
        textColor = statusPendingText;
        break;
      case '错误':
      case 'error':
        bgColor = statusErrorBg;
        textColor = statusErrorText;
        break;
      case '进行中':
      case 'doing':
        bgColor = const Color(0xFFFF9800);
        textColor = Colors.white;
        break;
      case '学习中':
        bgColor = const Color(0xFF2196F3);
        textColor = Colors.white;
        break;
      default:
        bgColor = statusPendingBg;
        textColor = statusPendingText;
    }
    
    return buildTag(
      text: text,
      bgColor: bgColor,
      textColor: textColor,
      style: tagTextStyle.copyWith(color: textColor, fontWeight: FontWeight.bold),
    );
  }
}