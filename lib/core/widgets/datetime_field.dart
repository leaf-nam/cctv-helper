import 'package:flutter/material.dart';

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
