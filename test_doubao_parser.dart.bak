import 'dart:io';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

void main() async {
  print('=== 豆包页面分析工具 ===\n');

  // 检查是否有本地保存的HTML文件
  final testFile = File('test_doubao_page.html');
  String? htmlContent;

  if (await testFile.exists()) {
    print('✅ 读取本地测试文件: ${testFile.path}');
    htmlContent = await testFile.readAsString(encoding: utf8);
  } else {
    print('❌ 未找到测试文件，请先保存目标页面为 test_doubao_page.html');
    print('请访问: https://www.doubao.com/thread/aa6a9c55effc9 并保存HTML');
    return;
  }

  print('\n=== 开始分析页面结构 ===\n');

  try {
    // 解析HTML
    final document = html.parse(htmlContent);
    final body = document.body;

    if (body == null) {
      print('❌ 无法找到 <body> 标签');
      return;
    }

    // 1. 打印页面结构概要
    print('📄 页面大小: ${htmlContent.length} 字符');
    print('\n🔍 查找标题标签:');

    // 分析标题
    final h1Tags = body.querySelectorAll('h1');
    final h2Tags = body.querySelectorAll('h2');
    final h3Tags = body.querySelectorAll('h3');

    print('  H1标签: ${h1Tags.length} 个');
    for (var i = 0; i < h1Tags.length; i++) {
      print('    [$i] ${_getText(h1Tags[i])}');
    }

    print('\n  H2标签: ${h2Tags.length} 个');
    for (var i = 0; i < h2Tags.length; i++) {
      print('    [$i] ${_getText(h2Tags[i])}');
    }

    print('\n  H3标签: ${h3Tags.length} 个');
    for (var i = 0; i < h3Tags.length; i++) {
      print('    [$i] ${_getText(h3Tags[i])}');
    }

    // 分析多媒体
    print('\n🎬 查找多媒体内容:');
    final imgTags = body.querySelectorAll('img');
    final videoTags = body.querySelectorAll('video');
    final audioTags = body.querySelectorAll('audio');

    print('  图片: ${imgTags.length} 个');
    for (var i = 0; i < imgTags.length && i < 5; i++) {
      final src = imgTags[i].attributes['src'] ?? '无src';
      final alt = imgTags[i].attributes['alt'] ?? '无alt';
      print('    [$i] $alt -> $src');
    }

    print('\n  视频: ${videoTags.length} 个');
    print('\n  音频: ${audioTags.length} 个');

    // 查找可能的内容容器（豆包页面特点）
    print('\n📦 查找内容容器:');
    final possibleContainers = [
      'div[id*="content"]',
      'div[class*="content"]',
      'div[id*="thread"]',
      'div[class*="thread"]',
      'article',
      'main',
    ];

    for (final selector in possibleContainers) {
      final elements = body.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        print('  ✅ 找到 $selector: ${elements.length} 个');
        for (var i = 0; i < elements.length && i < 2; i++) {
          final text = _getText(elements[i]);
          if (text.length > 50) {
            print('    [$i] 内容预览: ${text.substring(0, 50)}...');
          }
        }
      }
    }

    // 2. 查找包含关键词的文本
    print('\n🔍 关键词检查:');
    final allText = body.text;
    final hasLaoShe = allText.contains('老舍');
    final hasMao = allText.contains('猫');

    print('  包含"老舍": ${hasLaoShe ? '✅' : '❌'}');
    print('  包含"猫": ${hasMao ? '✅' : '❌'}');

    // 3. 尝试提取正文内容（简单版本）
    print('\n📝 简单正文提取测试:');

    // 方法1: 直接获取 body 文本
    print('\n[方法1] 直接body文本:');
    final bodyText = body.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (bodyText.length > 200) {
      print(bodyText.substring(0, 200) + '...');
    } else {
      print(bodyText);
    }
    print('长度: ${bodyText.length}');
    print('包含老舍: ${bodyText.contains('老舍')}');
    print('包含猫: ${bodyText.contains('猫')}');

    // 方法2: 查找可能的文本容器
    print('\n[方法2] 查找文本段落:');
    final pTags = body.querySelectorAll('p');
    print('找到 ${pTags.length} 个 <p> 标签');

    final buffer = StringBuffer();
    for (final p in pTags) {
      final text = p.text.trim();
      if (text.length > 10) {
        buffer.writeln('📄 $text');
      }
    }

    if (buffer.length > 0) {
      print('\n段落内容预览:');
      print(buffer.toString().substring(0, buffer.length > 500 ? 500 : buffer.length));
    }

    // 4. 查找包含目标关键词的元素
    print('\n🔎 查找包含目标词的元素:');
    final elementsWithKeywords = <dom.Element>[];

    for (final element in body.querySelectorAll('*')) {
      final text = element.text;
      if (text.contains('老舍') || text.contains('猫')) {
        if (element.children.isEmpty || element.children.length < 5) {
          elementsWithKeywords.add(element);
        }
      }
    }

    print('找到 ${elementsWithKeywords.length} 个包含关键词的元素');
    for (var i = 0; i < elementsWithKeywords.length && i < 10; i++) {
      final el = elementsWithKeywords[i];
      print('  [$i] <${el.localName}>: ${el.text.replaceAll('\n', ' ').substring(0, el.text.length > 50 ? 50 : el.text.length)}');
    }

  } catch (e) {
    print('❌ 分析出错: $e');
    print(StackTrace.current);
  }

  print('\n=== 分析完成 ===');
}

String _getText(dom.Element element) {
  try {
    final text = element.text.replaceAll('\n', ' ').trim();
    return text.length > 50 ? text.substring(0, 50) + '...' : text;
  } catch (e) {
    return '<错误>';
  }
}
