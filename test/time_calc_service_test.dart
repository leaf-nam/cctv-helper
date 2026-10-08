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

    test('formatOffset 부호·단위 표시', () {
      expect(TimeCalcService.formatOffset(120000), contains('+'));
      expect(TimeCalcService.formatOffset(120000), contains('120000ms'));
      expect(TimeCalcService.formatOffset(-90000), contains('-'));
      expect(TimeCalcService.formatOffset(0), contains('+0ms'));
    });
  });
}
