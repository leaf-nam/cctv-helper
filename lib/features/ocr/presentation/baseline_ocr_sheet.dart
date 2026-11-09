import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/photo_storage_service.dart';
import '../../../core/services/time_calc_service.dart';
import '../../../core/widgets/datetime_field.dart';
import '../../../core/widgets/modal_sheet.dart';
import '../../../core/widgets/time_edit_sheet.dart';
import '../../../core/widgets/time_text.dart';
import '../../photos/domain/case_photo.dart';
import '../../photos/providers/photos_provider.dart';
import '../../sources/domain/cctv_source.dart';
import '../data/ocr_service.dart';
import '../domain/timestamp_parser.dart';

/// 기준 촬영 OCR 결과 (#27 A).
class BaselineOcrResult {
  const BaselineOcrResult({required this.actualAt, required this.displayedAt});

  final DateTime actualAt;
  final DateTime displayedAt;
}

/// 기준 시각 입력 시트 (#27 A, #42).
///
/// 사진은 **한 장만** 받는다. CCTV 화면과 실제 시계가 함께 찍힌 사진에서
/// 시각 후보를 추출한 뒤, 사용자가 각 후보를 실제시간/CCTV 시각에 지정한다.
/// 자동 확정하지 않고 `적용`을 눌러야 오프셋이 저장된다.
Future<BaselineOcrResult?> showBaselineOcrSheet(
  BuildContext context, {
  required String caseId,
  required CctvSource source,
  OcrService? ocrService,
  ImagePicker? imagePicker,
}) {
  return showModalBottomSheet<BaselineOcrResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BaselineOcrSheetBody(
      caseId: caseId,
      source: source,
      ocrService: ocrService ?? createOcrService(),
      imagePicker: imagePicker ?? ImagePicker(),
    ),
  );
}

class _SlotState {
  String path = '';
  DateTime? time;
  String? info;
}

class _BaselineOcrSheetBody extends StatefulWidget {
  final String caseId;
  final CctvSource source;
  final OcrService ocrService;
  final ImagePicker imagePicker;

  const _BaselineOcrSheetBody({
    required this.caseId,
    required this.source,
    required this.ocrService,
    required this.imagePicker,
  });

  @override
  State<_BaselineOcrSheetBody> createState() => _BaselineOcrSheetBodyState();
}

class _BaselineOcrSheetBodyState extends State<_BaselineOcrSheetBody> {
  final _actual = _SlotState();
  final _displayed = _SlotState();

