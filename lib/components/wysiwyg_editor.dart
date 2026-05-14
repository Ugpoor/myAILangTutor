import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WysiwygEditor extends StatefulWidget {
  final String? initialContent;
  final Function(String)? onContentChanged;
  final Function(bool)? onFocusChanged;
  final String lang;

  const WysiwygEditor({
    super.key,
    this.initialContent,
    this.onContentChanged,
    this.onFocusChanged,
    this.lang = 'cn',
  });

  @override
  State<WysiwygEditor> createState() => WysiwygEditorState();
}

class WysiwygEditorState extends State<WysiwygEditor> with SingleTickerProviderStateMixin {
  String _content = '';
  String _lastValidContent = '';
  bool _hasError = false;
  late TabController _tabController;
  final List<Tab> _tabs = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isEditorFocused = false;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _content = widget.initialContent ?? '';
    _lastValidContent = _content;
    _textController.text = _content;
    _tabs.add(Tab(text: widget.lang == 'cn' ? '预览' : 'Preview'));
    _tabs.add(Tab(text: widget.lang == 'cn' ? '编辑' : 'Edit'));
    _tabController = TabController(length: 2, vsync: this);
    _editorFocusNode.addListener(_onEditorFocusChange);
    _initWebViewController();
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_buildHtmlContent(_content));
  }

  String _buildHtmlContent(String content) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      box-sizing: border-box;
    }
    html, body {
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      font-size: 16px;
      line-height: 1.6;
      color: #333;
      width: 100%;
      max-width: 100%;
      overflow-x: hidden;
    }
    h1 {
      font-size: 24px;
      font-weight: bold;
      margin: 16px 0;
      color: #1a1a1a;
    }
    h2 {
      font-size: 20px;
      font-weight: bold;
      margin: 12px 0;
      color: #2a2a2a;
    }
    h3 {
      font-size: 18px;
      font-weight: bold;
      margin: 10px 0;
      color: #3a3a3a;
    }
    p {
      margin: 10px 0;
    }
    img {
      max-width: 100%;
      height: auto;
      margin: 8px 0;
      border-radius: 4px;
    }
    video {
      max-width: 100%;
      height: auto;
      margin: 8px 0;
      border-radius: 4px;
    }
    .container {
      padding: 16px;
      width: 100%;
    }
  </style>
</head>
<body>
  <div class="container">
    $content
  </div>
</body>
</html>
''';
  }

  void _onEditorFocusChange() {
    setState(() {
      _isEditorFocused = _editorFocusNode.hasFocus;
    });
    if (_isEditorFocused && widget.onFocusChanged != null) {
      widget.onFocusChanged!(true);
    } else if (!_isEditorFocused && widget.onFocusChanged != null) {
      widget.onFocusChanged!(false);
    }
  }

  void _onContentChanged(String text) {
    setState(() {
      _content = text;
      _hasError = false;
      _lastValidContent = text;
    });
    _webViewController.loadHtmlString(_buildHtmlContent(text));
    if (widget.onContentChanged != null) {
      widget.onContentChanged!(text);
    }
  }

  void _restoreLastValid() {
    setState(() {
      _content = _lastValidContent;
      _textController.text = _content;
      _hasError = false;
    });
    _webViewController.loadHtmlString(_buildHtmlContent(_content));
    if (widget.onContentChanged != null) {
      widget.onContentChanged!(_content);
    }
  }

  void _insertHeading(int level) {
    final headingText = widget.lang == 'cn' ? '标题内容' : 'Heading content';
    final tag = '<h$level>$headingText</h$level>';
    _insertTextAtCursor(tag);
  }

  void _insertImage() {
    _insertTextAtCursor('<img src="image_url">');
  }

  void _insertVideo() {
    _insertTextAtCursor('<video src="video_url" controls></video>');
  }

  void _insertTextAtCursor(String text) {
    final controller = _textController;
    final selection = controller.selection;

    if (selection.start == selection.end) {
      controller.text = controller.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      controller.selection = TextSelection.collapsed(
        offset: selection.start + text.length,
      );
    } else {
      controller.text = controller.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      controller.selection = TextSelection.collapsed(
        offset: selection.start + text.length,
      );
    }

    _onContentChanged(controller.text);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _editorFocusNode.removeListener(_onEditorFocusChange);
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_hasError) _buildErrorBar(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPreview(),
              _buildEditor(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        tabs: _tabs,
        indicatorColor: Colors.pink,
        labelColor: Colors.pink,
        unselectedLabelColor: Colors.grey,
      ),
    );
  }

  Widget _buildErrorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.red[100],
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(widget.lang == 'cn' ? '渲染错误，请恢复到上一个正确版本' : 'Render error, please restore to last valid version'),
          const Spacer(),
          TextButton(
            onPressed: _restoreLastValid,
            child: Text(widget.lang == 'cn' ? '恢复' : 'Restore'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          _buildTagButton('H1', () => _insertHeading(1)),
          _buildTagButton('H2', () => _insertHeading(2)),
          _buildTagButton('H3', () => _insertHeading(3)),
          const SizedBox(width: 8),
          _buildTagButton('📷', _insertImage),
          _buildTagButton('🎬', _insertVideo),
        ],
      ),
    );
  }

  Widget _buildTagButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: const Key('editor-text-field'),
              controller: _textController,
              focusNode: _editorFocusNode,
              onChanged: _onContentChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '在这里输入HTML内容...',
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black),
              cursorColor: Colors.blue,
              showCursor: true,
              maxLines: null,
              minLines: 10,
              keyboardType: TextInputType.multiline,
              enableInteractiveSelection: true,
              autofocus: false,
              enabled: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return WebViewWidget(controller: _webViewController);
  }
}
