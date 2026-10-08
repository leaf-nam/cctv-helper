import 'package:cctv_helper/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('사건 목록 화면 표시', (tester) async {
    await tester.pumpWidget(const AppShell());
    await tester.pumpAndSettle();
    expect(find.text('사건 목록'), findsOneWidget);
    expect(find.text('등록된 사건이 없습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
