import 'package:cctv_helper/features/ocr/domain/timestamp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimestampParser', () {
    test('yyyy-MM-dd HH:mm:ss', () {
      final result = TimestampParser.parse('2026-10-22 14:03:22');
      expect(result, isNotNull);
      expect(result!.value, DateTime(2026, 10, 22, 14, 3, 22));
      expect(result.pattern, 'date+time');
      expect(result.confidence, greaterThan(0.8));
    });

    test('구분자 변형 yyyy/MM/dd', () {
      final result = TimestampParser.parse('CCTV 2026/10/22 09:05:00');
      expect(result!.value, DateTime(2026, 10, 22, 9, 5));
    });

    test('미국식 MM/dd/yyyy + AM/PM', () {
      final result = TimestampParser.parse('10/22/2026 02:03:22 PM');
      expect(result!.value, DateTime(2026, 10, 22, 14, 3, 22));
    });

    test('한글 단위 표기', () {
      final result = TimestampParser.parse('2026년 10월 22일 14시 03분 22초');
      expect(result!.value, DateTime(2026, 10, 22, 14, 3, 22));
    });

    test('시각만 있으면 fallback 날짜를 사용', () {
      final result = TimestampParser.parse(
        'REC 14:03:22',
        fallbackDate: DateTime(2026, 10, 22),
      );
      expect(result!.value, DateTime(2026, 10, 22, 14, 3, 22));
      expect(result.pattern, 'time');
    });

    test('압축 표기 yyyyMMddHHmmss', () {
      final result = TimestampParser.parse('20261022140322');
      expect(result!.value, DateTime(2026, 10, 22, 14, 3, 22));
    });

    test('전각 숫자/콜론 정규화', () {
      final result = TimestampParser.parse('２０２６－１０－２２　１４：０３：２２');
      expect(result!.value, DateTime(2026, 10, 22, 14, 3, 22));
    });

    test('범위를 벗어난 시각은 후보 없음', () {
      expect(TimestampParser.parse('2026-10-22 25:00:00'), isNull);
      expect(TimestampParser.parse('2026-10-22 14:60:00'), isNull);
    });

    test('존재하지 않는 날짜는 후보 없음', () {
      expect(TimestampParser.parse('2026-02-30 10:00:00'), isNull);
    });

    test('숫자만 있는 잡음은 후보 없음', () {
      expect(TimestampParser.parse('7777777'), isNull);
      expect(TimestampParser.candidates('7777777'), isEmpty);
    });

    test('신뢰도 내림차순 정렬', () {
      final list = TimestampParser.candidates('2026-10-22 14:03:22');
      expect(list.length, greaterThanOrEqualTo(2));
      expect(list.first.pattern, 'date+time');
      expect(list.first.confidence, greaterThanOrEqualTo(list[1].confidence));
    });

    test('한 글에 시각이 여러 개면 각각 후보로 만든다', () {
      final list = TimestampParser.candidates(
        'CCTV 2026-10-22 14:03:22\n실제 시계 2026-10-22 14:05:10',
        fallbackDate: DateTime(2026, 11, 9),
      );
      final values = list.map((e) => e.value).toSet();
      expect(values, contains(DateTime(2026, 10, 22, 14, 3, 22)));
      expect(values, contains(DateTime(2026, 10, 22, 14, 5, 10)));
      // 같은 시각이 형식만 다르게 중복되지 않는다.
      expect(values.length, list.length);
    });

    group('영어 월 이름', () {
      test('메뉴바 캡처: Fri Oct 30 9:11PM', () {
        final result = TimestampParser.parse(
          'Fri Oct 30\n) 9:11PM',
          fallbackDate: DateTime(2026, 10, 30),
        );
        expect(result, isNotNull);
        expect(result!.value, DateTime(2026, 10, 30, 21, 11));
        expect(result.pattern, 'date+time');
      });

      test('OCT.30.2026 21:11:05', () {
        final result = TimestampParser.parse('OCT.30.2026 21:11:05');
        expect(result!.value, DateTime(2026, 10, 30, 21, 11, 5));
      });

      test('30-Oct-2026 21:11:05', () {
        final result = TimestampParser.parse('30-Oct-2026 21:11:05');
        expect(result!.value, DateTime(2026, 10, 30, 21, 11, 5));
      });

      test('Oct 30, 2026 09:05:00', () {
        final result = TimestampParser.parse('Oct 30, 2026 09:05:00');
        expect(result!.value, DateTime(2026, 10, 30, 9, 5));
      });

      test('2026 OCT 30 21:11:05 (연-월-일)', () {
        final result = TimestampParser.parse('2026 OCT 30 21:11:05');
        expect(result!.value, DateTime(2026, 10, 30, 21, 11, 5));
      });

      test('전체 월 이름 October도 인식', () {
        final result = TimestampParser.parse(
          'October 30 21:11',
          fallbackDate: DateTime(2026, 10, 30),
        );
        expect(result!.value, DateTime(2026, 10, 30, 21, 11));
      });

      test('연도가 없고 미래 날짜면 작년으로 보정', () {
        final result = TimestampParser.parse(
          'Dec 31 23:59',
          fallbackDate: DateTime(2026, 3, 5),
        );
        expect(result!.value, DateTime(2025, 12, 31, 23, 59));
      });

      test('연도가 없고 과거/같은 날이면 fallback 연도 유지', () {
        final result = TimestampParser.parse(
          'Mar 4 10:00',
          fallbackDate: DateTime(2026, 3, 5),
        );
        expect(result!.value, DateTime(2026, 3, 4, 10));
      });

      test('범위를 벗어난 날짜는 후보 없음', () {
        expect(TimestampParser.parse('OCT 45 2026 10:00:00'), isNull);
        expect(TimestampParser.parse('FEB 30 2026 10:00:00'), isNull);
      });
    });
  });
}
