import 'package:cctv_helper/app.dart';
import 'package:cctv_helper/core/constants/store_keys.dart';
import 'package:cctv_helper/core/services/local_store.dart';
import 'package:cctv_helper/features/onboarding/presentation/tutorial_screen.dart';
import 'package:cctv_helper/features/onboarding/providers/tutorial_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

  testWidgets('좁은 화면·큰 글꼴에서 도움말이 단어 단위로 줄바꿈된다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TutorialProvider(null),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const TutorialScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final body = find.byKey(const ValueKey('tutorial-body-0'));
    expect(body, findsOneWidget);
    final bodyWidth = tester.getSize(body).width;
    const words = [
      '수사',
      '사건을',
      '먼저',
      '만들고,',
      '그',
      '안에',
      '확인할',
      'CCTV를',
      '추가합니다.',
    ];
    for (final word in words) {
      final wordFinder = find.descendant(of: body, matching: find.text(word));
      expect(wordFinder, findsOneWidget, reason: word);
      expect(
        tester.getSize(wordFinder).width,
        lessThanOrEqualTo(bodyWidth),
        reason: '$word 단어가 가용 폭을 넘음',
      );
    }
  });
}
