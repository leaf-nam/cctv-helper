import 'package:cctv_helper/app.dart';
import 'package:cctv_helper/core/constants/store_keys.dart';
import 'package:cctv_helper/core/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('첫 실행이면 튜토리얼을 보여주고 건너뛰기로 저장', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();

    await tester.pumpWidget(AppShell(store: store));
    await tester.pumpAndSettle();

    expect(find.text('사용 방법'), findsOneWidget);
    expect(find.text('1. 사건을 만드세요'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-image-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tutorial-next')));
    await tester.pumpAndSettle();

    expect(find.text('2. 두 시각을 입력하세요'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-image-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tutorial-skip')));
    await tester.pumpAndSettle();

    expect(find.text('사건 목록'), findsOneWidget);
    expect(store.getBool(StoreKeys.tutorialSeen), isTrue);
  });

  testWidgets('이미 본 경우 튜토리얼을 건너뛴다', (tester) async {
    SharedPreferences.setMockInitialValues({StoreKeys.tutorialSeen: true});
    final store = await LocalStore.create();

    await tester.pumpWidget(AppShell(store: store));
    await tester.pumpAndSettle();

    expect(find.text('사건 목록'), findsOneWidget);
    expect(find.text('사용 방법'), findsNothing);
  });

  testWidgets('도움말 버튼으로 튜토리얼 다시 보기', (tester) async {
    SharedPreferences.setMockInitialValues({StoreKeys.tutorialSeen: true});
    final store = await LocalStore.create();

    await tester.pumpWidget(AppShell(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('튜토리얼 다시 보기'));
    await tester.pumpAndSettle();

    expect(find.text('튜토리얼 다시 보기'), findsOneWidget);
    expect(find.text('1. 사건을 만드세요'), findsOneWidget);
  });
}
