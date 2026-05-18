import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlPreview extends StatefulWidget {
  final String? filePath;
  final String? htmlContent;
  final String? url;
  final bool showAppBar; // 是否显示自带的AppBar

  const HtmlPreview({
    super.key,
    this.filePath,
    this.htmlContent,
    this.url,
    this.showAppBar = true,
  });

  @override
  State<HtmlPreview> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<HtmlPreview> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('[HtmlPreview] 开始加载: $url');
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (url) {
            print('[HtmlPreview] 页面加载完成: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            print('[HtmlPreview] 加载错误: ${error.errorType}, ${error.description}');
            setState(() {
              _isLoading = false;
              _errorMessage = '${error.errorType}: ${error.description}';
            });
          },
        ),
      );

    await _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      if (widget.url != null && widget.url!.isNotEmpty) {
        print('[HtmlPreview] 从URL加载: ${widget.url}');
        await _controller.loadRequest(Uri.parse(widget.url!));
      } else if (widget.filePath != null) {
        final htmlPath = '${widget.filePath}/index.html';
        final file = File(htmlPath);
        if (await file.exists()) {
          print('[HtmlPreview] 从文件加载: $htmlPath');
          // 使用 loadHtmlString 替代 loadFile，避免文件路径问题
          final content = await file.readAsString(encoding: utf8);
          print('[HtmlPreview] 文件内容长度: ${content.length}');
          await _controller.loadHtmlString(content);
        } else {
          throw Exception('文件不存在: $htmlPath');
        }
      } else if (widget.htmlContent != null) {
        print('[HtmlPreview] 从内容加载HTML');
        await _controller.loadHtmlString(widget.htmlContent!);
      } else {
        throw Exception('没有提供有效的内容来源');
      }
    } catch (e) {
      print('[HtmlPreview] 加载失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('网页预览'),
        ),
        body: _buildBody(),
      );
    }
    return _buildBody();
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadContent,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载网页...'),
          ],
        ),
      );
    }

    return WebViewWidget(controller: _controller);
  }
}
