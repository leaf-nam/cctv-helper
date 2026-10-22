import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/time_calc_service.dart';
import '../../../core/widgets/datetime_field.dart';
import '../../../core/widgets/time_edit_sheet.dart';
import '../../events/domain/timeline_event.dart';
import '../../events/providers/events_provider.dart';
import '../../sources/domain/cctv_source.dart';
import 'event_sheet.dart';

/// 행 내 날짜/시간 직접 입력칸.
///
/// 날짜(`yyyy-MM-dd`)와 시간(`HH:mm:ss`)을 두 줄로 나눠 표시하고,
/// 두 값이 모두 유효한 순간 즉시 반영한다. 포커스 중에는 외부 값 동기화를
/// 건드리지 않아 타이핑이 끊기지 않는다.
class _InlineDateTimeText extends StatefulWidget {
  final DateTime? value;
  final Future<void> Function(DateTime value) onChanged;

  const _InlineDateTimeText({required this.value, required this.onChanged});

  @override
  State<_InlineDateTimeText> createState() => _InlineDateTimeTextState();
}

class _InlineDateTimeTextState extends State<_InlineDateTimeText> {
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  final FocusNode _dateFocus = FocusNode();
  final FocusNode _timeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _InlineDateTimeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dateFocus.hasFocus || _timeFocus.hasFocus) return;
    _syncControllers();
  }

  void _syncControllers() {
    final date = widget.value == null ? '' : formatDate(widget.value);
    final time = widget.value == null ? '' : formatTime(widget.value);
    if (_dateController.text != date) _dateController.text = date;
    if (_timeController.text != time) _timeController.text = time;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _dateFocus.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  Future<void> _applyLive() async {
    final date = parseDateInput(_dateController.text);
    final time = parseTimeInput(_timeController.text);
    if (date == null || time == null) return;
    final parsed = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
    if (parsed == widget.value) return;
    await widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('inline-date'),
          controller: _dateController,
          focusNode: _dateFocus,
          style: theme.textTheme.bodySmall,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: '날짜',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (_) => _applyLive(),
          onSubmitted: (_) => _applyLive(),
        ),
        TextField(
          key: const ValueKey('inline-time'),
          controller: _timeController,
          focusNode: _timeFocus,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '시간',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (_) => _applyLive(),
          onSubmitted: (_) => _applyLive(),
        ),
      ],
    );
  }
}

/// CCTV 카드 1개: 시간 입력(#1)·오차 표시(#2)·이벤트 목록(#3).
///
/// 시간 확인칸의 조회 시각(`_checkedTime`)을 상태로 들고 있어
/// 기록 추가 시 확인된 시간을 그대로 이어쓴다.
class CctvCard extends StatefulWidget {
  final String caseId;
  final CctvSource source;

  /// 목록 내 위치 (드래그 핸들용).
  final int index;
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
    required this.index,
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

  /// 카드 전체 접기/펼치기. 사건 상세가 길어질 때 CCTV 단위로 접는다.
  bool _expanded = true;

  /// 카드 안 기록 목록 접기/펼치기. 사진·기록이 많을 때 목록만 접는다.
  bool _recordsExpanded = true;

  CctvSource get _source => widget.source;

  /// 좁은 화면이거나 글꼴이 크면 텍스트 버튼 대신 아이콘 버튼을 쓴다.
  bool _useCompactActions(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 400 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
  }

  /// 시간 확인칸. 기준 확정 전에는 안내만 표시.
  Widget _timeChecker() {
    if (_source.offsetMillis == null) {
      return Text(
        '기준 시각 2개를 입력하면 시간 확인이 가능합니다.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final corrected = _checkedTime == null
        ? null
        : _source.correct(_checkedTime!);
    final compact = _useCompactActions(context);
    void openCheckedTimeSheet() {
      showTimeEditSheet(
        context,
        title: '확인할 CCTV 시각',
        initial: _checkedTime ?? _source.displayedAt ?? DateTime.now(),
        onApply: (v) async => setState(() => _checkedTime = v),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.search, size: 18),
            const SizedBox(width: 4),
            Text('시간 확인', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (compact)
              IconButton(
                icon: const Icon(Icons.edit_calendar),
                tooltip: 'CCTV 시각 입력',
                onPressed: openCheckedTimeSheet,
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.edit_calendar),
                label: const Text('CCTV 시각 입력'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: openCheckedTimeSheet,
              ),
          ],
        ),
        if (_checkedTime == null)
          const Text('CCTV 시간을 입력하세요.')
        else ...[
          _resultRow(
            context,
            icon: Icons.videocam,
            label: 'CCTV 시각',
            value: _checkedTime!,
            onChanged: (v) async => setState(() => _checkedTime = v),
          ),
          const Divider(),
          _resultRow(
            context,
            icon: Icons.access_time,
            label: '실제 시각',
            value: corrected!,
          ),
        ],
      ],
    );
  }

