import 'package:flutter/material.dart';

import '../../features/sources/domain/cctv_source.dart';

/// CCTV별 색상 팔레트 (#7, #28, #43).
///
/// 사건 상세·사진 보관함·통합 타임라인에서 같은 CCTV가 같은 색을 쓰도록
/// 사건 내 CCTV의 `colorIndex`를 기준으로 색을 배정한다. 사용자가 고르지
/// 않았으면 사건 내 순서를 기본값으로 쓴다.
///
/// 20개 색상은 같은 채도·명도에서 색상(hue)만 균등하게 나눈 테마 색이다.
class SourcePalette {
  static const int colorCount = 20;

  static final List<Color> colors = List.unmodifiable(
    List<Color>.generate(colorCount, (index) {
      final hue = (210 + index * 360 / colorCount) % 360;
      return HSLColor.fromAHSL(1, hue, 0.62, 0.44).toColor();
    }),
  );

  static Color of(int index) => colors[index.abs() % colors.length];

  /// CCTV에 저장된 색이 있으면 그 색, 없으면 [fallbackIndex] 순서 색.
  static Color ofSource(CctvSource source, int fallbackIndex) =>
      of(source.colorIndex ?? fallbackIndex);

  /// 사건 내 CCTV 목록에서 [sourceId]의 색. 목록에 없으면 이름 해시로 배정.
  static Color forSource(
    List<CctvSource> sources,
    String sourceId, {
    int fallbackIndex = 0,
  }) {
    final index = sources.indexWhere((e) => e.id == sourceId);
    if (index >= 0) return ofSource(sources[index], index);
    if (fallbackIndex != 0) return of(fallbackIndex);
    return of(sourceId.hashCode);
  }
}
