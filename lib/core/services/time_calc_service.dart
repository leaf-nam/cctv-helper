/// 시간 오차 계산 서비스 (순수 함수, 위젯 의존 없음).
///
/// 규약: `보정시각 = 표시시각 + 오프셋`, `오프셋 = 실제시각 - 표시시각` (ms 정수).
class TimeCalcService {
  /// 실제시각 - 표시시각을 ms 정수로 반환.
  static int offsetMillis({
    required DateTime displayedAt,
    required DateTime actualAt,
  }) {
    return actualAt.difference(displayedAt).inMilliseconds;
  }

  /// 표시시각 + 오프셋으로 보정시각을 반환.
  static DateTime correctedAt({
    required DateTime displayedAt,
    required int offsetMillis,
  }) {
    return displayedAt.add(Duration(milliseconds: offsetMillis));
  }

  /// 오프셋 ms를 `+1시간 2분 3초 (+3723000ms)` 형태로 포맷.
  static String formatOffset(int millis) {
    final sign = millis < 0 ? '-' : '+';
    final abs = millis.abs();
    final h = abs ~/ 3600000;
    final m = (abs % 3600000) ~/ 60000;
    final s = (abs % 60000) ~/ 1000;
    final ms = abs % 1000;
    final parts = <String>[];
    if (h > 0) parts.add('$h시간');
    if (m > 0 || h > 0) parts.add('$m분');
    parts.add(ms > 0 ? '$s.${ms.toString().padLeft(3, '0')}초' : '$s초');
    return '$sign${parts.join(' ')} ($sign${abs}ms)';
  }
}
