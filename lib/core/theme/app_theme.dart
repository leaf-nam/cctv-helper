import 'package:flutter/material.dart';

/// 로고(`assets/images/logo.png`) 기반 앱 테마.
///
/// 시그니처 컬러: 딥네이비 배경(`#02234C`) + 애저 블루(`#015E97`) +
/// 시안 글로우(`#62AFDD`).
class AppTheme {
  /// 로고 상단 애저 블루. 라이트·다크 스킴의 seed로 사용한다.
  static const Color seedBlue = Color(0xFF015E97);

  /// 로고 배경 딥네이비 (스플래시·강조 배경용 예약).
  static const Color deepNavy = Color(0xFF02234C);

  /// 로고 시계 링의 시안 글로우 (강조 포인트용 예약).
  static const Color glowCyan = Color(0xFF62AFDD);

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedBlue),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
