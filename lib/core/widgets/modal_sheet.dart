import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 모달 바텀시트 공통 여백 (#44).
///
/// `showModalBottomSheet(useSafeArea: true)`는 상·좌·우만 처리하고
/// **하단 시스템 inset은 처리하지 않는다**. 키보드가 열린 경우도 있으므로
/// `viewInsets`(키보드)와 `viewPadding`(내비게이션 바·홈 인디케이터) 중
/// 큰 값을 사용한다.
double modalBottomInset(MediaQueryData media) =>
    math.max(media.viewInsets.bottom, media.viewPadding.bottom);

/// 바텀시트 본문 기본 패딩. 하단에 시스템 바 + [extra] 여백을 확보한다.
EdgeInsets modalSheetPadding(
  BuildContext context, {
  double top = 16,
  double horizontal = 16,
  double extra = 16,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    modalBottomInset(MediaQuery.of(context)) + extra,
  );
}
