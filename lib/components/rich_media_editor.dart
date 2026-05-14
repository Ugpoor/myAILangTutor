import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum TextFormat {
  normal,
  h1,
  h2,
  h3,
  bold,
  italic,
  underline,
}

class RichMediaEditor extends StatefulWidget {
  final String? initialContent;
  final TextEditingController? controller;
  final ValueChanged<String>? onContentChanged;
  final String lang;
  final bool showHtmlMarkup;
  final FocusNode? focusNode;

  const RichMediaEditor({
    super.key,
    this.initialContent,
    this.controller,
    this.onContentChanged,
    this.lang = 'cn',
    this.showHtmlMarkup = false,
    this.focusNode,
  });

  @override
  State<RichMediaEditor> createState() => _RichMediaEditorState();
}

class _RichMediaEditorState extends State<RichMediaEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.initialContent != null && widget.controller == null) {
      _controller.text = widget.initialContent!;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    widget.onContentChanged?.call(_controller.text);
  }

  void _insertFormat(TextFormat format) {
    final text = _controller.text;
    final selection = _controller.selection;
    final selectedText = selection.textInside(text);

    String prefix, suffix;
    switch (format) {
      case TextFormat.h1:
        prefix = '<h1>';
        suffix = '</h1>';
        break;
      case TextFormat.h2:
        prefix = '<h2>';
        suffix = '</h2>';
        break;
      case TextFormat.h3:
        prefix = '<h3>';
        suffix = '</h3>';
        break;
      case TextFormat.bold:
        prefix = '<strong>';
        suffix = '</strong>';
        break;
      case TextFormat.italic:
        prefix = '<em>';
        suffix = '</em>';
        break;
      case TextFormat.underline:
        prefix = '<u>';
        suffix = '</u>';
        break;
      default:
        return;
    }

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );

    _controller.text = newText;

    final newPosition = selection.start + prefix.length + selectedText.length;
    _controller.selection = TextSelection.collapsed(offset: newPosition);

    _focusNode.requestFocus();
  }

  Future<void> _insertImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imagePath = pickedFile.path;
      final selection = _controller.selection;
      final imageHtml = '<img src="$imagePath">';

      final newText = _controller.text.replaceRange(
        selection.start,
        selection.end,
        imageHtml,
      );

      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: selection.start + imageHtml.length);
      _focusNode.requestFocus();
    }
  }

  Future<void> _insertVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      final videoPath = pickedFile.path;
      final selection = _controller.selection;
      final videoHtml = '<video src="$videoPath"></video>';

      final newText = _controller.text.replaceRange(
        selection.start,
        selection.end,
        videoHtml,
      );

      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: selection.start + videoHtml.length);
      _focusNode.requestFocus();
    }
  }

  Future<void> _insertAudio() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final audioPath = pickedFile.path;
      final selection = _controller.selection;
      final audioHtml = '<audio src="$audioPath"></audio>';

      final newText = _controller.text.replaceRange(
        selection.start,
        selection.end,
        audioHtml,
      );

      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: selection.start + audioHtml.length);
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: widget.showHtmlMarkup
                  ? _ProtectedHtmlEditor(
                      controller: _controller,
                      focusNode: _focusNode,
                      lang: widget.lang,
                    )
                  : _buildBasicEditor(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicEditor() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: widget.lang == 'cn'
            ? '开始编辑内容...'
            : 'Start editing...',
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      style: const TextStyle(fontSize: 16),
      showCursor: true,
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFormatButton(Icons.title, TextFormat.h1, 'H1'),
            _buildFormatButton(Icons.title_outlined, TextFormat.h2, 'H2'),
            _buildFormatButton(Icons.subtitles, TextFormat.h3, 'H3'),
            const SizedBox(width: 4),
            _buildFormatButton(Icons.format_bold, TextFormat.bold, 'B'),
            _buildFormatButton(Icons.format_italic, TextFormat.italic, 'I'),
            _buildFormatButton(Icons.format_underline, TextFormat.underline, 'U'),
            const SizedBox(width: 4),
            const VerticalDivider(width: 1, thickness: 1),
            const SizedBox(width: 4),
            _buildMediaButton(Icons.image, _insertImage),
            _buildMediaButton(Icons.video_library, _insertVideo),
            _buildMediaButton(Icons.mic, _insertAudio),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(IconData icon, TextFormat format, String label) {
    return InkWell(
      onTap: () => _insertFormat(format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildMediaButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ProtectedHtmlEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String lang;

  const _ProtectedHtmlEditor({
    required this.controller,
    required this.focusNode,
    this.lang = 'cn',
  });

  @override
  _ProtectedHtmlEditorState createState() => _ProtectedHtmlEditorState();
}

class _ProtectedHtmlEditorState extends State<_ProtectedHtmlEditor> {
  final Set<String> _singleTags = {
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr',
    'style', 'script', 'button', 'textarea', 'select',
  };

  final Set<String> _editableTags = {
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'p', 'a', 'span', 'div', 'li', 'td', 'th',
    'label', 'legend', 'caption',
  };

  List<_HtmlPart> _parseHtml(String text) {
    final parts = <_HtmlPart>[];
    if (text.isEmpty) {
      return parts;
    }

    final tagRegex = RegExp(r'<[^>]+>');
    int lastEnd = 0;
    final matches = tagRegex.allMatches(text);

    for (final match in matches) {
      if (match.start > lastEnd) {
        parts.add(_HtmlPart(
          type: _PartType.text,
          content: text.substring(lastEnd, match.start),
          start: lastEnd,
          end: match.start,
        ));
      }

      final tagText = match.group(0)!;
      final tagName = _extractTagName(tagText);
      final isSingle = _isSingleTag(tagText);

      if (isSingle) {
        parts.add(_HtmlPart(
          type: _PartType.singleTag,
          tagName: tagName,
          fullTag: tagText,
          start: match.start,
          end: match.end,
        ));
        lastEnd = match.end;
      } else if (_editableTags.contains(tagName)) {
        parts.add(_HtmlPart(
          type: _PartType.openTag,
          tagName: tagName,
          fullTag: tagText,
          start: match.start,
          end: match.end,
        ));

        final closeTagRegex = RegExp('</$tagName[^>]*>', caseSensitive: false);
        final remainingText = text.substring(match.end);
        final closeMatch = closeTagRegex.firstMatch(remainingText);

        if (closeMatch != null) {
          final innerText = remainingText.substring(0, closeMatch.start);
          final actualCloseStart = match.end + closeMatch.start;
          final actualCloseEnd = match.end + closeMatch.end;
          parts.add(_HtmlPart(
            type: _PartType.editableText,
            content: innerText,
            tagName: tagName,
            start: match.end,
            end: actualCloseStart,
          ));

          parts.add(_HtmlPart(
            type: _PartType.closeTag,
            tagName: tagName,
            fullTag: closeMatch.group(0)!,
            start: actualCloseStart,
            end: actualCloseEnd,
          ));

          lastEnd = actualCloseEnd;
        } else {
          lastEnd = match.end;
        }
      } else {
        parts.add(_HtmlPart(
          type: _PartType.singleTag,
          tagName: tagName,
          fullTag: tagText,
          start: match.start,
          end: match.end,
        ));
        lastEnd = match.end;
      }
    }

    if (lastEnd < text.length) {
      parts.add(_HtmlPart(
        type: _PartType.text,
        content: text.substring(lastEnd),
        start: lastEnd,
        end: text.length,
      ));
    }

    if (parts.isEmpty) {
      parts.add(_HtmlPart(
        type: _PartType.text,
        content: widget.lang == 'cn' ? '开始编辑内容...' : 'Start editing...',
        start: 0,
        end: 0,
      ));
    }

    return parts;
  }

  String _extractTagName(String tagText) {
    final match = RegExp(r'</?(\w+)').firstMatch(tagText);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  bool _isSingleTag(String tagText) {
    if (tagText.endsWith('/>')) return true;
    final tagName = _extractTagName(tagText);
    return _singleTags.contains(tagName);
  }

  void _handleTap(TapUpDetails details) {
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTap,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.lang == 'cn' ? '开始编辑内容...' : 'Start editing...',
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        showCursor: true,
        cursorColor: Colors.blue,
        cursorWidth: 2,
      ),
    );
  }
}

class _HtmlPart {
  final _PartType type;
  final String? content;
  final String? tagName;
  final String? fullTag;
  final int start;
  final int end;

  _HtmlPart({
    required this.type,
    this.content,
    this.tagName,
    this.fullTag,
    required this.start,
    required this.end,
  });
}

enum _PartType {
  text,
  singleTag,
  openTag,
  closeTag,
  editableText,
}

class _TagWidget extends StatelessWidget {
  final String text;

  const _TagWidget({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF616161),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
