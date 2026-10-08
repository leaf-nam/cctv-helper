import 'package:cctv_helper/core/services/time_calc_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeCalcService', () {
    test('CCTV가 2분 느리면 오프셋 +120000ms', () {
      final displayed = DateTime(2026, 10, 8, 14, 0, 0);
      final actual = DateTime(2026, 10, 8, 14, 2, 0);
      expect(
        TimeCalcService.offsetMillis(
          displayedAt: displayed,
          actualAt: actual,
        ),
        120000,
      );
    });

    test('CCTV가 90초 빠르면 오프셋 -90000ms', () {
      final displayed = DateTime(2026, 10, 8, 14, 2, 0);
      final actual = DateTime(2026, 10, 8, 14, 0, 30);
      expect(
        TimeCalcService.offsetMillis(
          displayedAt: displayed,
          actualAt: actual,
        ),
        -90000,
      );
    });

    test('보정시각 = 표시시각 + 오프셋', () {
      final displayed = DateTime(2026, 10, 8, 14, 0, 0);
      final corrected = TimeCalcService.correctedAt(
        displayedAt: displayed,
        offsetMillis: 120000,
      );
      expect(corrected, DateTime(2026, 10, 8, 14, 2, 0));
    });

    test('formatOffset 사람 읽기 쉬운 문장', () {
      expect(TimeCalcService.formatOffset(120000), 'CCTV가 2분 느림');
      expect(TimeCalcService.formatOffset(-90000), 'CCTV가 1분 30초 빠름');
      expect(
        TimeCalcService.formatOffset(90061000),
        'CCTV가 1일 1시간 1분 1초 느림',
      );
      expect(TimeCalcService.formatOffset(0), '시간 오차 없음');
      expect(TimeCalcService.formatOffset(1500), 'CCTV가 2초 느림');
      expect(TimeCalcService.formatOffset(500), 'CCTV가 1초 느림');
    });
  });
}
