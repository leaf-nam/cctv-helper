import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 날짜+시간 선택 헬퍼. 취소하면 null.
///
/// 1) 연도·월 선택 → 2) 일 선택 → 3) 시·분 선택 순서로 진행한다.
/// 연도 선택 단계에서 12개월 그리드를 함께 보여줘 월 이동을 바로 할 수 있다.
Future<DateTime?> pickDateTime(BuildContext context, DateTime? initial) async {
  final base = initial ?? DateTime.now();
  final yearMonth = await showYearMonthPicker(context, initial: base);
  if (yearMonth == null) return null;
  if (!context.mounted) return null;

  final lastDay = DateTime(yearMonth.year, yearMonth.month + 1, 0).day;
  final initialDay = base.day.clamp(1, lastDay);
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(yearMonth.year, yearMonth.month, initialDay),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100, 12, 31),
    initialDatePickerMode: DatePickerMode.day,
  );
  if (date == null) return null;
  if (!context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
    builder: (context, child) {
      // CCTV 타임스탬프는 24시간제가 일반적이므로 오전/오후 혼동을 막는다.
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
  if (time == null) return null;
  // 시/분 피커는 초를 다루지 않으므로 기존 초를 유지한다.
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
    base.second,
  );
}

/// 연도 + 12개월 그리드 선택 다이얼로그.
/// 선택 결과는 해당 월 1일이며, 호출부에서 일(day)을 이어서 선택한다.
Future<DateTime?> showYearMonthPicker(
  BuildContext context, {
  required DateTime initial,
  int firstYear = 2000,
  int lastYear = 2100,
}) {
  var year = initial.year.clamp(firstYear, lastYear);
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '이전 연도',
                  onPressed: year > firstYear
                      ? () => setDialogState(() => year -= 1)
                      : null,
                ),
                Expanded(
                  child: Center(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: year,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        alignment: Alignment.center,
                        items: [
                          for (var y = firstYear; y <= lastYear; y++)
                            DropdownMenuItem(
                              value: y,
                              child: Center(child: Text('$y년')),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => year = value);
                        },
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '다음 연도',
                  onPressed: year < lastYear
                      ? () => setDialogState(() => year += 1)
                      : null,
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 2.0,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (var month = 1; month <= 12; month++)
                    _MonthButton(
                      month: month,
                      selected: initial.year == year && initial.month == month,
                      onPressed: () =>
                          Navigator.of(dialogContext)
                              .pop(DateTime(year, month)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 연도·월 선택 다이얼로그의 월 버튼.
///
/// 좁은 화면에서 `10월`이 `10\n월`로 줄바꿈되지 않도록 한 줄 고정 +
/// FittedBox로 축소한다.
class _MonthButton extends StatelessWidget {
  final int month;
  final bool selected;
  final VoidCallback onPressed;

  const _MonthButton({
    required this.month,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '$month월',
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontSize: 13),
      ),
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    if (selected) {
      return FilledButton(style: style, onPressed: onPressed, child: child);
    }
    return OutlinedButton(style: style, onPressed: onPressed, child: child);
  }
}

/// `yyyy-MM-dd` 표시. 값이 없으면 `미입력`.
String formatDate(DateTime? value) {
  if (value == null) return '미입력';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

/// `HH:mm:ss` 표시. 값이 없으면 `--:--:--`.
String formatTime(DateTime? value) {
  if (value == null) return '--:--:--';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

/// `yyyy-MM-dd HH:mm:ss` 표시 (한 줄이 필요한 저장·로그용).
String formatDateTime(DateTime? value) {
  if (value == null) return '미입력';
  return '${formatDate(value)} ${formatTime(value)}';
}

/// 날짜 문자열 파싱. `yyyy-MM-dd`, `yyyy.MM.dd`, `yyyy/MM/dd`,
/// `yyyyMMdd`, `yyyy년 MM월 dd일`을 허용한다.
DateTime? parseDateInput(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return null;
  text = text
      .replaceAll('년', '-')
      .replaceAll('월', '-')
      .replaceAll('일', '')
      .replaceAll('.', '-')
      .replaceAll('/', '-');
  text = text.replaceAll(RegExp(r'-+'), '-');
  if (text.startsWith('-')) text = text.substring(1);
  if (text.endsWith('-')) text = text.substring(0, text.length - 1);

  if (RegExp(r'^\d{8}$').hasMatch(text)) {
    return _makeDateTime(
      int.parse(text.substring(0, 4)),
      int.parse(text.substring(4, 6)),
      int.parse(text.substring(6, 8)),
    );
  }
  final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text);
  if (match == null) return null;
  return _makeDateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// 시간 문자열 파싱. `HH:mm`, `HH:mm:ss`, `HHmm`, `HHmmss`,
/// `HH시 mm분 ss초`를 허용한다.
DateTime? parseTimeInput(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) return null;
  text = text
      .replaceAll('시', ':')
      .replaceAll('분', ':')
      .replaceAll('초', '')
      .replaceAll('：', ':');
  text = text.replaceAll(RegExp(r':+'), ':');
  if (text.startsWith(':')) text = text.substring(1);
  if (text.endsWith(':')) text = text.substring(0, text.length - 1);

  int? hour;
  int? minute;
  int? second = 0;
  final match = RegExp(r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$')
      .firstMatch(text);
  if (match != null) {
    hour = int.parse(match.group(1)!);
    minute = int.parse(match.group(2)!);
    second = int.tryParse(match.group(3) ?? '') ?? 0;
  } else if (RegExp(r'^\d{6}$').hasMatch(text)) {
    hour = int.parse(text.substring(0, 2));
    minute = int.parse(text.substring(2, 4));
    second = int.parse(text.substring(4, 6));
  } else if (RegExp(r'^\d{4}$').hasMatch(text)) {
    hour = int.parse(text.substring(0, 2));
    minute = int.parse(text.substring(2, 4));
  } else {
    return null;
  }
  if (hour < 0 || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;
  if (second < 0 || second > 59) return null;
  return DateTime(2000, 1, 1, hour, minute, second);
}

/// 날짜+시간 문자열 파싱. 날짜만 있으면 자정으로 처리한다.
DateTime? parseDateTimeInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // 20261022140211 / 20261022 140211 (공백 제외 14자리) 형태
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  if (RegExp(r'^\d{14}$').hasMatch(compact)) {
    return _combine(
      parseDateInput(compact.substring(0, 8)),
      parseTimeInput(compact.substring(8)),
    );
  }

  // `2026-10-22 14:02:11`, `2026년 10월 22일 14시 02분 11초` 등
  final dateMatch = RegExp(r'(\d{4})\s*[-./년]\s*(\d{1,2})\s*[-./월]\s*(\d{1,2})')
      .firstMatch(text);
  if (dateMatch == null) {
    // 구분자 없는 날짜(`20261022`)만 있는 경우
    return parseDateInput(text);
  }
  final date = _makeDateTime(
    int.parse(dateMatch.group(1)!),
    int.parse(dateMatch.group(2)!),
    int.parse(dateMatch.group(3)!),
  );
  if (date == null) return null;

  final timeMatch = RegExp(
    r'(\d{1,2})\s*[:시]\s*(\d{1,2})(?:\s*[:분]\s*(\d{1,2}))?',
  ).firstMatch(text);
  if (timeMatch == null) return date;

  final time = parseTimeInput(
    '${timeMatch.group(1)}:${timeMatch.group(2)}:'
    '${timeMatch.group(3) ?? '0'}',
  );
  if (time == null) return null;
  return _combine(date, time);
}

DateTime? _combine(DateTime? date, DateTime? time) {
  if (date == null || time == null) return null;
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
    time.second,
  );
}

/// 존재하지 않는 날짜(2월 30일 등)를 거부하는 생성 헬퍼.
DateTime? _makeDateTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int second = 0,
]) {
  if (year < 1900 || year > 2100) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  if (hour < 0 || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;
  if (second < 0 || second > 59) return null;
  final value = DateTime(year, month, day, hour, minute, second);
  if (value.year != year ||
      value.month != month ||
      value.day != day ||
      value.hour != hour ||
      value.minute != minute ||
      value.second != second) {
    return null;
  }
  return value;
}

/// 숫자만 입력하면 구분자까지 자동으로 채워 주는 포매터 (#36).
///
/// 사용자는 숫자만 누르면 되고, 그룹이 찰 때 `-`/`:`가 자동으로 들어간다.
/// 예) 날짜 `20261022` → `2026-10-22`, 시간 `140322` → `14:03:22`.
/// 구분자를 지우면(백스페이스) 앞 숫자까지 함께 지워 자연스럽게 줄어든다.
class GroupedDigitsInputFormatter extends TextInputFormatter {
  GroupedDigitsInputFormatter({required this.groups, required this.separator})
    : assert(groups.isNotEmpty);

  /// 앞에서부터의 자릿수 그룹. 예) 날짜 `[4, 2, 2]`, 시간 `[2, 2, 2]`.
  final List<int> groups;
  final String separator;

  /// 입력 가능한 최대 자릿수.
  int get maxDigits => groups.fold(0, (sum, value) => sum + value);

  /// 문자열에서 숫자만 남긴다.
  static String digitsOnly(String text) =>
      text.replaceAll(RegExp(r'[^0-9]'), '');

  /// 숫자열을 구분자가 포함된 표시 문자열로 바꾼다.
  ///
  /// 그룹이 꽉 차고 뒤 그룹이 남아 있으면 구분자를 미리 보여 준다
  /// (`14` → `14:`).
  String format(String digits) {
    final buffer = StringBuffer();
    var index = 0;
    for (var g = 0; g < groups.length; g++) {
      if (index >= digits.length) break;
      if (g > 0) buffer.write(separator);
      final take = math.min(groups[g], digits.length - index);
      buffer.write(digits.substring(index, index + take));
      index += take;
      if (index >= digits.length &&
          g < groups.length - 1 &&
          take == groups[g]) {
        buffer.write(separator);
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = digitsOnly(oldValue.text);
    var digits = digitsOnly(newValue.text);
    var cursor = newValue.selection.baseOffset;
    if (cursor < 0 || cursor > newValue.text.length) {
      cursor = newValue.text.length;
    }
    var digitsBeforeCursor = _digitCount(newValue.text, cursor);

    // 최대 자릿수를 넘는 입력(붙여넣기 포함)은 잘라낸다.
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
      digitsBeforeCursor = math.min(digitsBeforeCursor, digits.length);
    }

    // 숫자는 그대로인데 길이만 줄었다면 구분자를 지운 것이므로
    // 앞 숫자까지 함께 지운다.
    if (digits == oldDigits && newValue.text.length < oldValue.text.length) {
      final removedAt = _firstDifference(oldValue.text, newValue.text);
      final before = _digitCount(oldValue.text, removedAt);
      if (before > 0 && before <= digits.length) {
        digits = digits.replaceRange(before - 1, before, '');
        if (digitsBeforeCursor >= before) digitsBeforeCursor--;
      }
    }

    final text = format(digits);
    final offset = digitsBeforeCursor.clamp(0, digits.length);
    var position = 0;
    var seen = 0;
    while (position < text.length && seen < offset) {
      if (_isDigit(text[position])) seen++;
      position++;
    }
    // 자동으로 들어간 구분자 뒤로 커서를 넘겨 다음 숫자를 바로 받게 한다.
    if (position < text.length && text[position] == separator) {
      position++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: position),
    );
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static int _digitCount(String text, int end) {
    final limit = end.clamp(0, text.length);
    var count = 0;
    for (var i = 0; i < limit; i++) {
      if (_isDigit(text[i])) count++;
    }
    return count;
  }

  static int _firstDifference(String oldText, String newText) {
    final limit = math.min(oldText.length, newText.length);
    for (var i = 0; i < limit; i++) {
      if (oldText[i] != newText[i]) return i;
    }
    return limit;
  }
}

/// 날짜 직접 입력용 포매터. 숫자만 받고 `yyyy-MM-dd` 구분자를 자동 삽입한다.
List<TextInputFormatter> dateInputFormatters() => [
  GroupedDigitsInputFormatter(groups: const [4, 2, 2], separator: '-'),
];

/// 시간 직접 입력용 포매터. 숫자만 받고 `HH:mm:ss` 구분자를 자동 삽입한다.
List<TextInputFormatter> timeInputFormatters() => [
  GroupedDigitsInputFormatter(groups: const [2, 2, 2], separator: ':'),
];

/// 직접 입력 검증 결과.
class DateTimeInputValidation {
  const DateTimeInputValidation.empty()
    : value = null,
      error = null,
      incomplete = false;

  const DateTimeInputValidation.valid(this.value)
    : error = null,
      incomplete = false;

  const DateTimeInputValidation.invalid(this.error)
    : value = null,
      incomplete = false;

  /// 아직 자릿수가 모자란 상태. [error]가 null이면 경고를 띄우지 않는다.
  const DateTimeInputValidation.incomplete([this.error])
    : value = null,
      incomplete = true;

  final DateTime? value;
  final String? error;

  /// 입력이 덜 끝난 상태(범위 오류 아님).
  final bool incomplete;

  bool get isEmpty => value == null && error == null;
  bool get isValid => value != null;
}

/// 날짜 직접 입력 검증 (#36).
///
/// 숫자 8자리를 모두 채우기 전에는 경고하지 않고([incomplete]),
/// 1900~2100년 범위를 벗어나거나 존재하지 않는 날짜일 때만 오류를 준다.
/// [incompleteAsError]는 포커스를 잃었을 때 미완성 안내를 보여 줄 때 쓴다.
DateTimeInputValidation validateDateInput(
  String raw, {
  bool incompleteAsError = false,
}) {
  final text = raw.trim();
  if (text.isEmpty) return const DateTimeInputValidation.empty();
  final parsed = parseDateInput(text);
  if (parsed != null) return DateTimeInputValidation.valid(parsed);

  final digits = GroupedDigitsInputFormatter.digitsOnly(text);
  if (digits.length < 8) {
    final rangeError = _dateRangeError(digits);
    if (rangeError != null) return DateTimeInputValidation.invalid(rangeError);
    return incompleteAsError
        ? const DateTimeInputValidation.incomplete('연월일 8자리를 입력하세요.')
        : const DateTimeInputValidation.incomplete();
  }
  return const DateTimeInputValidation.invalid(
    '날짜 범위를 확인하세요 (1900~2100년, 실제 존재하는 날짜).',
  );
}

/// 부분 입력 상태에서 이미 범위를 벗어난 값이면 오류 문구를 돌려준다.
String? _dateRangeError(String digits) {
  if (digits.length >= 4) {
    final year = int.parse(digits.substring(0, 4));
    if (year < 1900 || year > 2100) {
      return '연도 범위를 확인하세요 (1900~2100년).';
    }
  }
  if (digits.length >= 6) {
    final month = int.parse(digits.substring(4, 6));
    if (month < 1 || month > 12) return '월 범위를 확인하세요 (1~12월).';
  }
  return null;
}

/// 시간 직접 입력 검증 (#36).
///
/// 시 0~23, 분/초 0~59를 벗어날 때만 오류를 주고, 자릿수가 모자라면
/// 경고 없이 [DateTimeInputValidation.incomplete]로 돌려준다.
DateTimeInputValidation validateTimeInput(
  String raw, {
  bool incompleteAsError = false,
}) {
  final text = raw.trim();
  if (text.isEmpty) return const DateTimeInputValidation.empty();
  final parsed = parseTimeInput(text);
  if (parsed != null) return DateTimeInputValidation.valid(parsed);

  final digits = GroupedDigitsInputFormatter.digitsOnly(text);
  final rangeError = _timeRangeError(digits);
  if (rangeError != null) return DateTimeInputValidation.invalid(rangeError);
  if (digits.length < 6) {
    return incompleteAsError
        ? const DateTimeInputValidation.incomplete('시분초 6자리를 입력하세요.')
        : const DateTimeInputValidation.incomplete();
  }
  return const DateTimeInputValidation.invalid(
    '시간 범위를 확인하세요 (00~23시, 00~59분/초).',
  );
}

/// 부분 입력 상태에서 이미 범위를 벗어난 시/분/초를 찾는다.
String? _timeRangeError(String digits) {
  if (digits.length >= 2) {
    final hour = int.parse(digits.substring(0, 2));
    if (hour > 23) return '시 범위를 확인하세요 (00~23시).';
  }
  if (digits.length >= 4) {
    final minute = int.parse(digits.substring(2, 4));
    if (minute > 59) return '분 범위를 확인하세요 (00~59분).';
  }
  if (digits.length >= 6) {
    final second = int.parse(digits.substring(4, 6));
    if (second > 59) return '초 범위를 확인하세요 (00~59초).';
  }
  return null;
}
