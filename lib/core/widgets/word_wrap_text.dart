import 'package:flutter/material.dart';

/// 공백으로 나눈 단어를 통째로 다음 줄로 넘기는 텍스트.
///
/// Flutter의 기본 [Text]는 좁은 폭에서 한글 단어를 음절 단위로 끊을 수 있다.
/// 온보딩 도움말처럼 짧은 안내 문구는 단어 중간이 잘리지 않도록 [Wrap]으로
/// 단어를 하나씩 배치한다. 한 단어가 가용 폭보다 길면 해당 단어만 내부에서
/// 줄바꿈된다.
class WordWrapText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double spacing;
  final double runSpacing;

  const WordWrapText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.spacing = 4,
    this.runSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: switch (textAlign) {
            TextAlign.center => WrapAlignment.center,
            TextAlign.end => WrapAlignment.end,
            TextAlign.left => WrapAlignment.start,
            _ => WrapAlignment.start,
          },
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final word in words)
              Text(word, style: effectiveStyle, textAlign: textAlign),
          ],
        ),
      ),
    );
  }
}
