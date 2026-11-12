import 'package:flutter/material.dart';

/// Hiển thị câu trả lời AI. Model đôi khi vẫn trả Markdown dù system prompt yêu cầu văn bản
/// thuần (Gemini, ngày 12), nên chỉ nhận dạng vài cú pháp an toàn: `**đậm**`, dòng gạch đầu
/// (`* `, `- `, `• `) và tiêu đề `#`. Mọi thứ khác — kể cả HTML hay link — hiển thị đúng
/// nguyên văn, không thực thi, không tự mở.
class CoachText extends StatelessWidget {
  const CoachText(this.content, {super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(TextSpan(children: coachSpans(content)));
  }
}

final _bullet = RegExp(r'^(\s*)[*\-•]\s+(.*)$');
final _heading = RegExp(r'^\s*#{1,6}\s+(.*)$');
final _bold = RegExp(r'\*\*(.+?)\*\*');

const _boldStyle = TextStyle(fontWeight: FontWeight.bold);

/// Tách nội dung thành các đoạn văn bản; dùng riêng để test không cần dựng widget.
List<TextSpan> coachSpans(String content) {
  final spans = <TextSpan>[];
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final heading = _heading.firstMatch(line);
    final bullet = heading == null ? _bullet.firstMatch(line) : null;
    if (heading != null) {
      spans.add(TextSpan(text: _stripBold(heading.group(1)!), style: _boldStyle));
    } else if (bullet != null) {
      final nested = bullet.group(1)!.length >= 2;
      spans.add(TextSpan(text: nested ? '    ◦ ' : '• '));
      spans.addAll(_inline(bullet.group(2)!));
    } else {
      spans.addAll(_inline(line));
    }
    if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
  }
  return spans;
}

String _stripBold(String text) => text.replaceAllMapped(_bold, (m) => m.group(1)!);

/// `**x**` → đậm; dấu `**` lẻ giữ nguyên.
List<TextSpan> _inline(String text) {
  final spans = <TextSpan>[];
  var start = 0;
  for (final m in _bold.allMatches(text)) {
    if (m.start > start) spans.add(TextSpan(text: text.substring(start, m.start)));
    spans.add(TextSpan(text: m.group(1), style: _boldStyle));
    start = m.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}
