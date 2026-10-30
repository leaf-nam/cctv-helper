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
  });
}
