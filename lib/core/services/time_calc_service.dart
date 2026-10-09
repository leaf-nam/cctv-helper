/// 시간 오차 계산 서비스 (순수 함수, 위젯 의존 없음).
///
/// 규약: `보정시각 = 표시시각 + 오프셋`, `오프셋 = 실제시각 - 표시시각` (ms 정수).
class TimeCalcService {
  /// 초 미만 버림. 모든 계산은 초 단위로만 수행한다.
  static DateTime truncateToSecond(DateTime value) {
    if (value.isUtc) {
      return DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      );
    }
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
  }

  /// 실제시각 - 표시시각을 ms 정수로 반환 (초 단위 계산, 밀리초 버림).
  static int offsetMillis({
    required DateTime displayedAt,
    required DateTime actualAt,
  }) {
    return truncateToSecond(
      actualAt,
    ).difference(truncateToSecond(displayedAt)).inMilliseconds;
  }

  /// 표시시각 + 오프셋으로 보정시각을 반환 (초 단위).
  static DateTime correctedAt({
    required DateTime displayedAt,
    required int offsetMillis,
  }) {
    return truncateToSecond(
      displayedAt,
    ).add(Duration(milliseconds: offsetMillis));
  }

  /// 오프셋 ms를 사람이 읽기 쉬운 문장으로 포맷 (초 단위까지만, 내림).
  /// 예: `CCTV가 2분 0초 느림`, `CCTV가 1분 30초 빠름`, `CCTV가 0초 느림`.
  ///
  /// 부호 규약: 오프셋 = 실제 − 표시. 양수면 CCTV 시계가 실제보다
  /// 뒤처져 있으므로 "느림", 음수면 앞서 있으므로 "빠름".
  /// 초 미만은 버린다 (내림). 초 단위 표기는 항상 포함한다 (0초 포함).
  static String formatOffset(int millis) {
    if (millis == 0) return '시간 오차 없음';
    final totalSeconds = millis.abs() ~/ 1000;
    final d = totalSeconds ~/ 86400;
    final h = (totalSeconds % 86400) ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final parts = <String>[];
    if (d > 0) parts.add('$d일');
    if (h > 0) parts.add('$h시간');
    if (m > 0) parts.add('$m분');
    parts.add('$s초');
    final pace = millis > 0 ? '느림' : '빠름';
    return 'CCTV가 ${parts.join(' ')} $pace';
  }
}
