import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/photo_storage_service.dart';
import '../../../core/services/time_calc_service.dart';
import '../../../core/theme/source_palette.dart';
import '../../../core/widgets/modal_sheet.dart';
import '../../../core/widgets/datetime_field.dart';
import '../../../core/widgets/time_text.dart';
import '../../cases/providers/cases_provider.dart';
import '../../sources/domain/cctv_source.dart';
import '../../sources/providers/sources_provider.dart';
import '../domain/case_photo.dart';
import '../providers/photos_provider.dart';
import 'add_photo_sheet.dart';
import 'photo_viewer.dart';

/// 사건·CCTV별 사진 보관함 화면 (`/case/:id/photos`, #28).
class PhotosScreen extends StatefulWidget {
  final String caseId;

  const PhotosScreen({super.key, required this.caseId});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  String? _filterSourceId;

  @override
  Widget build(BuildContext context) {
    final caseFile = context.watch<CasesProvider>().getById(widget.caseId);
    if (caseFile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('사건을 찾을 수 없습니다.')),
      );
    }
    final sources = context.watch<SourcesProvider>().byCase(widget.caseId);
    final photos = context.watch<PhotosProvider>().byCase(widget.caseId);
    final visible = _filterSourceId == null
        ? photos
        : photos.where((e) => e.sourceId == _filterSourceId).toList();

    final groups = <String, List<CasePhoto>>{};
    for (final source in sources) {
      final group = visible.where((e) => e.sourceId == source.id).toList();
      if (group.isNotEmpty) groups[source.id] = group;
    }
    final unknown = visible
        .where((e) => !sources.any((s) => s.id == e.sourceId))
        .toList();
    if (unknown.isNotEmpty) groups[''] = unknown;

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 보관함'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/case/${widget.caseId}'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: photos.isEmpty
            ? _EmptyState(
                onAdd: () => _addPhoto(context, sources),
                hasSources: sources.isNotEmpty,
              )
            : Column(
                children: [
                  if (sources.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('전체'),
                            selected: _filterSourceId == null,
                            onSelected: (_) =>
                                setState(() => _filterSourceId = null),
                          ),
                          const SizedBox(width: 6),
                          for (var i = 0; i < sources.length; i++) ...[
                            FilterChip(
                              key: ValueKey('photo-filter-${sources[i].id}'),
                              avatar: CircleAvatar(
                                backgroundColor: SourcePalette.ofSource(
                                  sources[i],
                                  i,
                                ),
                                radius: 7,
                              ),
                              label: Text(sources[i].name),
                              selected: _filterSourceId == sources[i].id,
                              onSelected: (_) => setState(
                                () => _filterSourceId = sources[i].id,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(child: Text('해당 CCTV의 사진이 없습니다.'))
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 96),
                            children: [
                              for (final entry in groups.entries)
                                _Section(
                                  sources: sources,
                                  sourceId: entry.key,
                                  photos: entry.value,
                                  onChanged: () => setState(() {}),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPhoto(context, sources),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('사진 추가'),
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context, List<CctvSource> sources) async {
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('먼저 CCTV를 추가하세요.')));
      return;
    }
    await showAddPhotoSheet(
      context,
      caseId: widget.caseId,
      sources: sources,
      initialSourceId: _filterSourceId,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool hasSources;

  const _EmptyState({required this.onAdd, required this.hasSources});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasSources
                  ? '아직 보관한 사진이 없습니다.\n현장 사진과 CCTV 화면을 모아 두세요.'
                  : '먼저 CCTV를 추가한 뒤 사진을 보관할 수 있습니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (hasSources)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('사진 추가'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<CctvSource> sources;
  final String sourceId;
  final List<CasePhoto> photos;
  final VoidCallback onChanged;

  const _Section({
    required this.sources,
    required this.sourceId,
    required this.photos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = sources.indexWhere((e) => e.id == sourceId);
    final source = index >= 0 ? sources[index] : null;
    final color = SourcePalette.forSource(sources, sourceId);
    final offset = source?.offsetMillis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  source?.name ?? 'CCTV 미지정',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (offset != null)
                Text(
                  TimeCalcService.formatOffsetShort(offset),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                '${photos.length}장',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 500 ? 2 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, i) => _PhotoTile(
                  photo: photos[i],
                  color: color,
                  onTap: () => _openViewer(context, photos[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 사진을 누르면 상세 시트 대신 바로 전체화면으로 연다 (#46).
  Future<void> _openViewer(BuildContext context, CasePhoto photo) async {
    final index = sources.indexWhere((e) => e.id == sourceId);
    final source = index >= 0 ? sources[index] : null;
    await showPhotoViewer(
      context,
      photo: photo,
      sourceName: source?.name ?? 'CCTV 미지정',
      onShowDetail: () => _showDetail(context, photo),
    );
  }

  Future<void> _showDetail(BuildContext context, CasePhoto photo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PhotoDetailSheet(photo: photo),
    );
    onChanged();
  }
}

class _PhotoTile extends StatelessWidget {
  final CasePhoto photo;
  final Color color;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.photo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = photo.correctedAt ?? photo.capturedAt;
    return Semantics(
      button: true,
      label: '${photo.kind.label} 사진, ${formatDateTime(time)}',
      child: InkWell(
        key: ValueKey('photo-tile-${photo.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: photo.filePath.isEmpty
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image),
                      )
                    : Image.file(
                        File(PhotoStorageService.resolve(photo.filePath)),
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
              ),
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            photo.kind.label,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    DateTimeInlineText(value: time, compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoDetailSheet extends StatefulWidget {
  final CasePhoto photo;

  const _PhotoDetailSheet({required this.photo});

  @override
  State<_PhotoDetailSheet> createState() => _PhotoDetailSheetState();
}

class _PhotoDetailSheetState extends State<_PhotoDetailSheet> {
  late CasePhoto _photo = widget.photo;

  Future<void> _editMemo() async {
    var memo = _photo.memo;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('메모 수정'),
        content: TextFormField(
          initialValue: memo,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          onChanged: (value) => memo = value,
          decoration: const InputDecoration(
            labelText: '메모',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(memo),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    await context.read<PhotosProvider>().updateMemo(_photo.id, result);
    if (!mounted) return;
    final next = context.read<PhotosProvider>().getById(_photo.id);
    if (next != null) setState(() => _photo = next);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<PhotosProvider>().removePhoto(_photo.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = context.watch<SourcesProvider>().byCase(_photo.caseId);
    CctvSource? source;
    for (final item in sources) {
      if (item.id == _photo.sourceId) {
        source = item;
        break;
      }
    }
    return SingleChildScrollView(
      child: Padding(
        padding: modalSheetPadding(context, extra: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${source?.name ?? 'CCTV 미지정'} · ${_photo.kind.label}',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_photo.filePath.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(PhotoStorageService.resolve(_photo.filePath)),
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, __) => Container(
                      height: 160,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _MetaRow(
              label: '촬영 시각',
              child: DateTimeInlineText(value: _photo.capturedAt),
            ),
            if (_photo.displayedAt != null)
              _MetaRow(
                label: 'CCTV 시각',
                child: DateTimeInlineText(value: _photo.displayedAt),
              ),
            if (_photo.offsetMillis != null)
              _MetaRow(
                label: '오프셋',
                child: Text(
                  TimeCalcService.formatOffsetFull(_photo.offsetMillis!),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (_photo.correctedAt != null)
              _MetaRow(
                label: '보정 실제시간',
                child: DateTimeInlineText(value: _photo.correctedAt),
              ),
            _MetaRow(
              label: '메모',
              child: Text(
                _photo.memo.isEmpty ? '(메모 없음)' : _photo.memo,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                    onPressed: _delete,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('메모 수정'),
                    onPressed: _editMemo,
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

class _MetaRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _MetaRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
