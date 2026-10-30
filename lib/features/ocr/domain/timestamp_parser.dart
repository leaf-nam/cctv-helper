/// CCTV 화면에서 인식한 텍스트에서 날짜·시각을 추출하는 파서 (#27).
///
/// 온디바이스 OCR 결과는 줄바꿈·전각 문자·한글 단위가 섞여 들어오므로
/// 정규화 후 여러 형식을 순서대로 시도한다. 범위를 벗어난 값(25시, 60분,
/// 2월 30일 등)은 후보에서 제외한다.
class TimestampParser {
  static final RegExp _dateYmd = RegExp(
    r'(?<!\d)((?:19|20)\d{2})\s*[-./]\s*(\d{1,2})\s*[-./]\s*(\d{1,2})(?!\d)',
  );
  static final RegExp _dateMdy = RegExp(
    r'(?<!\d)(\d{1,2})\s*[-./]\s*(\d{1,2})\s*[-./]\s*((?:19|20)\d{2})(?!\d)',
  );
  static final RegExp _dateCompact = RegExp(
    r'(?<!\d)((?:19|20)\d{2})(\d{2})(\d{2})(?!\d)',
  );
  static final RegExp _time = RegExp(
    r'(?<!\d)(\d{1,2})\s*:\s*(\d{1,2})(?:\s*:\s*(\d{1,2}))?(?!\d)',
  );
  static final RegExp _timeCompact = RegExp(
    r'(?<!\d)(\d{2})(\d{2})(\d{2})(?!\d)',
  );
  static final RegExp _ampm = RegExp(r'([AaPp][Mm])');

  /// 텍스트에서 시각 후보를 신뢰도 내림차순으로 반환한다.
  ///
  /// [fallbackDate]는 날짜 없이 시각만 인식됐을 때 사용할 날짜다.
  static List<TimestampCandidate> candidates(
    String text, {
    DateTime? fallbackDate,
  }) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return const [];

    // yyyyMMddHHmmss (14자리) 압축 표기.
    final compact = RegExp(r'(?<!\d)(\d{14})(?!\d)').firstMatch(normalized);
    if (compact != null) {
      final raw = compact.group(1)!;
      final date = _makeDate(
        raw.substring(0, 4),
        raw.substring(4, 6),
        raw.substring(6, 8),
      );
      final hour = int.parse(raw.substring(8, 10));
      final minute = int.parse(raw.substring(10, 12));
      final second = int.parse(raw.substring(12, 14));
      if (date != null && _validTime(hour, minute, second)) {
        return [
          TimestampCandidate(
            value: DateTime(
              date.year,
              date.month,
              date.day,
              hour,
              minute,
              second,
            ),
            raw: text.trim(),
            confidence: 0.9,
            pattern: 'date+time',
          ),
        ];
      }
    }

    final rawDateFound =
        _dateYmd.hasMatch(normalized) ||
        _dateMdy.hasMatch(normalized) ||
        _dateCompact.hasMatch(normalized);
    final rawTimeFound =
        _time.hasMatch(normalized) || _timeCompact.hasMatch(normalized);
    final date = _findDate(normalized);
    final time = _findTime(normalized);

    // 날짜/시각 형태가 보이는데 범위를 벗어난 값이면 후보를 만들지 않는다.
    // (예: 2월 30일, 25시) 잘못된 값을 조용히 보정하지 않기 위함.
    if (rawDateFound && date == null) return const [];
    if (rawTimeFound && time == null) return const [];

    final results = <TimestampCandidate>[];

