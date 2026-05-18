import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewExtractor extends StatefulWidget {
  final String url;
  final ValueChanged<String?> onContentExtracted;
  final Duration timeout;

  const WebViewExtractor({
    super.key,
    required this.url,
    required this.onContentExtracted,
    this.timeout = const Duration(seconds: 60),
  });

  @override
  State<WebViewExtractor> createState() => _WebViewExtractorState();
}

class _WebViewExtractorState extends State<WebViewExtractor> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasExtracted = false;
  Timer? _timeoutTimer;
  Timer? _saveTimer;
  String? _pageTitle;

  @override
  void initState() {
    super.initState();
    _initController();
    _startTimeoutTimer();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('[WebViewExtractor] 开始加载: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            print('[WebViewExtractor] 页面加载完成: $url');
            _extractPageTitle();
            _scheduleSave();
          },
          onWebResourceError: (error) {
            print('[WebViewExtractor] 加载错误: ${error.errorType}, ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(widget.timeout, () {
      if (!_hasExtracted) {
        print('[WebViewExtractor] 超时，强制保存当前页面');
        _savePageAs();
      }
    });
  }

  void _scheduleSave() {
    const saveInterval = Duration(seconds: 30);
    _saveTimer = Timer(saveInterval, () {
      _savePageAs();
    });
  }

  Future<void> _extractPageTitle() async {
    try {
      final title = await _controller.runJavaScriptReturningResult(
        'document.title',
      );
      if (title != null && title.toString().isNotEmpty) {
        _pageTitle = title.toString().replaceAll('"', '');
        print('[WebViewExtractor] 提取页面标题: $_pageTitle');
      }
    } catch (e) {
      print('[WebViewExtractor] 提取标题失败: $e');
    }
  }

  Future<void> _savePageAs() async {
    if (_hasExtracted) return;

    print('[WebViewExtractor] ========== 开始保存页面 ==========');

    try {
      if (_pageTitle == null || _pageTitle!.isEmpty) {
        await _extractPageTitle();
      }

      String fileName = _pageTitle ?? '网页内容';
      fileName = _sanitizeFileName(fileName);
      if (fileName.isEmpty) {
        fileName = '网页内容';
      }

      print('[WebViewExtractor] 正在获取HTML内容...');
      final htmlContent = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (htmlContent == null || htmlContent.toString().isEmpty) {
        print('[WebViewExtractor] ✗ 无法获取页面内容');
        _handleError();
        return;
      }

      final htmlString = htmlContent.toString().replaceAll('"', '');
      print('[WebViewExtractor] ✓ 获取页面HTML成功，长度: ${htmlString.length}');

      final appDocDir = await getApplicationDocumentsDirectory();
      final inboxDir = Directory('${appDocDir.path}/inbox/$fileName');
      await inboxDir.create(recursive: true);

      final filePath = inboxDir.path;
      print('[WebViewExtractor] ✓ 创建保存目录: $filePath');

      final htmlFile = File('$filePath/index.html');
      await htmlFile.writeAsString(htmlString, encoding: utf8);
      print('[WebViewExtractor] ✓ 保存HTML文件: ${htmlFile.path}');

      String textContent = '';
      try {
        final text = await _controller.runJavaScriptReturningResult(
          'document.body.innerText.substring(0, 10000)',
        );
        if (text != null) {
          textContent = text.toString().replaceAll('"', '');
        }
      } catch (e) {
        print('[WebViewExtractor] 提取文本失败: $e');
      }

      final mdFile = File('$filePath/content.md');
      await mdFile.writeAsString(textContent, encoding: utf8);
      print('[WebViewExtractor] ✓ 保存文本内容: ${mdFile.path}');

      final result = jsonEncode({
        'title': fileName,
        'url': widget.url,
        'filePath': filePath,
        'htmlFile': htmlFile.path,
        'textContent': textContent.length > 500 ? textContent.substring(0, 500) + '...' : textContent,
        'contentLength': textContent.length,
        'htmlLength': htmlString.length,
      });

      _hasExtracted = true;
      _timeoutTimer?.cancel();
      _saveTimer?.cancel();

      print('[WebViewExtractor] ✅ 页面保存完成');
      print('[WebViewExtractor] 标题: $fileName');
      print('[WebViewExtractor] 路径: $filePath');
      print('[WebViewExtractor] HTML长度: ${htmlString.length}');

      widget.onContentExtracted(result);
    } catch (e) {
      print('[WebViewExtractor] ✗ 保存页面失败: $e');
      _handleError();
    }
  }

  String _sanitizeFileName(String fileName) {
    final illegalChars = RegExp(r'[\\/:*?"<>|]');
    String result = fileName.replaceAll(illegalChars, '_');
    if (result.length > 100) {
      result = result.substring(0, 100);
    }
    return result.trim();
  }

  void _handleError() {
    if (_hasExtracted) return;

    _hasExtracted = true;
    _timeoutTimer?.cancel();
    _saveTimer?.cancel();
    widget.onContentExtracted(null);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleError();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('加载网页中...'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _handleError();
              Navigator.pop(context);
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.9),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在加载并保存页面...'),
                      SizedBox(height: 8),
                      Text('请耐心等待30秒让JavaScript完全执行'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
