import 'package:cctv_helper/core/widgets/datetime_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDateInput', () {
    test('지원 형식', () {
      expect(parseDateInput('2026-10-22'), DateTime(2026, 10, 22));
      expect(parseDateInput('2026.10.22'), DateTime(2026, 10, 22));
      expect(parseDateInput('2026/10/22'), DateTime(2026, 10, 22));
      expect(parseDateInput('20261022'), DateTime(2026, 10, 22));
      expect(parseDateInput('2026년 10월 22일'), DateTime(2026, 10, 22));
    });

    test('존재하지 않는 날짜·범위 밖은 거부', () {
      expect(parseDateInput('2026-02-30'), isNull);
      expect(parseDateInput('2026-13-01'), isNull);
      expect(parseDateInput('2026-10-32'), isNull);
      expect(parseDateInput('1899-12-31'), isNull);
      expect(parseDateInput('2101-01-01'), isNull);
      expect(parseDateInput('날짜아님'), isNull);
    });
  });

  group('parseTimeInput', () {
    test('지원 형식', () {
      expect(parseTimeInput('14:02:11')!.hour, 14);
      expect(parseTimeInput('14:02:11')!.minute, 2);
      expect(parseTimeInput('14:02:11')!.second, 11);
      expect(parseTimeInput('14:02')!.second, 0);
      expect(parseTimeInput('140211')!.second, 11);
      expect(parseTimeInput('1402')!.minute, 2);
      expect(parseTimeInput('14시 2분 11초')!.second, 11);
    });

    test('범위 밖은 거부', () {
      expect(parseTimeInput('24:00'), isNull);
      expect(parseTimeInput('12:60'), isNull);
      expect(parseTimeInput('12:00:60'), isNull);
      expect(parseTimeInput('abc'), isNull);
    });
  });

  group('parseDateTimeInput', () {
    test('날짜+시간 조합', () {
      expect(
        parseDateTimeInput('2026-10-22 14:02:11'),
        DateTime(2026, 10, 22, 14, 2, 11),
      );
      expect(
        parseDateTimeInput('2026.10.22 14:02'),
        DateTime(2026, 10, 22, 14, 2),
      );
      expect(
        parseDateTimeInput('2026/10/22T14:02:11'),
        DateTime(2026, 10, 22, 14, 2, 11),
      );
      expect(
        parseDateTimeInput('2026년 10월 22일 14시 2분 3초'),
        DateTime(2026, 10, 22, 14, 2, 3),
      );
      expect(
        parseDateTimeInput('20261022140211'),
        DateTime(2026, 10, 22, 14, 2, 11),
      );
    });

    test('날짜만 있으면 자정', () {
      expect(parseDateTimeInput('2026-10-22'), DateTime(2026, 10, 22));
      expect(parseDateTimeInput('20261022'), DateTime(2026, 10, 22));
    });

    test('잘못된 값은 null', () {
      expect(parseDateTimeInput('2026-02-30 10:00:00'), isNull);
      expect(parseDateTimeInput('2026-10-22 25:00:00'), isNull);
      expect(parseDateTimeInput(''), isNull);
    });
  });

  test('표시 포맷', () {
    final value = DateTime(2026, 10, 8, 14, 2, 11);
    expect(formatDate(value), '2026-10-08');
    expect(formatTime(value), '14:02:11');
    expect(formatDateTime(value), '2026-10-08 14:02:11');
    expect(formatDate(null), '미입력');
    expect(formatTime(null), '--:--:--');
    expect(formatDateTime(null), '미입력');
  });

  testWidgets('좁은 화면에서 월 버튼이 한 줄로 표시', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showYearMonthPicker(
                  context,
                  initial: DateTime(2026, 5, 10),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final october = tester.widget<Text>(find.text('10월'));
    expect(october.maxLines, 1);
    expect(october.softWrap, isFalse);
  });

  testWidgets('연도·월 선택 다이얼로그에서 월을 바로 선택', (tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showYearMonthPicker(
                    context,
                    initial: DateTime(2026, 5, 10),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년'), findsOneWidget);
    expect(find.text('1월'), findsOneWidget);
    expect(find.text('12월'), findsOneWidget);

    await tester.tap(find.text('3월'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 3, 1));
  });
}
