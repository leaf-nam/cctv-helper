import 'package:flutter/material.dart';

/// 날짜+시간 선택 헬퍼. 취소하면 null.
Future<DateTime?> pickDateTime(BuildContext context, DateTime? initial) async {
  final now = initial ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// `yyyy-MM-dd HH:mm:ss` 표시 (10초/1초 스테퍼 대응).
String formatDateTime(DateTime? value) {
  if (value == null) return '미입력';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
