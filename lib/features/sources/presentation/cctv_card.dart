import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/time_calc_service.dart';
import '../../../core/widgets/datetime_field.dart';
import '../../events/providers/events_provider.dart';
import '../../sources/domain/cctv_source.dart';
import 'event_sheet.dart';

/// CCTV 카드 1개: 시간 입력(#1)·오차 표시(#2)·이벤트 목록(#3).
class CctvCard extends StatelessWidget {
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

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: source.name);
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
    await onRename(source.id, name);
  }

  Future<void> _pickTime(
    BuildContext context, {
    required bool displayed,
  }) async {
    final picked = await pickDateTime(
      context,
      displayed ? source.displayedAt : source.actualAt,
    );
    if (picked == null) return;
    if (!context.mounted) return;
    if (displayed) {
      await onUpdateTimes(source.id, displayedAt: () => picked);
    } else {
      await onUpdateTimes(source.id, actualAt: () => picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = source.offsetMillis;
    final events = context
        .watch<EventsProvider>()
        .bySource(source.id);
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
                    source.name,
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
                  onPressed: () => onRemove(source.id),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: Text(
                    'CCTV 시각: ${formatDateTime(source.displayedAt)}',
                  ),
                  onPressed: () => _pickTime(context, displayed: true),
                ),
                ActionChip(
                  label: Text(
                    '실제 시각: ${formatDateTime(source.actualAt)}',
                  ),
                  onPressed: () => _pickTime(context, displayed: false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              offset == null
                  ? '오차: 미계산 (시각 2개를 모두 입력하세요)'
                  : '오차: ${TimeCalcService.formatOffset(offset)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(),
            Row(
              children: [
                Text(
                  '기록 ${events.length}건',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('기록 추가'),
                  onPressed: offset == null
                      ? null
                      : () => showEventSheet(context, caseId, source),
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
                  title: Text(
                    e.memo.isEmpty ? '(메모 없음)' : e.memo,
                  ),
                  subtitle: Text(
                    '보정 ${formatDateTime(e.correctedAt)} '
                    '(영상 ${formatDateTime(e.displayedAt)})'
                    '${e.photoPath.isEmpty ? '' : '\n사진: ${e.photoPath}'}',
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
        ),
      ),
    );
  }
}
