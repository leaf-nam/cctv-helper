import 'package:flutter/material.dart';

import 'datetime_field.dart';

/// 시각 편집 바텀시트.
///
/// [지금] 버튼, 가로 2행 ±스테퍼(1일/1시간/10분/1분/10초/1초),
/// 날짜 직접 타이핑 입력을 제공한다.
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
      final directController = TextEditingController(
        text: formatDateTime(initial),
      );
      String? directError;
      return StatefulBuilder(
        builder: (context, setState) {
          // 스테퍼·지금·달력 변경 시 입력칸 표시도 함께 갱신
          Future<void> applyAndSync(
            void Function(void Function()) setState,
            DateTime value,
          ) async {
            await apply(setState, value);
            directController.text = formatDateTime(value);
          }

          Widget stepButton(String text, Duration delta) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => applyAndSync(setState, current.add(delta)),
                  child: Text(text, style: const TextStyle(fontSize: 13)),
                ),
              ),
            );
          }

          List<Widget> stepRow(bool minus) {
            return [
              for (final unit in units)
                stepButton(
                  '${minus ? '−' : '+'}${unit.label}',
                  minus
                      ? Duration(
                          microseconds: -unit.duration.inMicroseconds,
                        )
                      : unit.duration,
                ),
            ];
          }

          Future<void> applyDirect() async {
            final parsed = DateTime.tryParse(
              directController.text.trim().replaceAll('/', '-'),
            );
            if (parsed == null) {
              setState(() => directError = '형식: 2026-10-08 22:30:00');
              return;
            }
            setState(() => directError = null);
            await apply(setState, parsed);
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
                // 상단 시간 자체가 입력칸 (탭해 직접 타이핑, Enter로 적용)
                TextField(
                  controller: directController,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    errorText: directError,
                  ),
                  onSubmitted: (_) => applyDirect(),
                ),
                Text(
                  '직접 입력 가능 (예: 2026-10-08 22:30:00)',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: const Text('지금으로 설정'),
                  onPressed: () => applyAndSync(setState, DateTime.now()),
                ),
                const SizedBox(height: 8),
                // 가로 2행 스테퍼: 윗행 −, 아랫행 +
                Row(children: stepRow(true)),
                const SizedBox(height: 4),
                Row(children: stepRow(false)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('날짜·시간 직접 선택'),
                  onPressed: () async {
                    final picked = await pickDateTime(context, current);
                    if (picked == null) return;
                    if (!context.mounted) return;
                    await applyAndSync(setState, picked);
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
