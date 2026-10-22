import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'datetime_field.dart';

/// 시각 편집 바텀시트.
///
/// 값을 바로 저장하지 않고 draft로 편집한 뒤 `적용`에서 한 번만 저장한다.
/// `닫기`는 변경 사항을 버리고 닫는다. `지금`, 스테퍼(길게 누르면 연속 증감),
/// 단위별 직접 입력, 연도·월·일 선택을 제공한다.
Future<void> showTimeEditSheet(
  BuildContext context, {
  required String title,
  required DateTime initial,
  required Future<void> Function(DateTime value) onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _TimeEditSheetBody(title: title, initial: initial, onApply: onApply),
  );
}

class _TimeEditSheetBody extends StatefulWidget {
  final String title;
  final DateTime initial;
  final Future<void> Function(DateTime value) onApply;

  const _TimeEditSheetBody({
    required this.title,
    required this.initial,
    required this.onApply,
  });

  @override
  State<_TimeEditSheetBody> createState() => _TimeEditSheetBodyState();
}

class _TimeEditSheetBodyState extends State<_TimeEditSheetBody> {
  static const _units = <({String label, Duration duration})>[
    (label: '1일', duration: Duration(days: 1)),
    (label: '1시간', duration: Duration(hours: 1)),
    (label: '10분', duration: Duration(minutes: 10)),
    (label: '1분', duration: Duration(minutes: 1)),
    (label: '10초', duration: Duration(seconds: 10)),
    (label: '1초', duration: Duration(seconds: 1)),
  ];

  late DateTime _draft = widget.initial;
  late final List<TextEditingController> _parts;
  String? _error;
  bool _dirty = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _parts = List.generate(6, (_) => TextEditingController());
    _syncParts(_draft);
  }

  @override
  void dispose() {
    for (final controller in _parts) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncParts(DateTime value) {
    final values = [
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    ];
    for (var i = 0; i < 6; i++) {
      _parts[i].text = values[i].toString().padLeft(i == 0 ? 4 : 2, '0');
    }
  }

  /// 6칸 조합. 범위 밖(월 13·분 70 등)이나 존재하지 않는 날짜는 null.
  DateTime? _composeParts() {
    final numbers = _parts.map((c) => int.tryParse(c.text.trim())).toList();
    if (numbers.any((e) => e == null)) return null;
    final year = numbers[0]!;
    final month = numbers[1]!;
    final day = numbers[2]!;
    final hour = numbers[3]!;
    final minute = numbers[4]!;
    final second = numbers[5]!;
    if (year < 1900 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;
    if (second < 0 || second > 59) return null;
    final composed = DateTime(year, month, day, hour, minute, second);
    // 월말 넘김(2월 30일 → 3월 2일) rollover 방지
    if (composed.year != year ||
        composed.month != month ||
        composed.day != day) {
      return null;
    }
    return composed;
  }

  void _setDraft(DateTime value, {bool syncParts = true}) {
    if (!mounted) return;
    setState(() {
      _draft = value;
      _dirty = true;
      _error = null;
    });
    if (syncParts) _syncParts(value);
  }

  void _onPartChanged() {
    if (!_dirty) setState(() => _dirty = true);
    final allFilled = _parts.every((c) => c.text.trim().isNotEmpty);
    if (!allFilled) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    final composed = _composeParts();
    if (composed == null) {
      if (_error == null) {
        setState(() => _error = '유효하지 않은 날짜/시간입니다.');
      }
      return;
    }
    setState(() {
      _draft = composed;
      _dirty = true;
      _error = null;
    });
  }

  Future<void> _apply() async {
    if (_applying) return;
    final composed = _composeParts();
    if (composed == null) {
      setState(() => _error = '유효하지 않은 날짜/시간입니다.');
      return;
    }
    setState(() => _applying = true);
    try {
      await widget.onApply(composed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _applying = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('시각을 저장할 수 없습니다.')));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _close() async {
    if (_applying) return;
    if (_dirty || _error != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('변경 사항'),
            content: const Text('적용하지 않고 닫을까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('계속 편집'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _stepButton(String text, Duration delta) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _RepeatStepButton(
          label: text,
          onStep: () => _setDraft(_draft.add(delta)),
        ),
      ),
    );
  }

  List<Widget> _stepRow(bool minus) {
    return [
      for (final unit in _units)
        _stepButton(
          '${minus ? '−' : '+'}${unit.label}',
          minus
              ? Duration(microseconds: -unit.duration.inMicroseconds)
              : unit.duration,
        ),
    ];
  }

  Widget _numField(int index, String suffix, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('time-part-$index'),
              controller: _parts[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: index == 5
                  ? TextInputAction.done
                  : TextInputAction.next,
              style: const TextStyle(fontSize: 15),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(index == 0 ? 4 : 2),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (_) => _onPartChanged(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(suffix, style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          math.max(16.0, bottomInset + 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  key: const ValueKey('time-close-icon'),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: _applying ? null : _close,
                ),
              ],
            ),
            Text('값을 확인한 뒤 적용을 누르세요.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                _numField(0, '년', flex: 3),
                const SizedBox(width: 4),
                _numField(1, '월'),
                const SizedBox(width: 4),
                _numField(2, '일'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _numField(3, '시'),
                const SizedBox(width: 4),
                _numField(4, '분'),
                const SizedBox(width: 4),
                _numField(5, '초'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.access_time),
              label: const Text('지금으로 설정'),
              onPressed: _applying ? null : () => _setDraft(DateTime.now()),
            ),
            const SizedBox(height: 8),
            // 가로 2행 스테퍼: 윗행 −, 아랫행 +
            Row(children: _stepRow(true)),
            const SizedBox(height: 4),
            Row(children: _stepRow(false)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('날짜·시간 직접 선택'),
              onPressed: _applying
                  ? null
                  : () async {
                      final picked = await pickDateTime(context, _draft);
                      if (picked == null) return;
                      if (!mounted) return;
                      _setDraft(picked);
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('time-close'),
                    onPressed: _applying ? null : _close,
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('time-apply'),
                    onPressed: _applying ? null : _apply,
                    child: _applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('적용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 길게 누르면 일정 지연 후 연속으로 [onStep]을 호출하는 스테퍼 버튼.
class _RepeatStepButton extends StatefulWidget {
  final String label;
  final VoidCallback onStep;

  const _RepeatStepButton({required this.label, required this.onStep});

  @override
  State<_RepeatStepButton> createState() => _RepeatStepButtonState();
}

class _RepeatStepButtonState extends State<_RepeatStepButton> {
  Timer? _delayTimer;
  Timer? _repeatTimer;
  bool _pressed = false;

  void _start() {
    if (_pressed) return;
    _pressed = true;
    HapticFeedback.selectionClick();
    widget.onStep();
    _delayTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        HapticFeedback.selectionClick();
        widget.onStep();
      });
    });
  }

  void _stop() {
    _delayTimer?.cancel();
    _repeatTimer?.cancel();
    _delayTimer = null;
    _repeatTimer = null;
    _pressed = false;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onStep,
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(widget.label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