  /// 확인 결과 표시 행 (기준 행과 같은 위아래 구조).
  /// CCTV 행은 바로 타이핑 가능, 실제 행은 계산값이라 읽기 전용.
  Widget _resultRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DateTime value,
    Future<void> Function(DateTime)? onChanged,
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
              if (onChanged == null)
                _twoLineDisplay(value)
              else
                _InlineDateTimeText(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ],
    );
  }

  /// 기록 목록의 CCTV/실제 시각 행. 라벨 폭을 고정해 두 시각의 시작점을 맞춘다.
  Widget _recordTimeRow(String label, DateTime value, {Key? timeKey}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '${formatDate(value)} ${formatTime(value)}',
            key: timeKey,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// 날짜/시간을 두 줄로 표시한다. 시간은 초까지 고정폭 숫자로 보여 준다.
  Widget _twoLineDisplay(DateTime? value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatDate(value), style: theme.textTheme.bodySmall),
        Text(
          formatTime(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
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

  /// 기록 메모 수정 다이얼로그. 저장 시에만 EventsProvider에 반영한다.
  Future<void> _editMemo(TimelineEvent event) async {
    var memo = event.memo;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: const Text('메모 수정'),
          content: TextFormField(
            key: const ValueKey('memo-edit-field'),
            initialValue: event.memo,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            onChanged: (value) => memo = value,
            decoration: const InputDecoration(
              labelText: '메모',
              hintText: '메모를 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('memo-edit-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('memo-edit-save'),
              onPressed: () => Navigator.of(dialogContext).pop(memo),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (!mounted || result == null) return;
    final trimmed = result.trim();
    if (trimmed == event.memo) return;
    await context.read<EventsProvider>().updateMemo(event.id, trimmed);
  }

  /// 시각 편집 시트 열기. `displayed`가 false면 실제 시각.
  /// 시트를 열기 전 포커스를 풀어 행 입력칸 표시가 외부 변경에 동기화되게 한다.
  Future<void> _editTime(
    BuildContext context, {
    required bool displayed,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showTimeEditSheet(
      context,
      title: displayed ? 'CCTV 시각 입력' : '실제 시각 입력',
      initial:
          (displayed ? _source.displayedAt : _source.actualAt) ??
          DateTime.now(),
      onApply: (value) async {
        if (displayed) {
          await widget.onUpdateTimes(_source.id, displayedAt: () => value);
        } else {
          await widget.onUpdateTimes(_source.id, actualAt: () => value);
        }
      },
    );
  }

  /// [지금] 즉시 반영. 포커스를 먼저 풀어 행 입력칸 표시를 동기화한다.
  Future<void> _setNow(BuildContext context, {required bool displayed}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    if (displayed) {
      await widget.onUpdateTimes(_source.id, displayedAt: () => now);
    } else {
      await widget.onUpdateTimes(_source.id, actualAt: () => now);
    }
  }

  /// 시각 입력 행 1개 (전체 너비). 실제 시각이 위, CCTV 시각이 아래에 배치된다.
  /// 행 앞 아이콘으로 구분 (실제=시계, CCTV=카메라).
  /// 값 텍스트에 바로 타이핑해도 즉시 반영된다 (입력 시트 생략 가능).
  Widget _timeRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required DateTime? value,
    required bool displayed,
  }) {
    final compact = _useCompactActions(context);
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
              _InlineDateTimeText(
                value: value,
                onChanged: (v) async {
                  if (displayed) {
                    await widget.onUpdateTimes(
                      _source.id,
                      displayedAt: () => v,
                    );
                  } else {
                    await widget.onUpdateTimes(_source.id, actualAt: () => v);
                  }
                },
              ),
            ],
          ),
        ),
        if (compact) ...[
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            tooltip: '입력',
            onPressed: () => _editTime(context, displayed: displayed),
          ),
          IconButton(
            icon: const Icon(Icons.access_time),
            tooltip: '지금',
            onPressed: () => _setNow(context, displayed: displayed),
          ),
        ] else ...[
          TextButton.icon(
            icon: const Icon(Icons.edit_calendar),
            label: const Text('입력'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _editTime(context, displayed: displayed),
          ),
          TextButton.icon(
            icon: const Icon(Icons.access_time),
            label: const Text('지금'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _setNow(context, displayed: displayed),
          ),
        ],
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
    final events = context.watch<EventsProvider>().bySource(_source.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카드 맨 위 드래그 핸들 (순서 조정용)
            Center(
              child: ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Icon(Icons.drag_handle, size: 20),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _expanded ? 'CCTV 접기' : 'CCTV 펼치기',
                    child: InkWell(
                      key: ValueKey('cctv-toggle-${_source.id}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _source.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
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
            if (!_expanded)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  ready
                      ? '기록 ${events.length}건 · '
                            '${TimeCalcService.formatOffset(offset)}'
                      : '기준 시각 미입력 · 기록 ${events.length}건',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // 기준 영역: 배경+테두리 박스로 시간확인·기록과 시각 분리
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '기준',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _timeRow(
                                context,
                                label: 'CCTV 시각',
                                icon: Icons.videocam,
                                value: _source.displayedAt,
                                displayed: true,
                              ),
                              const Divider(),
                              _timeRow(
                                context,
                                label: '실제 시각',
                                icon: Icons.access_time,
                                value: _source.actualAt,
                                displayed: false,
                              ),
                              // 오차 문구도 기준 표 안에 표시 (기준 확정 시에만)
                              if (ready) ...[
                                const Divider(),
                                Text(
                                  TimeCalcService.formatOffset(offset),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
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
                                    _timeChecker(),
                                    const Divider(),
                                    // 시간 확인 바로 밑 기록 추가 (확인된 시각으로 바로 기록)
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text('기록 추가'),
                                        onPressed: () => showEventSheet(
                                          context,
                                          widget.caseId,
                                          _source,
                                          initialDisplayed: recordTime,
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    // 기록 로그: 분리된 박스에 시간순 보관
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Semantics(
                                            button: true,
                                            label: _recordsExpanded
                                                ? '기록 접기'
                                                : '기록 펼치기',
                                            child: InkWell(
                                              key: ValueKey(
                                                'records-toggle-${_source.id}',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () => setState(
                                                () => _recordsExpanded =
                                                    !_recordsExpanded,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.list_alt,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '기록 ${events.length}건',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall,
                                                    ),
                                                    const Spacer(),
                                                    Icon(
                                                      _recordsExpanded
                                                          ? Icons.expand_less
                                                          : Icons.expand_more,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (!_recordsExpanded)
                                            const SizedBox.shrink()
                                          else if (events.isEmpty)
                                            const Text('아직 기록이 없습니다.')
                                          else
                                            ...events.map(
                                              (e) => ListTile(
                                                dense: true,
                                                isThreeLine: true,
                                                contentPadding: EdgeInsets.zero,
                                                leading: e.photoPath.isEmpty
                                                    ? null
                                                    : ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        child: Image.file(
                                                          File(e.photoPath),
                                                          width: 48,
                                                          height: 48,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                _,
                                                                __,
                                                              ) => const Icon(
                                                                Icons
                                                                    .broken_image,
                                                              ),
                                                        ),
                                                      ),
                                                title: Text(
                                                  e.memo.isEmpty
                                                      ? '(메모 없음)'
                                                      : e.memo,
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _recordTimeRow(
                                                      'CCTV',
                                                      e.displayedAt,
                                                      timeKey: ValueKey(
                                                        'record-cctv-${e.id}',
                                                      ),
                                                    ),
                                                    _recordTimeRow(
                                                      '실제',
                                                      e.correctedAt,
                                                      timeKey: ValueKey(
                                                        'record-actual-${e.id}',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      key: ValueKey(
                                                        'record-edit-${e.id}',
                                                      ),
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 20,
                                                      ),
                                                      tooltip: '메모 수정',
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints.tightFor(
                                                            width: 36,
                                                            height: 36,
                                                          ),
                                                      onPressed: () =>
                                                          _editMemo(e),
                                                    ),
                                                    IconButton(
                                                      key: ValueKey(
                                                        'record-delete-${e.id}',
                                                      ),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                      ),
                                                      tooltip: '삭제',
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints.tightFor(
                                                            width: 36,
                                                            height: 36,
                                                          ),
                                                      onPressed: () => context
                                                          .read<
                                                            EventsProvider
                                                          >()
                                                          .removeEvent(e.id),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(
                                  width: double.infinity,
                                  height: 0,
                                ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
