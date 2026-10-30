import 'package:flutter/material.dart';

import '../../features/sources/domain/cctv_source.dart';

/// CCTV별 색상 팔레트 (#7, #28).
///
/// 사건 상세·사진 보관함·통합 타임라인에서 같은 CCTV가 같은 색을 쓰도록
/// 사건 내 CCTV 순서를 기준으로 색을 배정한다.
class SourcePalette {
  static const List<Color> colors = [
    Color(0xFF1565C0), // blue
    Color(0xFF00897B), // teal
    Color(0xFFEF6C00), // orange
    Color(0xFF6A1B9A), // purple
    Color(0xFF2E7D32), // green
    Color(0xFFC62828), // red
    Color(0xFF00838F), // cyan
    Color(0xFF5D4037), // brown
  ];

  static Color of(int index) => colors[index.abs() % colors.length];

  /// 사건 내 CCTV 목록에서 [sourceId]의 색. 목록에 없으면 이름 해시로 배정.
  static Color forSource(
    List<CctvSource> sources,
    String sourceId, {
    int fallbackIndex = 0,
  }) {
    final index = sources.indexWhere((e) => e.id == sourceId);
    if (index >= 0) return of(index);
    if (fallbackIndex != 0) return of(fallbackIndex);
    return of(sourceId.hashCode);
  }
}
