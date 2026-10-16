import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'datetime_field.dart';

/// 시각 편집 바텀시트.
///
/// [지금] 버튼, 가로 2행 ±스테퍼(1일/1시간/1분/1초…),
/// 단위별 분할 직접 입력(년·월·일·시·분·초, 범위 검증)을 제공한다.
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

  // 단위별 컨트롤러: 0=년 1=월 2=일 3=시 4=분 5=초
  final parts = List.generate(6, (_) => TextEditingController());

  void syncParts(DateTime value) {
    final values = [
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    ];
    for (var i = 0; i < 6; i++) {
      parts[i].text = values[i].toString().padLeft(i == 0 ? 4 : 2, '0');
    }
  }

  syncParts(initial);

  /// 6칸 조합. 범위 밖(월 13·분 70 등)이나 존재하지 않는 날짜(2월 30일)는
  /// null → 적용하지 않고 마지막 유효값 유지.
  DateTime? composeParts() {
    final numbers = parts.map((c) => int.tryParse(c.text)).toList();
    if (numbers.any((e) => e == null)) return null;
    final y = numbers[0]!;
    final mo = numbers[1]!;
    final d = numbers[2]!;
    final h = numbers[3]!;
    final mi = numbers[4]!;
    final s = numbers[5]!;
    if (mo < 1 || mo > 12) return null;
    if (d < 1 || d > 31) return null;
    if (h < 0 || h > 23) return null;
    if (mi < 0 || mi > 59) return null;
    if (s < 0 || s > 59) return null;
    final composed = DateTime(y, mo, d, h, mi, s);
    // 월말 넘김(2월 30일 → 3월 2일) rollover 방지
    if (composed.year != y || composed.month != mo || composed.day != d) {
      return null;
    }
    return composed;
  }

  var lastComposed = composeParts();

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
            syncParts(value);
            lastComposed = value;
          }

          // 분할 입력 즉시 적용: 6칸이 모두 유효한 순간 바로 반영.
          Future<void> applyLive() async {
            final composed = composeParts();
            if (composed == null || composed == current) return;
            lastComposed = composed;
            await apply(setState, composed);
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

          Widget numField(int index, String suffix, {int flex = 2}) {
            return Expanded(
              flex: flex,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('time-part-$index'),
                      controller: parts[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          index == 0 ? 4 : 2,
                        ),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => applyLive(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(suffix),
                  ),
                ],
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
                // 단위별 분할 입력 (범위 밖 값은 적용되지 않음)
                Row(
                  children: [
                    numField(0, '년', flex: 3),
                    const SizedBox(width: 4),
                    numField(1, '월'),
                    const SizedBox(width: 4),
                    numField(2, '일'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    numField(3, '시'),
                    const SizedBox(width: 4),
                    numField(4, '분'),
                    const SizedBox(width: 4),
                    numField(5, '초'),
                  ],
                ),
                Text(
                  '각 단위별로 입력 (월 1-12·시 0-23·분/초 0-59)',
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
  // controllers는 pop 애니메이션 중에도 시트가 참조하므로 여기서 dispose하지
  // 않는다 (리스너가 없어 GC 대상이 됨).
  final pending = composeParts();
  if (pending != null && pending != lastComposed) {
    await onChanged(pending);
  }
}
