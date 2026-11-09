import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/photo_storage_service.dart';
import '../../../core/services/time_calc_service.dart';
import '../../../core/theme/source_palette.dart';
import '../../../core/widgets/datetime_field.dart';
import '../../../core/widgets/time_text.dart';
import '../../cases/providers/cases_provider.dart';
import '../../events/providers/events_provider.dart';
import '../../photos/providers/photos_provider.dart';
import '../../sources/domain/cctv_source.dart';
import '../../sources/providers/sources_provider.dart';
import '../domain/timeline_entry.dart';

/// 사건 하나의 모든 CCTV 기록·사진을 보정 실제시간 기준으로 합친
/// 통합 타임라인 화면 (`/case/:id/timeline`, #7).
class CaseTimelineScreen extends StatefulWidget {
  final String caseId;

  const CaseTimelineScreen({super.key, required this.caseId});

  @override
  State<CaseTimelineScreen> createState() => _CaseTimelineScreenState();
}

class _TimelineRow {
  const _TimelineRow.header(this.date, this.count) : entry = null;
  const _TimelineRow.entry(this.entry) : date = null, count = 0;

  final String? date;
  final int count;
  final TimelineEntry? entry;
}

class _CaseTimelineScreenState extends State<CaseTimelineScreen> {
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
    final events = context.watch<EventsProvider>().byCase(widget.caseId);
    final photos = context.watch<PhotosProvider>().byCase(widget.caseId);
    final all = TimelineEntry.build(events: events, photos: photos);
    final entries = _filterSourceId == null
        ? all
        : all.where((e) => e.sourceId == _filterSourceId).toList();
    final rows = _buildRows(entries);

    return Scaffold(
      appBar: AppBar(
        title: Text('${caseFile.title} 타임라인'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/case/${widget.caseId}'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (sources.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('전체'),
                      selected: _filterSourceId == null,
                      onSelected: (_) => setState(() => _filterSourceId = null),
                    ),
                    const SizedBox(width: 6),
                    for (var i = 0; i < sources.length; i++) ...[
                      FilterChip(
                        key: ValueKey('timeline-filter-${sources[i].id}'),
                        avatar: CircleAvatar(
                          backgroundColor: SourcePalette.ofSource(
                            sources[i],
                            i,
                          ),
                          radius: 7,
                        ),
                        label: Text(sources[i].name),
                        selected: _filterSourceId == sources[i].id,
                        onSelected: (_) =>
                            setState(() => _filterSourceId = sources[i].id),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: rows.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      key: const ValueKey('case-timeline-list'),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        if (row.date != null) {
                          return _DateHeader(date: row.date!, count: row.count);
                        }
                        final entry = row.entry!;
                        return _EntryTile(
                          entry: entry,
                          sources: sources,
                          onTap: () => _showDetail(entry, sources),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_TimelineRow> _buildRows(List<TimelineEntry> entries) {
    // 날짜별 건수를 먼저 세어 두고( O(n) ), 행을 만들 때 재사용한다.
    final counts = <String, int>{};
    for (final entry in entries) {
      final date = formatDate(entry.at);
      counts[date] = (counts[date] ?? 0) + 1;
    }
    final rows = <_TimelineRow>[];
    String? lastDate;
    for (final entry in entries) {
      final date = formatDate(entry.at);
      if (date != lastDate) {
        rows.add(_TimelineRow.header(date, counts[date] ?? 0));
        lastDate = date;
      }
      rows.add(_TimelineRow.entry(entry));
    }
    return rows;
  }

  Future<void> _showDetail(
    TimelineEntry entry,
    List<CctvSource> sources,
  ) async {
    CctvSource? source;
    for (final item in sources) {
      if (item.id == entry.sourceId) {
        source = item;
        break;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _EntryDetailSheet(
        entry: entry,
        source: source,
        color: SourcePalette.forSource(sources, entry.sourceId),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;
  final int count;

  const _DateHeader({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            date,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count건',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final TimelineEntry entry;
  final List<CctvSource> sources;
  final VoidCallback onTap;

  const _EntryTile({
    required this.entry,
    required this.sources,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SourcePalette.forSource(sources, entry.sourceId);
    CctvSource? source;
    for (final item in sources) {
      if (item.id == entry.sourceId) {
        source = item;
        break;
      }
    }
    final title = entry.memo.isEmpty
        ? (entry.isPhoto ? '${entry.kindLabel} 사진' : '(메모 없음)')
        : entry.memo;
    return SizedBox(
      height: 78,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                formatTime(entry.at),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: ValueKey('timeline-entry-${entry.id}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        if (entry.photoPaths.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(
                                  PhotoStorageService.resolve(
                                    entry.photoPaths.first,
                                  ),
                                ),
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (context, _, __) => Container(
                                  width: 46,
                                  height: 46,
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                                  Flexible(
                                    child: Text(
                                      '${source?.name ?? 'CCTV 미지정'} · '
                                      '${entry.kindLabel}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  if (entry.offsetMillis != null) ...[
                                    const SizedBox(width: 6),
                                    _OffsetBadge(millis: entry.offsetMillis!),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffsetBadge extends StatelessWidget {
  final int millis;

  const _OffsetBadge({required this.millis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        TimeCalcService.formatOffsetShort(millis),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.timeline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '아직 기록이나 사진이 없습니다.\nCCTV 카드에서 기록을 추가하거나 '
              '사진을 보관해 보세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailSheet extends StatelessWidget {
  final TimelineEntry entry;
  final CctvSource? source;
  final Color color;

  const _EntryDetailSheet({
    required this.entry,
    required this.source,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${source?.name ?? 'CCTV 미지정'} · ${entry.kindLabel}',
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
            if (entry.photoPaths.isNotEmpty)
              for (final path in entry.photoPaths)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(PhotoStorageService.resolve(path)),
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, __) => Container(
                        height: 140,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            if (entry.displayedAt != null)
              _DetailRow(
                label: 'CCTV 시각',
                child: DateTimeInlineText(value: entry.displayedAt),
              ),
            _DetailRow(
              label: '보정 실제시간',
              child: DateTimeInlineText(value: entry.at),
            ),
            if (entry.offsetMillis != null)
              _DetailRow(
                label: '오프셋',
                child: Text(
                  '${TimeCalcService.formatOffsetShort(entry.offsetMillis!)} '
                  '(${entry.offsetMillis}ms)',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            _DetailRow(
              label: '메모',
              child: Text(
                entry.memo.isEmpty ? '(메모 없음)' : entry.memo,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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
