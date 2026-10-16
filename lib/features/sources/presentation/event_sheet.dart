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
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _EventSheetBody(
      caseId: caseId,
      source: source,
      initialDisplayed:
          initialDisplayed ?? source.displayedAt ?? DateTime.now(),
    ),
  );
}

/// 시트 본문.
/// 메모 컨트롤러는 State가 소유하고 unmount 시점에 dispose한다.
/// `showModalBottomSheet`의 future는 pop 호출 즉시 완료되므로
/// 함수 지역 컨트롤러를 거기서 dispose하면 pop 애니메이션·키보드 정리
/// 리빌드와 경합해 "used after being disposed" 크래시가 난다.
class _EventSheetBody extends StatefulWidget {
  final String caseId;
  final CctvSource source;
  final DateTime initialDisplayed;

  const _EventSheetBody({
    required this.caseId,
    required this.source,
    required this.initialDisplayed,
  });

  @override
  State<_EventSheetBody> createState() => _EventSheetBodyState();
}

class _EventSheetBodyState extends State<_EventSheetBody> {
  late final TextEditingController _memoController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late DateTime _displayed = widget.initialDisplayed;
  String _photoPath = '';
  bool _saving = false;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource from) async {
    try {
      final file = await _picker.pickImage(source: from);
      if (file == null) return;
      if (!mounted) return;
      setState(() => _photoPath = file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 가져올 수 없습니다.')),
      );
    }
  }

  /// 저장 연타 가드: 첫 탭 이후 버튼을 비활성화하고 중복 호출을 막는다.
  /// 두 번째 pop이 아래 상세 화면까지 닫아버리는 사고를 방지한다.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<EventsProvider>().addEvent(
        caseId: widget.caseId,
        source: widget.source,
        displayedAt: _displayed,
        memo: _memoController.text,
        photoPath: _photoPath,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록을 저장할 수 없습니다.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            '${widget.source.name} 기록 추가',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '영상 시각: ${formatDateTime(_displayed)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_calendar),
                label: const Text('입력'),
                onPressed: () => showTimeEditSheet(
                  context,
                  title: '사건 영상 시각 입력',
                  initial: _displayed,
                  onChanged: (v) async {
                    if (!mounted) return;
                    setState(() => _displayed = v);
                  },
                ),
              ),
            ],
          ),
          TextField(
            controller: _memoController,
            decoration: const InputDecoration(labelText: '기록 메모'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_photoPath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photoPath),
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
                      onPressed: () => _pickPhoto(ImageSource.camera),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('앨범에서 선택'),
                      onPressed: () => _pickPhoto(ImageSource.gallery),
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
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
