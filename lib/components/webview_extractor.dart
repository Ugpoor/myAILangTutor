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
  Timer? _monitorTimer;
  String? _pageTitle;
  int _checkCount = 0;
  int _stableCount = 0;
  int _lastFileSize = 0;
  final int _maxChecks = 30; // 最多检查30次（每次2秒，共60秒）
  final int _stableThreshold = 3; // 连续3次稳定
  final int _minContentLength = 3000; // 最小内容长度
  final int _sizeChangeThreshold = 100; // 文件大小变化阈值

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
            _startContentMonitoring();
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

  void _startContentMonitoring() {
    _checkContent();
  }

  Future<void> _checkContent() async {
    if (_hasExtracted) return;

    try {
      _checkCount++;
      print('[WebViewExtractor] ========== 第 $_checkCount 次内容检查 ==========');

      // 获取当前页面innerText长度，用于判断页面稳定
      final result = await _controller.runJavaScriptReturningResult(
        'document.body.innerText.length',
      );

      int currentSize = 0;
      if (result is int) {
        currentSize = result;
      } else if (result is String) {
        currentSize = int.tryParse(result) ?? 0;
      }

      print('[WebViewExtractor] 当前文本大小: ${_formatFileSize(currentSize)}');

      // 检查稳定性
      final sizeDiff = (currentSize - _lastFileSize).abs();
      print('[WebViewExtractor] 大小变化: ${sizeDiff} 字节');

      if (_lastFileSize > 0) {
        if (sizeDiff < _sizeChangeThreshold) {
          _stableCount++;
          print('[WebViewExtractor] 稳定计数: $_stableCount');

          // 如果连续3次稳定且长度足够
          if (_stableCount >= _stableThreshold && currentSize >= _minContentLength) {
            print('[WebViewExtractor] ✅ 内容稳定，开始保存');
            _savePageAs();
            return;
          }
        } else {
          _stableCount = 0;
          print('[WebViewExtractor] 内容仍在变化');
        }
      }

      _lastFileSize = currentSize;

      // 检查是否达到最大检查次数
      if (_checkCount >= _maxChecks) {
        print('[WebViewExtractor] ⏱️ 已达到最大检查次数，强制保存');
        _savePageAs();
        return;
      }

      _scheduleNextCheck();
    } catch (e) {
      print('[WebViewExtractor] 检查出错: $e');
      _scheduleNextCheck();
    }
  }

  void _scheduleNextCheck() {
    if (_hasExtracted) return;

    _monitorTimer?.cancel();
    _monitorTimer = Timer(const Duration(seconds: 2), () {
      _checkContent();
    });
    print('[WebViewExtractor] 2秒后进行下一次检查...');
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

      print('[WebViewExtractor] 获取完整HTML...');
      final rawHtml = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      if (rawHtml == null || rawHtml.toString().isEmpty) {
        print('[WebViewExtractor] ✗ 无法获取HTML');
        _handleError();
        return;
      }

      final htmlString = rawHtml.toString();

      final appDocDir = await getApplicationDocumentsDirectory();
      
      // 使用时间戳 + 随机字符串作为目录名，确保绝对唯一性
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomString = _generateRandomString(8);
      final directoryName = '$timestamp-$randomString';
      
      final inboxDir = Directory('${appDocDir.path}/inbox/$directoryName');
      await inboxDir.create(recursive: true);

      final filePath = inboxDir.path;
      print('[WebViewExtractor] ✓ 创建保存目录: $filePath');

      // 解码Unicode转义字符
      final decodedHtml = _decodeUnicodeEscapes(htmlString);

      // 只保存原始HTML
      final htmlFile = File('$filePath/index.html');
      await htmlFile.writeAsString(decodedHtml, encoding: utf8);
      print('[WebViewExtractor] ✓ 保存HTML文件: ${htmlFile.path}');

      final result = jsonEncode({
        'title': fileName,
        'url': widget.url,
        'filePath': filePath,
        'htmlFile': htmlFile.path,
        'textContent': decodedHtml.substring(0, decodedHtml.length > 5000 ? 5000 : decodedHtml.length),
        'htmlLength': htmlString.length,
        'checkCount': _checkCount,
      });

      _hasExtracted = true;
      _timeoutTimer?.cancel();
      _monitorTimer?.cancel();

      print('[WebViewExtractor] ✅ 页面保存完成');
      print('[WebViewExtractor] 标题: $fileName');
      print('[WebViewExtractor] 路径: $filePath');
      print('[WebViewExtractor] HTML长度: ${htmlString.length}');
      print('[WebViewExtractor] 检查次数: $_checkCount');
      print('[WebViewExtractor] 准备调用回调 onContentExtracted');

      try {
        widget.onContentExtracted(result);
        print('[WebViewExtractor] ✅ 回调调用成功');
      } catch (e) {
        print('[WebViewExtractor] ❌ 回调调用失败: $e');
      }
    } catch (e) {
      print('[WebViewExtractor] ✗ 保存失败: $e');
      _handleError();
    }
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String result = '';
    for (int i = 0; i < length; i++) {
      final randomIndex = DateTime.now().microsecondsSinceEpoch % chars.length;
      result += chars[randomIndex];
      // 添加微小延迟确保随机
      Future.delayed(const Duration(microseconds: 1));
    }
    return result;
  }

  String _sanitizeFileName(String fileName) {
    final illegalChars = RegExp(r'[\\/:*?"<>|]');
    String result = fileName.replaceAll(illegalChars, '_');
    if (result.length > 100) {
      result = result.substring(0, 100);
    }
    return result.trim();
  }

  String _decodeUnicodeEscapes(String input) {
    String result = input;
    // 解码Unicode转义字符 (\u003C -> <)
    result = result.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
    // 删除显式的换行符 (\n 和 \\n)
    result = result.replaceAll(r'\n', '');
    result = result.replaceAll(r'\\n', '');
    // 删除显式的回车符 (\r 和 \\r)
    result = result.replaceAll(r'\r', '');
    result = result.replaceAll(r'\\r', '');
    // 删除显式的制表符 (\t 和 \\t)
    result = result.replaceAll(r'\t', '');
    result = result.replaceAll(r'\\t', '');
    // 修复转义的反斜杠 (\\\\ -> \\)
    result = result.replaceAll(r'\\\\', r'\\');
    // 修复双重转义的引号 (\\" -> ")
    result = result.replaceAll('\\"', '"');
    return result;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    }
  }

  void _handleError() {
    if (_hasExtracted) return;

    _hasExtracted = true;
    _timeoutTimer?.cancel();
    _monitorTimer?.cancel();
    widget.onContentExtracted(null);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _monitorTimer?.cancel();
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('正在加载并保存页面...'),
                      const SizedBox(height: 8),
                      Text(
                        '检测中 (${_checkCount}/${_maxChecks})',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '内容大小: ${_formatFileSize(_lastFileSize)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '稳定计数: ${_stableCount}/${_stableThreshold}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _stableCount >= _stableThreshold ? Colors.green : Colors.grey[500],
                        ),
                      ),
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
