import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/photo_storage_service.dart';
import '../../../core/services/time_calc_service.dart';
import '../../../core/widgets/modal_sheet.dart';
import '../../../core/widgets/time_edit_sheet.dart';
import '../../../core/widgets/time_text.dart';
import '../../ocr/data/ocr_service.dart';
import '../../ocr/domain/timestamp_parser.dart';
import '../../sources/domain/cctv_source.dart';
import '../domain/case_photo.dart';
import '../providers/photos_provider.dart';

/// 사진 보관함에 사진을 추가하는 시트 (#28).
///
/// CCTV·유형·메모를 고르고, 필요하면 사진에서 시각을 인식해 보정 실제시간을
/// 자동으로 채운다. 저장 전 사용자 확인을 거친다.
Future<void> showAddPhotoSheet(
  BuildContext context, {
  required String caseId,
  required List<CctvSource> sources,
  String? initialSourceId,
  OcrService? ocrService,
  ImagePicker? imagePicker,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddPhotoSheetBody(
      caseId: caseId,
      sources: sources,
      initialSourceId: initialSourceId,
      ocrService: ocrService ?? createOcrService(),
      imagePicker: imagePicker ?? ImagePicker(),
    ),
  );
}

class _AddPhotoSheetBody extends StatefulWidget {
  final String caseId;
  final List<CctvSource> sources;
  final String? initialSourceId;
  final OcrService ocrService;
  final ImagePicker imagePicker;

  const _AddPhotoSheetBody({
    required this.caseId,
    required this.sources,
    required this.initialSourceId,
    required this.ocrService,
    required this.imagePicker,
  });

  @override
  State<_AddPhotoSheetBody> createState() => _AddPhotoSheetBodyState();
}

class _AddPhotoSheetBodyState extends State<_AddPhotoSheetBody> {
  final _memo = TextEditingController();
  CasePhotoKind _kind = CasePhotoKind.scene;
  String? _sourceId;
  String _path = '';
  DateTime? _displayedAt;
  String? _info;
  String? _error;
  bool _recognizing = false;
  bool _saving = false;

  CctvSource? get _source {
    final id = _sourceId;
    if (id == null) return null;
    for (final source in widget.sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _sourceId =
        widget.initialSourceId ??
        (widget.sources.isEmpty ? null : widget.sources.first.id);
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource from) async {
    try {
      final file = await widget.imagePicker.pickImage(source: from);
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        _path = file.path;
        _info = null;
        _error = null;
      });
      await _recognize();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '사진을 가져올 수 없습니다.');
    }
  }

  Future<void> _chooseAndPick() async {
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
    await _pick(source);
  }

  Future<void> _recognize() async {
    if (_path.isEmpty) return;
    setState(() {
      _recognizing = true;
      _info = null;
    });
    final text = await widget.ocrService.recognizeText(_path);
    final candidate = text == null
        ? null
        : TimestampParser.parse(text, fallbackDate: DateTime.now());
    if (!mounted) return;
    setState(() {
      _recognizing = false;
      if (candidate == null) {
        _info = '시각을 인식하지 못했습니다. 직접 입력하세요.';
      } else {
        _displayedAt = candidate.value;
        _info = '인식된 CCTV 시각 ${candidate.confidenceLabel}';
      }
    });
  }

  Future<void> _editDisplayedAt() async {
    await showTimeEditSheet(
      context,
      title: 'CCTV 표시 시각',
      initial: _displayedAt ?? DateTime.now(),
      onApply: (value) async {
        if (!mounted) return;
        setState(() => _displayedAt = value);
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final source = _source;
    if (source == null) {
      setState(() => _error = 'CCTV를 선택하세요.');
      return;
    }
    if (_path.isEmpty) {
      setState(() => _error = '사진을 추가하세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final photo = await context.read<PhotosProvider>().addPhoto(
      caseId: widget.caseId,
      sourceId: source.id,
      filePath: _path,
      kind: _kind,
      displayedAt: _displayedAt,
      offsetMillis: source.offsetMillis,
      memo: _memo.text,
    );
    if (!mounted) return;
    if (photo == null) {
      setState(() {
        _saving = false;
        _error = '사진을 저장할 수 없습니다.';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = _source;
    final offset = source?.offsetMillis;
    final corrected = _displayedAt != null && offset != null
        ? TimeCalcService.correctedAt(
            displayedAt: _displayedAt!,
            offsetMillis: offset,
          )
        : null;
    return SingleChildScrollView(
      child: Padding(
        padding: modalSheetPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('사진 추가', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            if (widget.sources.isEmpty)
              const Text('먼저 CCTV를 추가하세요.')
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('photo-source'),
                initialValue: _sourceId,
                decoration: const InputDecoration(
                  labelText: 'CCTV',
                  isDense: true,
                ),
                items: [
                  for (final s in widget.sources)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (value) => setState(() => _sourceId = value),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final kind in CasePhotoKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_path.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(PhotoStorageService.resolve(_path)),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) => const SizedBox(
                          width: 84,
                          height: 84,
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
                        onPressed: _saving
                            ? null
                            : () => _pick(ImageSource.camera),
                      ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('앨범에서 선택'),
                        onPressed: _saving
                            ? null
                            : () => _pick(ImageSource.gallery),
                      ),
                      const SizedBox(height: 4),
                      FilledButton.tonalIcon(
                        key: const ValueKey('photo-ocr'),
                        icon: _recognizing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.document_scanner, size: 18),
                        label: const Text('시각 인식'),
                        onPressed: _recognizing || _saving
                            ? null
                            : (_path.isEmpty ? _chooseAndPick : _recognize),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _info!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DateTimeText(
                    value: _displayedAt,
                    label: 'CCTV 표시 시각',
                    timeKey: const ValueKey('photo-displayed-at'),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('입력'),
                  onPressed: _saving ? null : _editDisplayedAt,
                ),
              ],
            ),
            const SizedBox(height: 4),
            DateTimeText(
              value: corrected,
              label: '보정 실제시간',
              compact: true,
              timeKey: const ValueKey('photo-corrected-at'),
            ),
            if (corrected == null && _displayedAt != null)
              Text(
                'CCTV 오프셋이 없어 보정 시간은 비워 둡니다.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모', isDense: true),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('photo-save'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장'),
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