  /// 한 장의 사진에서 추출한 시각 후보 (#42).
  String _photoPath = '';
  List<TimestampCandidate> _candidates = const [];
  bool _recognizing = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _actual.time = widget.source.actualAt;
    _displayed.time = widget.source.displayedAt;
  }

  Future<void> _pickPhoto(ImageSource from) async {
    try {
      final file = await widget.imagePicker.pickImage(source: from);
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        _photoPath = file.path;
        _candidates = const [];
        _recognizing = true;
      });
      final text = await widget.ocrService.recognizeText(file.path);
      final candidates = text == null
          ? const <TimestampCandidate>[]
          : TimestampParser.candidates(
              text,
              fallbackDate: widget.source.displayedAt ?? DateTime.now(),
            );
      if (!mounted) return;
      setState(() {
        _recognizing = false;
        _candidates = candidates;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recognizing = false;
        _candidates = const [];
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('사진을 가져올 수 없습니다.')));
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('사진 찍기'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickPhoto(source);
  }

  void _assign(TimestampCandidate candidate, {required bool actual}) {
    final slot = actual ? _actual : _displayed;
    final other = actual ? _displayed : _actual;
    setState(() {
      // 같은 후보를 양쪽 슬롯에 동시에 쓰지 않는다.
      // 반대쪽에 이미 같은 시각이 있으면 이 슬롯의 이전 시각과 교체한다.
      if (other.time == candidate.value) {
        other.time = slot.time == candidate.value ? null : slot.time;
        other.info = other.time == null
            ? '다른 후보를 선택하세요.'
            : '한 사진에서 선택한 시각으로 교체했습니다.';
      }
      slot.time = candidate.value;
      slot.path = _photoPath;
      slot.info = actual ? '실제시간으로 지정했습니다.' : 'CCTV 시각으로 지정했습니다.';
    });
  }

  Future<void> _editTime({required bool actual}) async {
    final slot = actual ? _actual : _displayed;
    await showTimeEditSheet(
      context,
      title: actual ? '실제 시간 입력' : 'CCTV 표시 시각 입력',
      initial: slot.time ?? DateTime.now(),
      onApply: (value) async {
        if (!mounted) return;
        setState(() {
          slot.time = value;
          slot.info = '직접 입력한 시각입니다.';
        });
      },
    );
  }

  Future<void> _apply() async {
    if (_applying) return;
    final actualAt = _actual.time;
    final displayedAt = _displayed.time;
    if (actualAt == null || displayedAt == null) {
      setState(() {
        final target = actualAt == null ? _actual : _displayed;
        target.info = '실제시간과 CCTV 시각을 모두 입력해야 합니다.';
      });
      return;
    }
    setState(() => _applying = true);
    final offset = TimeCalcService.offsetMillis(
      displayedAt: displayedAt,
      actualAt: actualAt,
    );
    final photos = context.read<PhotosProvider>();
    final shared = _actual.path.isNotEmpty && _actual.path == _displayed.path;
    if (shared) {
      // 한 장으로 두 시각을 읽은 경우 같은 사진을 두 번 저장하지 않는다.
      await photos.addPhoto(
        caseId: widget.caseId,
        sourceId: widget.source.id,
        filePath: _actual.path,
        kind: CasePhotoKind.baseline,
        capturedAt: actualAt,
        displayedAt: displayedAt,
        offsetMillis: offset,
        memo: '실제시간·CCTV 기준 촬영',
      );
    } else {
      if (_actual.path.isNotEmpty) {
        await photos.addPhoto(
          caseId: widget.caseId,
          sourceId: widget.source.id,
          filePath: _actual.path,
          kind: CasePhotoKind.baseline,
          capturedAt: actualAt,
          memo: '실제시간 기준 촬영',
        );
      }
      if (_displayed.path.isNotEmpty) {
        await photos.addPhoto(
          caseId: widget.caseId,
          sourceId: widget.source.id,
          filePath: _displayed.path,
          kind: CasePhotoKind.baseline,
          displayedAt: displayedAt,
          offsetMillis: offset,
          memo: 'CCTV 기준 촬영',
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context)
        .pop(BaselineOcrResult(actualAt: actualAt, displayedAt: displayedAt));
  }

  /// 사진에서 인식한 시각 후보를 실제시간/CCTV에 지정하는 영역 (#42).
  Widget _candidateSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '사진 한 장으로 시각 인식',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_recognizing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'CCTV 화면과 실제 시계가 함께 찍힌 사진 한 장을 선택하세요. '
            '인식된 시각을 실제시간/CCTV에 각각 지정합니다.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('baseline-shared-pick'),
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: Text(_photoPath.isEmpty ? '사진 선택' : '다른 사진 선택'),
              onPressed: _recognizing ? null : _choosePhotoSource,
            ),
          ),
          if (_photoPath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(PhotoStorageService.resolve(_photoPath)),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _candidates.isEmpty
                      ? Text(
                          _recognizing
                              ? '시각을 인식하는 중입니다...'
                              : '시각을 인식하지 못했습니다. 아래에서 직접 입력하세요.',
                          style: theme.textTheme.bodySmall,
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < _candidates.length; i++)
                              _CandidateRow(
                                candidate: _candidates[i],
                                index: i,
                                assignedActual:
                                    _actual.time == _candidates[i].value,
                                assignedDisplayed:
                                    _displayed.time == _candidates[i].value,
                                onAssignActual: () =>
                                    _assign(_candidates[i], actual: true),
                                onAssignDisplayed: () =>
                                    _assign(_candidates[i], actual: false),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 지정된 시각을 확인하고 직접 수정하는 슬롯 카드.
  Widget _slot({
    required bool actual,
    required String label,
    required IconData icon,
    required String keyPrefix,
  }) {
    final slot = actual ? _actual : _displayed;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              TextButton.icon(
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('직접 입력'),
                onPressed: () => _editTime(actual: actual),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DateTimeText(
            value: slot.time,
            label: '적용할 시각',
            timeKey: ValueKey('$keyPrefix-time'),
          ),
          if (slot.info != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                slot.info!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: modalSheetPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('사진으로 기준 입력', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '사진 한 장을 인식한 뒤, 실제시간과 CCTV 시각에 쓸 시각을 순서대로 '
              '지정하세요. 인식 결과는 적용 전에 수정할 수 있습니다.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _candidateSection(theme),
            const SizedBox(height: 10),
            _slot(
              actual: true,
              label: '실제시간',
              icon: Icons.access_time,
              keyPrefix: 'baseline-actual',
            ),
            const SizedBox(height: 10),
            _slot(
              actual: false,
              label: 'CCTV 시각',
              icon: Icons.videocam,
              keyPrefix: 'baseline-cctv',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _applying
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('baseline-apply'),
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

/// OCR 후보 1개와 실제시간/CCTV 지정 버튼.
class _CandidateRow extends StatelessWidget {
  final TimestampCandidate candidate;
  final int index;
  final bool assignedActual;
  final bool assignedDisplayed;
  final VoidCallback onAssignActual;
  final VoidCallback onAssignDisplayed;

  const _CandidateRow({
    required this.candidate,
    required this.index,
    required this.assignedActual,
    required this.assignedDisplayed,
    required this.onAssignActual,
    required this.onAssignDisplayed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${formatTime(candidate.value)} · ${candidate.confidenceLabel}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        TextButton(
          key: ValueKey('baseline-shared-actual-$index'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onAssignActual,
          child: Text(assignedActual ? '실제시간 ✓' : '실제시간'),
        ),
        TextButton(
          key: ValueKey('baseline-shared-cctv-$index'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onAssignDisplayed,
          child: Text(assignedDisplayed ? 'CCTV ✓' : 'CCTV'),
        ),
      ],
    );
  }
}
