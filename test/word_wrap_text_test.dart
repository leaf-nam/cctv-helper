import 'package:cctv_helper/core/widgets/word_wrap_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('좁은 폭에서도 단어를 중간에서 자르지 않는다', (tester) async {
    const key = ValueKey('word-wrap-text');
    const body = '수사 사건을 먼저 만들고 그 안에 확인할 CCTV를 추가합니다.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 120, child: WordWrapText(body, key: key)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final wrap = find.byKey(key);
    expect(wrap, findsOneWidget);
    expect(
      find.descendant(of: wrap, matching: find.byType(Wrap)),
      findsOneWidget,
    );

    final width = tester.getSize(wrap).width;
    for (final word in body.split(' ')) {
      final wordFinder = find.descendant(of: wrap, matching: find.text(word));
      expect(wordFinder, findsOneWidget, reason: word);
      expect(
        tester.getSize(wordFinder).width,
        lessThanOrEqualTo(width),
        reason: '$word 단어가 가용 폭을 넘음',
      );
    }
  });

  testWidgets('가용 폭보다 긴 단어는 단어 내부에서 줄바꿈된다', (tester) async {
    const key = ValueKey('long-word-wrap');
    final longWord = '아주긴단어' * 20;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: WordWrapText(longWord, key: key),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final word = find.text(longWord);
    expect(word, findsOneWidget);
    expect(tester.getSize(word).width, lessThanOrEqualTo(120));
    expect(tester.getSize(word).height, greaterThan(20));
  });
}
