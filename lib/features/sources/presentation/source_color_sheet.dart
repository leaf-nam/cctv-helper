import 'package:flutter/material.dart';

import '../../../core/theme/source_palette.dart';
import '../../../core/widgets/modal_sheet.dart';

/// CCTV 테마 색상 선택 시트 (#43).
///
/// 20개 테마 색 중 하나를 고르면 해당 인덱스를 반환한다.
Future<int?> showSourceColorSheet(
  BuildContext context, {
  required String sourceName,
  required int selectedIndex,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _SourceColorSheet(sourceName: sourceName, selectedIndex: selectedIndex),
  );
}

class _SourceColorSheet extends StatelessWidget {
  final String sourceName;
  final int selectedIndex;

  const _SourceColorSheet({
    required this.sourceName,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: modalSheetPadding(context),
        child: Column(
          key: const ValueKey('source-color-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CCTV 색상', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$sourceName CCTV를 구분할 색을 선택하세요.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < SourcePalette.colors.length; i++)
                  _ColorOption(
                    index: i,
                    selected: i == selectedIndex,
                    onTap: () => Navigator.of(context).pop(i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = SourcePalette.of(index);
    return Semantics(
      button: true,
      selected: selected,
      label: 'CCTV 색상 ${index + 1}',
      child: InkWell(
        key: ValueKey('source-color-option-$index'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}