    if (date != null && time != null) {
      final combined = _combine(date.value, time.value);
      if (combined != null) {
        results.add(
          TimestampCandidate(
            value: combined,
            raw: text.trim(),
            confidence: (0.9 * date.confidence * time.confidence).clamp(
              0.0,
              1.0,
            ),
            pattern: 'date+time',
          ),
        );
      }
    }
    if (date != null) {
      results.add(
        TimestampCandidate(
          value: date.value,
          raw: text.trim(),
          confidence: date.confidence * 0.6,
          pattern: 'date',
        ),
      );
    }
    if (time != null) {
      final base = fallbackDate ?? DateTime.now();
      final value = DateTime(
        base.year,
        base.month,
        base.day,
        time.value.hour,
        time.value.minute,
        time.value.second,
      );
      results.add(
        TimestampCandidate(
          value: value,
          raw: text.trim(),
          confidence: time.confidence * 0.65,
          pattern: 'time',
        ),
      );
    }
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  /// 가장 신뢰도 높은 후보 1개. 없으면 null.
  static TimestampCandidate? parse(String text, {DateTime? fallbackDate}) {
    final list = candidates(text, fallbackDate: fallbackDate);
    return list.isEmpty ? null : list.first;
  }

  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      // 전각 숫자/콜론 → ASCII
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buffer.writeCharCode(rune - 0xFF10 + 0x30);
        continue;
      }
      if (rune == 0xFF1A) {
        buffer.write(':');
      } else if (rune == 0xFF0E) {
        buffer.write('.');
      } else if (rune == 0xFF0D || rune == 0x2013 || rune == 0x2014) {
        // 전각 하이픈/대시
        buffer.write('-');
      } else if (rune == 0xFF0F) {
        buffer.write('/');
      } else if (rune == 0x3000) {
        buffer.write(' ');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer
        .toString()
        .replaceAll('년', '-')
        .replaceAll('월', '-')
        .replaceAll('일', ' ')
        .replaceAll('시', ':')
        .replaceAll('분', ':')
        .replaceAll('초', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  static _FoundDate? _findDate(String text) {
    // yyyy-MM-dd
    final ymd = _dateYmd.firstMatch(text);
    if (ymd != null) {
      final date = _makeDate(ymd.group(1)!, ymd.group(2)!, ymd.group(3)!);
      if (date != null) return _FoundDate(date, 0.95);
    }
    // MM/dd/yyyy (미국식 CCTV)
    final mdy = _dateMdy.firstMatch(text);
    if (mdy != null) {
      final date = _makeDate(mdy.group(3)!, mdy.group(1)!, mdy.group(2)!);
      if (date != null) return _FoundDate(date, 0.85);
    }
    // yyyyMMdd
    final compact = _dateCompact.firstMatch(text);
    if (compact != null) {
      final date = _makeDate(
        compact.group(1)!,
        compact.group(2)!,
        compact.group(3)!,
      );
      if (date != null) return _FoundDate(date, 0.8);
    }
    return null;
  }

  static _FoundTime? _findTime(String text) {
    final match = _time.firstMatch(text);
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final second = int.tryParse(match.group(3) ?? '') ?? 0;
      var confidence = match.group(3) == null ? 0.8 : 0.95;

      // AM/PM 표기 보정
      final suffix = text.substring(match.end).trimLeft();
      final prefix = text.substring(0, match.start).trimRight();
      RegExpMatch? ampm = _ampm.firstMatch(suffix);
      if (ampm == null && prefix.isNotEmpty) {
        final matches = _ampm.allMatches(prefix);
        if (matches.isNotEmpty) ampm = matches.last;
      }
      if (ampm != null && hour <= 12) {
        final isPm = ampm.group(1)!.toUpperCase() == 'PM';
        hour = hour % 12 + (isPm ? 12 : 0);
        confidence = (confidence + 0.02).clamp(0.0, 1.0);
      }
      if (!_validTime(hour, minute, second)) return null;
      return _FoundTime(DateTime(2000, 1, 1, hour, minute, second), confidence);
    }
    // HHmmss
    final compact = _timeCompact.firstMatch(text);
    if (compact != null) {
      final hour = int.parse(compact.group(1)!);
      final minute = int.parse(compact.group(2)!);
      final second = int.parse(compact.group(3)!);
      if (!_validTime(hour, minute, second)) return null;
      return _FoundTime(DateTime(2000, 1, 1, hour, minute, second), 0.7);
    }
    return null;
  }

  static bool _validTime(int hour, int minute, int second) {
    return hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59 &&
        second >= 0 &&
        second <= 59;
  }

  static DateTime? _makeDate(String year, String month, String day) {
    final y = int.tryParse(year);
    final m = int.tryParse(month);
    final d = int.tryParse(day);
    if (y == null || m == null || d == null) return null;
    if (y < 1900 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    final value = DateTime(y, m, d);
    if (value.year != y || value.month != m || value.day != d) return null;
    return value;
  }

  static DateTime? _combine(DateTime date, DateTime time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
  }
}

/// OCR 텍스트에서 추출한 시각 후보.
class TimestampCandidate {
  const TimestampCandidate({
    required this.value,
    required this.raw,
    required this.confidence,
    required this.pattern,
  });

  final DateTime value;
  final String raw;

  /// 0.0~1.0. 사용자 확인 UI에서 참고용으로 표시한다.
  final double confidence;
  final String pattern;

  /// 신뢰도 백분율 표시.
  String get confidenceLabel => '${(confidence * 100).round()}%';
}

class _FoundDate {
  const _FoundDate(this.value, this.confidence);
  final DateTime value;
  final double confidence;
}

class _FoundTime {
  const _FoundTime(this.value, this.confidence);
  final DateTime value;
  final double confidence;
}
