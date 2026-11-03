import 'package:cctv_helper/core/widgets/time_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DateTimeText: 날짜/시간 크기·고정폭·라벨 표시', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateTimeText(
            value: DateTime(2026, 10, 22, 14, 3, 22),
            label: 'CCTV 시각',
          ),
        ),
      ),
    );

    expect(find.text('2026-10-22'), findsOneWidget);
    expect(find.text('14:03:22'), findsOneWidget);
    expect(find.text('CCTV 시각'), findsOneWidget);

    final time = tester.widget<Text>(find.text('14:03:22'));
    expect(time.style?.fontSize, greaterThanOrEqualTo(18));
    expect(time.style?.fontWeight, FontWeight.w600);
    expect(time.style?.fontFeatures, isNotNull);

    final date = tester.widget<Text>(find.text('2026-10-22'));
    expect(date.style?.fontSize, greaterThanOrEqualTo(13));
  });

  testWidgets('DateTimeText: 값이 없으면 미입력/자리표시', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DateTimeText(value: null))),
    );
    expect(find.text('미입력'), findsOneWidget);
    expect(find.text('--:--:--'), findsOneWidget);
  });

  testWidgets('DateTimeInlineText: 한 줄에 날짜와 시간 표시', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateTimeInlineText(value: DateTime(2026, 10, 22, 14, 3, 22)),
        ),
      ),
    );
    expect(find.text('2026-10-22 14:03:22'), findsOneWidget);
  });
}
