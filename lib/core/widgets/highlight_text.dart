import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  const HighlightText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    super.key,
  });

  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;
  final int? maxLines;
  final TextOverflow overflow;

  /// Normalization that preserves string length so indices stay aligned.
  String _normalizeForHighlight(String input) {
    if (input.isEmpty) return '';
    return removeDiacritics(input).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final normalizedText = _normalizeForHighlight(text);
    final normalizedQuery = _normalizeForHighlight(query).trim();
    if (normalizedQuery.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final spans = <TextSpan>[];
    var cursor = 0;

    while (true) {
      final matchIndex = normalizedText.indexOf(normalizedQuery, cursor);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(cursor), style: style));
        break;
      }

      if (matchIndex > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, matchIndex),
            style: style,
          ),
        );
      }

      final matchEnd = matchIndex + normalizedQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchEnd),
          style: highlightStyle,
        ),
      );
      cursor = matchEnd;
      if (cursor >= text.length) break;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}
