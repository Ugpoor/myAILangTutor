import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class EfficiencySection extends StatefulWidget {
  final VoidCallback? onEfficiencyTap;
  final VoidCallback? onScheduleTap;

  const EfficiencySection({
    super.key,
    this.onEfficiencyTap,
    this.onScheduleTap,
  });

  @override
  State<EfficiencySection> createState() => _EfficiencySectionState();
}

class _EfficiencySectionState extends State<EfficiencySection> {
  late Future<List<Map<String, dynamic>>> _efficiencyRecordsFuture;
  late Future<List<Map<String, dynamic>>> _scheduleItemsFuture;

  @override
  void initState() {
    super.initState();
    _efficiencyRecordsFuture = DatabaseHelper().getRecentEfficiencyRecords(2);
    _scheduleItemsFuture = DatabaseHelper().getTodayScheduleItems(2);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '我的效率',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              flex: 6,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _efficiencyRecordsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildEfficiencyWidget(
                      title: '效率记录',
                      color: const Color(0xFF651FFF),
                      children: const [CircularProgressIndicator()],
                      onTap: widget.onEfficiencyTap,
                    );
                  } else if (snapshot.hasError) {
                    return _buildEfficiencyWidget(
                      title: '效率记录',
                      color: const Color(0xFF651FFF),
                      children: [Text('加载失败: ${snapshot.error}')],
                      onTap: widget.onEfficiencyTap,
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEfficiencyWidget(
                      title: '效率记录',
                      color: const Color(0xFF651FFF),
                      children: const [Text('暂无记录')],
                      onTap: widget.onEfficiencyTap,
                    );
                  } else {
                    final records = snapshot.data!;
                    print(
                      '>>> EfficiencySection: got ${records.length} efficiency records',
                    );
                    final List<Widget> children = [];
                    for (int i = 0; i < records.length && i < 2; i++) {
                      final record = records[i];
                      final title = record['title'] as String? ?? '';
                      final unitEff =
                          (record['unit_efficiency'] as num?)?.toDouble() ??
                          0.0;
                      children.add(
                        Text(
                          '$title — ${unitEff.toStringAsFixed(1)}秒',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      );
                      children.add(const SizedBox(height: 6));
                    }
                    print(
                      '>>> EfficiencySection: rendering ${children.length} efficiency items',
                    );
                    return _buildEfficiencyWidget(
                      title: '效率记录',
                      color: const Color(0xFF651FFF),
                      children: children,
                      onTap: widget.onEfficiencyTap,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _scheduleItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildEfficiencyWidget(
                      title: '日程安排',
                      color: const Color(0xFFC2185B),
                      children: const [CircularProgressIndicator()],
                      onTap: widget.onScheduleTap,
                    );
                  } else if (snapshot.hasError) {
                    return _buildEfficiencyWidget(
                      title: '日程安排',
                      color: const Color(0xFFC2185B),
                      children: [Text('加载失败: ${snapshot.error}')],
                      onTap: widget.onScheduleTap,
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEfficiencyWidget(
                      title: '日程安排',
                      color: const Color(0xFFC2185B),
                      children: const [Text('今日无安排')],
                      onTap: widget.onScheduleTap,
                    );
                  } else {
                    final items = snapshot.data!;
                    print(
                      '>>> EfficiencySection: got ${items.length} schedule items',
                    );
                    final List<Widget> children = [];
                    for (int i = 0; i < items.length && i < 2; i++) {
                      final item = items[i];
                      final title = item['title'] as String? ?? '';
                      final startTime = item['start_time'] as String? ?? '';
                      children.add(
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              startTime.length >= 5
                                  ? startTime.substring(0, 5)
                                  : startTime,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                      children.add(const SizedBox(height: 4));
                      children.add(
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      );
                      children.add(const SizedBox(height: 4));
                    }
                    print(
                      '>>> EfficiencySection: rendering ${children.length} schedule items',
                    );
                    return _buildEfficiencyWidget(
                      title: '日程安排',
                      color: const Color(0xFFC2185B),
                      children: children,
                      onTap: widget.onScheduleTap,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEfficiencyWidget({
    required String title,
    required Color color,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(
                (color.r * 255.0).round().clamp(0, 255),
                (color.g * 255.0).round().clamp(0, 255),
                (color.b * 255.0).round().clamp(0, 255),
                0.3,
              ),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
