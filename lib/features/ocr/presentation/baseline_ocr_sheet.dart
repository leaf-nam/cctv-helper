import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/photo_storage_service.dart';
import '../../../core/services/time_calc_service.dart';
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

/// 실제시간 화면과 CCTV LIVE 화면 사진을 각각 인식해 기준 시각 2개를 채운다.
///
/// 자동 확정하지 않는다. 사용자가 인식 결과를 확인·수정한 뒤 `적용`을 눌러야
/// 오프셋이 저장된다.
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
  bool loading = false;
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
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _actual.time = widget.source.actualAt;
    _displayed.time = widget.source.displayedAt;
  }

  Future<void> _pick(ImageSource from, {required bool actual}) async {
    final slot = actual ? _actual : _displayed;
    try {
      final file = await widget.imagePicker.pickImage(source: from);
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        slot.path = file.path;
        slot.info = null;
      });
      await _recognize(file.path, actual: actual);
    } catch (_) {
      if (!mounted) return;
      setState(() => slot.info = '사진을 가져올 수 없습니다.');
    }
  }

  Future<void> _recognize(String path, {required bool actual}) async {
    final slot = actual ? _actual : _displayed;
    setState(() => slot.loading = true);
    final text = await widget.ocrService.recognizeText(path);
    final fallback = actual
        ? DateTime.now()
        : (_displayed.time ?? widget.source.displayedAt ?? DateTime.now());
    final candidate = text == null
        ? null
        : TimestampParser.parse(text, fallbackDate: fallback);
    if (!mounted) return;
    setState(() {
      slot.loading = false;
      if (candidate == null) {
        slot.info = '시각을 인식하지 못했습니다. 직접 입력하세요.';
      } else {
        slot.time = candidate.value;
        slot.info = '인식 ${candidate.confidenceLabel} · 확인 후 적용하세요.';
      }
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
    if (!mounted) return;
    Navigator.of(context)
        .pop(BaselineOcrResult(actualAt: actualAt, displayedAt: displayedAt));
  }

  Widget _slot({
    required bool actual,
    required String label,
    required IconData icon,
    required Key keyPrefix,
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
              if (slot.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slot.path.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(PhotoStorageService.resolve(slot.path)),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: DateTimeText(
                  value: slot.time,
                  label: '인식/입력 시각',
                  timeKey: ValueKey('$keyPrefix-time'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera, size: 18),
                label: const Text('촬영'),
                onPressed: slot.loading
                    ? null
                    : () => _pick(ImageSource.camera, actual: actual),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('앨범'),
                onPressed: slot.loading
                    ? null
                    : () => _pick(ImageSource.gallery, actual: actual),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('직접 입력'),
                onPressed: () => _editTime(actual: actual),
              ),
            ],
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
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('사진으로 기준 입력', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '실제시간이 보이는 화면과 CCTV LIVE 화면을 각각 촬영하세요. '
              '인식 결과는 적용 전에 수정할 수 있습니다.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _slot(
              actual: true,
              label: '실제시간 화면',
              icon: Icons.access_time,
              keyPrefix: const ValueKey('baseline-actual'),
            ),
            const SizedBox(height: 10),
            _slot(
              actual: false,
              label: 'CCTV 화면',
              icon: Icons.videocam,
              keyPrefix: const ValueKey('baseline-cctv'),
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
