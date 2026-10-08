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

  DateTime? tryParseDirect(String text) {
    return DateTime.tryParse(text.trim().replaceAll('/', '-'));
  }

  final directController = TextEditingController(
    text: formatDateTime(initial),
  );
  // 시트가 닫히는 시점에 최종 입력값을 읽기 위한 스냅샷.
  // (컨트롤러 자체는 시트 위젯이 들고 있어 pop 후에 건드리면 안 됨)
  var lastDirectText = directController.text;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
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

          // 타이핑 즉시 적용: 파싱 가능한 순간 바로 반영 (Enter 불필요).
          // 중간 상태(미완성 문자열)는 무시하고 마지막 유효값 유지.
          Future<void> applyLive(String text) async {
            final parsed = tryParseDirect(text);
            if (parsed == null || parsed == current) return;
            await apply(setState, parsed);
          }

          Future<void> applyDirect() async {
            final parsed = tryParseDirect(directController.text);
            if (parsed == null) return;
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
                // 상단 시간 자체가 입력칸 (타이핑 즉시 적용, Enter 불필요)
                TextField(
                  controller: directController,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  onChanged: (text) {
                    lastDirectText = text;
                    applyLive(text);
                  },
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
  // 모달이 닫히는 시점에 입력칸 최종값을 한 번 더 읽어 반영한다.
  // (타이핑 중 저장 가드에 걸려 live-apply를 놓친 경우 커버)
  final pending = tryParseDirect(lastDirectText);
  if (pending != null && pending != current) {
    await onChanged(pending);
  }
}
