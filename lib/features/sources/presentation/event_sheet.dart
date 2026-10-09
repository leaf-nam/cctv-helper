import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/datetime_field.dart';
import '../../../core/widgets/time_edit_sheet.dart';
import '../../events/providers/events_provider.dart';
import '../../sources/domain/cctv_source.dart';

/// 기록(메모·사진) 입력 시트 (#3).
/// 사진은 경로 타이핑이 아니라 카메라 촬영·앨범 선택으로 첨부한다.
/// [initialDisplayed]가 있으면 영상 시각 초기값으로 사용한다
/// (시간 확인칸의 조회 시간 이어쓰기).
Future<void> showEventSheet(
  BuildContext context,
  String caseId,
  CctvSource source, {
  DateTime? initialDisplayed,
}) async {
  final memoController = TextEditingController();
  final picker = ImagePicker();
  DateTime displayed =
      initialDisplayed ?? source.displayedAt ?? DateTime.now();
  String photoPath = '';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickPhoto(ImageSource from) async {
            try {
              final file = await picker.pickImage(source: from);
              if (file == null) return;
              setState(() => photoPath = file.path);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('사진을 가져올 수 없습니다.')),
              );
            }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${source.name} 기록 추가',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '영상 시각: ${formatDateTime(displayed)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('입력'),
                      onPressed: () => showTimeEditSheet(
                        context,
                        title: '사건 영상 시각 입력',
                        initial: displayed,
                        onChanged: (v) async =>
                            setState(() => displayed = v),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: memoController,
                  decoration: const InputDecoration(labelText: '기록 메모'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (photoPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photoPath),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => const SizedBox(
                              width: 72,
                              height: 72,
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('사진 찍기'),
                            onPressed: () =>
                                pickPhoto(ImageSource.camera),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('앨범에서 선택'),
                            onPressed: () =>
                                pickPhoto(ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          photoPath: photoPath,
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
}
