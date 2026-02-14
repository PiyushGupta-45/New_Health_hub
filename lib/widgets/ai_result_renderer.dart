import 'package:flutter/material.dart';

class AIResultRenderer extends StatelessWidget {
  const AIResultRenderer({
    super.key,
    required this.rawText,
  });

  final String rawText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTextColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937);
    final subtleTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final sectionBg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
    final sectionBorder = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    final sections = _parseSections(rawText);
    if (sections.isEmpty) {
      return Text(
        rawText,
        style: TextStyle(color: subtleTextColor, fontSize: 14, height: 1.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sectionBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sectionBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: baseTextColor,
                ),
              ),
              if (section.items.isNotEmpty) const SizedBox(height: 8),
              ...section.items.map((item) {
                final isBullet = item.startsWith('- ');
                final content = isBullet ? item.substring(2).trim() : item.trim();
                final isDayHeading = RegExp(r'^Day\s+\d+\s*:', caseSensitive: false)
                    .hasMatch(content);
                if (isDayHeading) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_note_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            content,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBullet)
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: 8),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          content,
                          style: TextStyle(
                            color: subtleTextColor,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<_ParsedSection> _parseSections(String input) {
    final lines = input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];

    final sections = <_ParsedSection>[];
    _ParsedSection? current;

    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (current != null) sections.add(current);
        current = _ParsedSection(title: line.substring(3).trim(), items: <String>[]);
        continue;
      }

      if (line.startsWith('# ')) {
        if (current != null) sections.add(current);
        current = _ParsedSection(title: line.substring(2).trim(), items: <String>[]);
        continue;
      }

      current ??= _ParsedSection(title: 'Result', items: <String>[]);
      current.items.add(line);
    }

    if (current != null) {
      sections.add(current);
    }
    return sections;
  }
}

class _ParsedSection {
  const _ParsedSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}
