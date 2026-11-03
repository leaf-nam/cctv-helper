import 'package:cctv_helper/core/widgets/datetime_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateDateInput', () {
    test('정상 날짜', () {
      final result = validateDateInput('2026-10-22');
      expect(result.isValid, isTrue);
      expect(result.value, DateTime(2026, 10, 22));
      expect(result.error, isNull);
    });

    test('빈 값은 오류가 아니다', () {
      final result = validateDateInput('   ');
      expect(result.isEmpty, isTrue);
      expect(result.error, isNull);
    });

    test('7777777처럼 자릿수 초과/형식 오류는 거부', () {
      final result = validateDateInput('7777777');
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('존재하지 않는 날짜 거부', () {
      expect(validateDateInput('2026-02-30').error, isNotNull);
      expect(validateDateInput('2026-13-01').error, isNotNull);
    });

    test('연도 범위 초과 거부', () {
      expect(validateDateInput('1899-01-01').error, isNotNull);
      expect(validateDateInput('2101-01-01').error, isNotNull);
    });

    test('입력 중(자릿수 부족)에는 경고하지 않는다', () {
      final result = validateDateInput('2026-10');
      expect(result.incomplete, isTrue);
      expect(result.error, isNull);
      expect(result.isValid, isFalse);
    });

    test('포커스를 잃으면 미완성 안내를 보여 준다', () {
      final result = validateDateInput('2026-10', incompleteAsError: true);
      expect(result.incomplete, isTrue);
      expect(result.error, isNotNull);
    });

    test('부분 입력이라도 이미 범위를 벗어나면 즉시 경고', () {
      expect(validateDateInput('1899').error, contains('연도'));
      expect(validateDateInput('2026-13').error, contains('월'));
    });
  });

  group('validateTimeInput', () {
    test('정상 시간', () {
      final result = validateTimeInput('23:59:59');
      expect(result.isValid, isTrue);
      expect(result.value!.hour, 23);
      expect(result.value!.second, 59);
    });

    test('빈 값은 오류가 아니다', () {
      expect(validateTimeInput('').isEmpty, isTrue);
    });

    test('7777777 입력 거부', () {
      final result = validateTimeInput('7777777');
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });

    test('24시/60분/60초 거부', () {
      expect(validateTimeInput('24:00:00').error, isNotNull);
      expect(validateTimeInput('12:60:00').error, isNotNull);
      expect(validateTimeInput('12:00:60').error, isNotNull);
    });

    test('입력 중(자릿수 부족)에는 경고하지 않는다', () {
      final result = validateTimeInput('14:');
      expect(result.incomplete, isTrue);
      expect(result.error, isNull);
      expect(validateTimeInput('14').incomplete, isTrue);
      expect(validateTimeInput('14').error, isNull);
    });

    test('포커스를 잃으면 미완성 안내를 보여 준다', () {
      expect(validateTimeInput('14', incompleteAsError: true).error, isNotNull);
    });

    test('부분 입력이라도 범위를 벗어나면 즉시 경고', () {
      expect(validateTimeInput('25').error, contains('시'));
      expect(validateTimeInput('14:60').error, contains('분'));
      expect(validateTimeInput('14:03:60').error, contains('초'));
    });

    test('한글 단위 표기도 검증', () {
      expect(validateTimeInput('14시 03분 22초').isValid, isTrue);
      expect(validateTimeInput('25시 00분 00초').error, isNotNull);
    });
  });
}
