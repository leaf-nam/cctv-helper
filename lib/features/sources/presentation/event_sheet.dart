import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/datetime_field.dart';
import '../../events/providers/events_provider.dart';
import '../../sources/domain/cctv_source.dart';

/// 기록(메모·사진 경로) 입력 시트 (#3).
Future<void> showEventSheet(
  BuildContext context,
  String caseId,
  CctvSource source,
) async {
  final memoController = TextEditingController();
  final photoController = TextEditingController();
  DateTime displayed = source.displayedAt ?? DateTime.now();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${source.name} 기록 추가',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ActionChip(
                  label: Text('영상 시각: ${formatDateTime(displayed)}'),
                  onPressed: () async {
                    final picked =
                        await pickDateTime(context, displayed);
                    if (picked != null) {
                      setState(() => displayed = picked);
                    }
                  },
                ),
                TextField(
                  controller: memoController,
                  decoration: const InputDecoration(labelText: '기록 메모'),
                  maxLines: 2,
                ),
                TextField(
                  controller: photoController,
                  decoration: const InputDecoration(
                    labelText: '사진 경로 (선택)',
                    hintText: '예: /sdcard/cctv/img_001.jpg',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await sheetContext.read<EventsProvider>().addEvent(
                          caseId: caseId,
                          source: source,
                          displayedAt: displayed,
                          memo: memoController.text,
                          photoPath: photoController.text,
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
  memoController.dispose();
  photoController.dispose();
}
