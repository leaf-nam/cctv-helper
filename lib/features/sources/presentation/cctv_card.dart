import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/time_calc_service.dart';
import '../../../core/widgets/datetime_field.dart';
import '../../../core/widgets/time_edit_sheet.dart';
import '../../events/providers/events_provider.dart';
import '../../sources/domain/cctv_source.dart';
import 'event_sheet.dart';

/// CCTV 카드 1개: 시간 입력(#1)·오차 표시(#2)·이벤트 목록(#3).
///
/// 시간 확인칸의 조회 시각(`_checkedTime`)을 상태로 들고 있어
/// 기록 추가 시 확인된 시간을 그대로 이어쓴다.
class CctvCard extends StatefulWidget {
  final String caseId;
  final CctvSource source;
  final Future<void> Function(String id, String name) onRename;
  final Future<void> Function(String id) onRemove;
  final Future<void> Function(
    String id, {
    DateTime? Function()? displayedAt,
    DateTime? Function()? actualAt,
  })
  onUpdateTimes;

  const CctvCard({
    super.key,
    required this.caseId,
    required this.source,
    required this.onRename,
    required this.onRemove,
    required this.onUpdateTimes,
  });

  @override
  State<CctvCard> createState() => _CctvCardState();
}

class _CctvCardState extends State<CctvCard> {
  /// 시간 확인칸에서 마지막으로 조회한 CCTV 시간. 기록 추가 시 초기값으로 사용.
  DateTime? _checkedTime;

  CctvSource get _source => widget.source;

  /// 시간 확인칸. 기준 확정 전에는 안내만 표시.
  Widget _timeChecker() {
    if (_source.offsetMillis == null) {
      return Text(
        '기준 시각 2개를 입력하면 시간 확인이 가능합니다.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final corrected =
        _checkedTime == null ? null : _source.correct(_checkedTime!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.search, size: 18),
            const SizedBox(width: 4),
            Text('시간 확인', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('CCTV 시간 입력'),
              onPressed: () => showTimeEditSheet(
                context,
                title: '확인할 CCTV 시간',
                initial: _checkedTime ??
                    _source.displayedAt ??
                    DateTime.now(),
                onChanged: (v) async => setState(() => _checkedTime = v),
              ),
            ),
          ],
        ),
        Text(
          _checkedTime == null
              ? 'CCTV 시간을 입력하세요.'
              : 'CCTV ${formatDateTime(_checkedTime)} → 실제 ${formatDateTime(corrected)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: _source.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CCTV 이름 변경'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '이름'),
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    await widget.onRename(_source.id, name);
  }

  /// 시각 편집 시트 열기. `displayed`가 false면 실제 시각.
  Future<void> _editTime(
    BuildContext context, {
    required bool displayed,
  }) async {
    await showTimeEditSheet(
      context,
      title: displayed ? 'CCTV 시각 입력' : '실제 시각 입력',
      initial: (displayed ? _source.displayedAt : _source.actualAt) ??
          DateTime.now(),
      onChanged: (value) async {
        if (displayed) {
          await widget.onUpdateTimes(_source.id, displayedAt: () => value);
        } else {
          await widget.onUpdateTimes(_source.id, actualAt: () => value);
        }
      },
    );
  }

  /// [지금] 즉시 반영.
  Future<void> _setNow(
    BuildContext context, {
    required bool displayed,
  }) async {
    final now = DateTime.now();
    if (displayed) {
      await widget.onUpdateTimes(_source.id, displayedAt: () => now);
    } else {
      await widget.onUpdateTimes(_source.id, actualAt: () => now);
    }
  }

  /// 시각 입력 행 1개 (전체 너비). 실제 시각이 위, CCTV 시각이 아래에 배치된다.
  /// 행 앞 아이콘으로 구분 (실제=시계, CCTV=카메라).
  Widget _timeRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required DateTime? value,
    required bool displayed,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                formatDateTime(value),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.edit_calendar),
          label: const Text('입력'),
          onPressed: () => _editTime(context, displayed: displayed),
        ),
        TextButton.icon(
          icon: const Icon(Icons.access_time),
          label: const Text('지금'),
          onPressed: () => _setNow(context, displayed: displayed),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final offset = _source.offsetMillis;
    // 기준 시각 2개가 모두 입력돼 오프셋이 확정될 때만 하단 기능 공개.
    final ready = offset != null;
    // 기록 추가 시 쓸 시각: 시간 확인칸의 조회 시간 우선, 없으면 기준 CCTV 시각.
    final recordTime = _checkedTime ?? _source.displayedAt ?? DateTime.now();
    final events = context
        .watch<EventsProvider>()
        .bySource(_source.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _source.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: '이름 변경',
                  onPressed: () => _rename(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '삭제',
                  onPressed: () => widget.onRemove(_source.id),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 기준 영역: 배경+테두리 박스로 시간확인·기록과 시각 분리
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '기준',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _timeRow(
                    context,
                    label: '실제 시각',
                    icon: Icons.access_time,
                    value: _source.actualAt,
                    displayed: false,
                  ),
                  const Divider(),
                  _timeRow(
                    context,
                    label: 'CCTV 시각',
                    icon: Icons.videocam,
                    value: _source.displayedAt,
                    displayed: true,
                  ),
                ],
              ),
            ),
            const Divider(),
            // 아코디언: 기준 확정 시 펼쳐지며 오차·확인·기록 공개
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: ready
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TimeCalcService.formatOffset(offset),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Divider(),
                        _timeChecker(),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '기록 ${events.length}건',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    '기록 시각: ${formatDateTime(recordTime)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('기록 추가'),
                              onPressed: () => showEventSheet(
                                context,
                                widget.caseId,
                                _source,
                                initialDisplayed: recordTime,
                              ),
                            ),
                          ],
                        ),
                        if (events.isEmpty)
                          const Text('아직 기록이 없습니다.')
                        else
                          ...events.map(
                            (e) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: e.photoPath.isEmpty
                                  ? null
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(e.photoPath),
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, _, __) =>
                                            const Icon(Icons.broken_image),
                                      ),
                                    ),
                              title: Text(
                                e.memo.isEmpty ? '(메모 없음)' : e.memo,
                              ),
                              subtitle: Text(
                                '보정 ${formatDateTime(e.correctedAt)} '
                                '(영상 ${formatDateTime(e.displayedAt)})',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => context
                                    .read<EventsProvider>()
                                    .removeEvent(e.id),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            if (!ready)
              Text(
                'CCTV·실제 시각을 모두 입력하면 오차·확인·기록 기능이 펼쳐집니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
