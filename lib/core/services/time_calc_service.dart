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

  /// 오프셋 ms를 사람이 읽기 쉬운 문장으로 포맷.
  /// 예: `CCTV가 2분 느림`, `CCTV가 1분 30초 빠름`.
  ///
  /// 부호 규약: 오프셋 = 실제 − 표시. 양수면 CCTV 시계가 실제보다
  /// 뒤처져 있으므로 "느림", 음수면 앞서 있으므로 "빠름".
  static String formatOffset(int millis) {
    if (millis == 0) return '시간 오차 없음';
    final abs = millis.abs();
    final d = abs ~/ 86400000;
    final h = (abs % 86400000) ~/ 3600000;
    final m = (abs % 3600000) ~/ 60000;
    final s = (abs % 60000) ~/ 1000;
    final ms = abs % 1000;
    final parts = <String>[];
    if (d > 0) parts.add('$d일');
    if (h > 0) parts.add('$h시간');
    if (m > 0) parts.add('$m분');
    if (s > 0 || ms > 0 || parts.isEmpty) {
      parts.add(ms > 0 ? '$s.${ms.toString().padLeft(3, '0')}초' : '$s초');
    }
    final pace = millis > 0 ? '느림' : '빠름';
    return 'CCTV가 ${parts.join(' ')} $pace';
  }
}
