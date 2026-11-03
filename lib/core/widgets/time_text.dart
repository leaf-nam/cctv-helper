import 'package:flutter/material.dart';

import 'datetime_field.dart';

/// 날짜·시간을 일관된 크기와 대비로 표시하는 공용 위젯 (#35).
///
/// - 날짜: `bodyMedium`(14sp) 이상, 보조 색상으로 라벨과 구분
/// - 시간: 20sp(compact 16sp) · 굵기 600 · 고정폭 숫자
/// - 스크린리더에는 날짜+시간을 한 문장으로 읽어 준다.
class DateTimeText extends StatelessWidget {
  const DateTimeText({
    super.key,
    required this.value,
    this.label,
    this.compact = false,
    this.dateKey,
    this.timeKey,
    this.showLabel = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
  });

  final DateTime? value;

  /// `CCTV 시각`, `실제 시각` 같은 행 라벨.
  final String? label;

  /// 목록처럼 좁은 공간에서는 한 단계 작게 표시한다.
  final bool compact;

  final Key? dateKey;
  final Key? timeKey;
  final bool showLabel;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStyle =
        (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
    final timeStyle = TextStyle(
      fontSize: compact ? 16 : 20,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final semantic = [
      if (label != null) label!,
      formatDate(value),
      formatTime(value),
    ].join(' ');

    return Semantics(
      label: semantic,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            if (label != null && showLabel) ...[
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              formatDate(value),
              key: dateKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: dateStyle,
            ),
            const SizedBox(height: 1),
            Text(
              formatTime(value),
              key: timeKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: timeStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// 한 줄짜리 시각 표시 (`yyyy-MM-dd HH:mm:ss`).
///
/// 기록 목록처럼 세로 공간이 좁은 곳에서 날짜·시간을 한 행에 표시한다.
class DateTimeInlineText extends StatelessWidget {
  const DateTimeInlineText({
    super.key,
    required this.value,
    this.label,
    this.compact = false,
  });

  final DateTime? value;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w500,
            );
    return Text(
      [
        if (label != null) label!,
        formatDate(value),
        formatTime(value),
      ].join(' '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
