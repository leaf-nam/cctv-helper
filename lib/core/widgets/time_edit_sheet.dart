import 'package:flutter/material.dart';

import 'datetime_field.dart';

/// 시각 편집 바텀시트.
///
/// 달력→시계 2단계 피커만으로는 맞추기 힘들어
/// [지금] 버튼과 ±스테퍼(1시간/10분/1분)를 제공한다.
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

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Widget stepButton(String label, Duration delta) {
            return OutlinedButton(
              onPressed: () => apply(setState, current.add(delta)),
              child: Text(label),
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
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    stepButton('-1시간', const Duration(hours: -1)),
                    stepButton('-10분', const Duration(minutes: -10)),
                    stepButton('-1분', const Duration(minutes: -1)),
                    stepButton('+1분', const Duration(minutes: 1)),
                    stepButton('+10분', const Duration(minutes: 10)),
                    stepButton('+1시간', const Duration(hours: 1)),
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
