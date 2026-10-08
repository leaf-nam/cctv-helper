import 'package:flutter/material.dart';

import 'datetime_field.dart';

/// 시각 편집 바텀시트.
///
/// 달력→시계 2단계 피커만으로는 맞추기 힘들어
/// [지금] 버튼과 2열 ±스테퍼 테이블(1일/1시간/10분/1분/10초/1초)을 제공한다.
/// 모든 변경은 즉시 `onChanged`로 반영된다 (live-apply).
Future<void> showTimeEditSheet(
  BuildContext context, {
  required String title,
  required DateTime initial,
  required Future<void> Function(DateTime value) onChanged,
}) async {
  var current = initial;
  var saving = false;

  Future<void> apply(
    void Function(void Function()) setState,
    DateTime value,
  ) async {
    if (saving) return;
    saving = true;
    setState(() => current = value);
    try {
      await onChanged(value);
    } finally {
      saving = false;
    }
  }

  const units = <({String label, Duration duration})>[
    (label: '1일', duration: Duration(days: 1)),
    (label: '1시간', duration: Duration(hours: 1)),
    (label: '10분', duration: Duration(minutes: 10)),
    (label: '1분', duration: Duration(minutes: 1)),
    (label: '10초', duration: Duration(seconds: 10)),
    (label: '1초', duration: Duration(seconds: 1)),
  ];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Widget stepCell(String text, Duration delta) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: OutlinedButton(
                onPressed: () => apply(setState, current.add(delta)),
                child: Text(text, style: const TextStyle(fontSize: 16)),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  formatDateTime(current),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: const Text('지금으로 설정'),
                  onPressed: () => apply(setState, DateTime.now()),
                ),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  children: [
                    for (final unit in units)
                      TableRow(
                        children: [
                          stepCell(
                            '− ${unit.label}',
                            Duration(
                              microseconds: -unit.duration.inMicroseconds,
                            ),
                          ),
                          stepCell('+ ${unit.label}', unit.duration),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('날짜·시간 직접 선택'),
                  onPressed: () async {
                    final picked = await pickDateTime(context, current);
                    if (picked == null) return;
                    if (!context.mounted) return;
                    await apply(setState, picked);
                  },
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
