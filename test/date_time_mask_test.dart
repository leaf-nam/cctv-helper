import 'package:cctv_helper/core/widgets/datetime_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 타이핑처럼 마지막에 글자를 덧붙인 새 값을 만든다.
TextEditingValue _append(
  TextInputFormatter formatter,
  TextEditingValue old,
  String char,
) {
  final text = old.text + char;
  return formatter.formatEditUpdate(
    old,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
}

void main() {
  final date = GroupedDigitsInputFormatter(
    groups: const [4, 2, 2],
    separator: '-',
  );
  final time = GroupedDigitsInputFormatter(
    groups: const [2, 2, 2],
    separator: ':',
  );

  test('날짜: 숫자만 입력해도 -가 자동 삽입된다', () {
    const expected = {
      1: '2',
      2: '20',
      3: '202',
      4: '2026-',
      5: '2026-1',
      6: '2026-10-',
      7: '2026-10-2',
      8: '2026-10-22',
    };
    var value = const TextEditingValue();
    var typed = '';
    for (final digit in '20261022'.split('')) {
      value = _append(date, value, digit);
      typed += digit;
      expect(value.text, expected[typed.length], reason: '입력 $typed');
    }
    expect(value.selection.baseOffset, value.text.length);
  });

  test('시간: 두 칸이 차면 :가 자동 삽입된다', () {
    const expected = {
      1: '1',
      2: '14:',
      3: '14:0',
      4: '14:03:',
      5: '14:03:2',
      6: '14:03:22',
    };
    var value = const TextEditingValue();
    var typed = '';
    for (final digit in '140322'.split('')) {
      value = _append(time, value, digit);
      typed += digit;
      expect(value.text, expected[typed.length], reason: '입력 $typed');
    }
    expect(value.selection.baseOffset, value.text.length);
  });

  test('숫자가 아닌 문자는 무시한다', () {
    var value = const TextEditingValue();
    for (final char in '2026abc10'.split('')) {
      value = _append(date, value, char);
    }
    expect(value.text, '2026-10-');

    var t = const TextEditingValue();
    for (final char in '14:03:22'.split('')) {
      t = _append(time, t, char);
    }
    expect(t.text, '14:03:22');
  });

  test('최대 자릿수를 넘는 입력은 무시한다', () {
    var value = date.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '2026-10-22',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    value = _append(date, value, '3');
    expect(value.text, '2026-10-22');

    final pasted = date.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '20261022140322',
        selection: TextSelection.collapsed(offset: 14),
      ),
    );
    expect(pasted.text, '2026-10-22');
  });

  test('구분자를 지우면 앞 숫자까지 함께 지운다', () {
    const old = TextEditingValue(
      text: '14:03:',
      selection: TextSelection.collapsed(offset: 6),
    );
    final next = time.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '14:03',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    expect(next.text, '14:0');
  });

  test('커서 위치는 입력한 숫자 뒤에 유지된다', () {
    const old = TextEditingValue(
      text: '14:0',
      selection: TextSelection.collapsed(offset: 4),
    );
    final next = time.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '14:03',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    expect(next.text, '14:03:');
    expect(next.selection.baseOffset, next.text.length);
  });
}
