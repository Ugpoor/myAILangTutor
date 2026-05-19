class InboxItem {
  final int? id;
  final String title;
  final String source;
  final String url;
  final String filePath;
  final String content;
  final String category;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isValid; // 是否有效（数据库中有记录）

  InboxItem({
    this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.filePath,
    this.content = '',
    this.category = '未知归类',
    this.status = '未处理',
    required this.createdAt,
    this.updatedAt,
    this.isValid = true, // 默认有效
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'url': url,
      'filePath': filePath,
      'content': content,
      'category': category,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory InboxItem.fromMap(Map<String, dynamic> map) {
    return InboxItem(
      id: map['id'],
      title: map['title'],
      source: map['source'],
      url: map['url'],
      filePath: map['filePath'],
      content: map['content'],
      category: map['category'],
      status: map['status'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  InboxItem copyWith({
    int? id,
    String? title,
    String? source,
    String? url,
    String? filePath,
    String? content,
    String? category,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isValid,
  }) {
    return InboxItem(
      id: id ?? this.id,
      title: title ?? this.title,
      source: source ?? this.source,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isValid: isValid ?? this.isValid,
    );
  }
}
