
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class RealTimePreview extends StatelessWidget {
  final String content;
  final String lang;

  const RealTimePreview({
    super.key,
    required this.content,
    this.lang = 'cn',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              lang == 'cn' ? '实时预览' : 'Preview',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: content.isEmpty
                    ? Center(
                        child: Text(
                          lang == 'cn' ? '编辑内容后在此预览' : 'Preview will appear here',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        child: Html(
                          data: _convertMarkdownToHtml(content),
                          style: {
                            'html': Style(
                              fontSize: FontSize(14),
                              lineHeight: LineHeight(1.6),
                            ),
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                            ),
                            'div': Style(
                              width: Width(100, Unit.percent),
                              display: Display.block,
                            ),
                            'h1': Style(
                              fontSize: FontSize(20),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 8, bottom: 8),
                            ),
                            'h2': Style(
                              fontSize: FontSize(18),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 6, bottom: 6),
                            ),
                            'h3': Style(
                              fontSize: FontSize(16),
                              fontWeight: FontWeight.bold,
                              margin: Margins.only(top: 4, bottom: 4),
                            ),
                            'strong': Style(fontWeight: FontWeight.bold),
                            'em': Style(fontStyle: FontStyle.italic),
                            'u': Style(textDecoration: TextDecoration.underline),
                            'p': Style(
                              fontSize: FontSize(14),
                              lineHeight: LineHeight(1.6),
                              margin: Margins.only(bottom: 8),
                            ),
                            'br': Style(),
                            'img': Style(width: Width(100, Unit.percent)),
                          },
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _convertMarkdownToHtml(String markdown) {
    String html = markdown
        .replaceAll(RegExp(r'^### (.+)$', multiLine: true), r'<h3>$1</h3>')
        .replaceAll(RegExp(r'^## (.+)$', multiLine: true), r'<h2>$1</h2>')
        .replaceAll(RegExp(r'^# (.+)$', multiLine: true), r'<h1>$1</h1>')
        .replaceAll(r'**([^*]+)**', r'<strong>$1</strong>')
        .replaceAll(r'*([^*]+)*', r'<em>$1</em>')
        .replaceAll(r'__([^_]+)__', r'<u>$1</u>')
        .replaceAll(r'\n', '<br>')
        .replaceAll(RegExp(r'!\[.*?\]\((.+?)\)'), r'<img src="$1" />');

    return '<div>$html</div>';
  }
}
