import 'package:cctv_helper/core/widgets/modal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('modalBottomInset', () {
    test('시스템 하단 inset만 있으면 그 값을 쓴다', () {
      final media = MediaQueryData(
        viewPadding: const EdgeInsets.only(bottom: 34),
      );
      expect(modalBottomInset(media), 34);
    });

    test('키보드 inset이 더 크면 키보드 값을 쓴다', () {
      final media = MediaQueryData(
        viewInsets: const EdgeInsets.only(bottom: 300),
        viewPadding: const EdgeInsets.only(bottom: 34),
      );
      expect(modalBottomInset(media), 300);
    });

    test('시스템 하단 inset이 더 크면 그 값을 유지한다', () {
      final media = MediaQueryData(
        viewInsets: const EdgeInsets.only(bottom: 10),
        viewPadding: const EdgeInsets.only(bottom: 34),
      );
      expect(modalBottomInset(media), 34);
    });
  });

  testWidgets('시트 패딩은 하단 시스템 inset + 기본 여백을 확보한다', (tester) async {
    late EdgeInsets padding;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(viewPadding: const EdgeInsets.only(bottom: 34)),
        child: Builder(
          builder: (context) {
            padding = modalSheetPadding(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(padding.left, 16);
    expect(padding.top, 16);
    expect(padding.right, 16);
    expect(padding.bottom, 34 + 16);
  });

  testWidgets('하단 inset이 있어도 시트 버튼을 탭할 수 있다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (sheetContext) => SingleChildScrollView(
                    child: Padding(
                      padding: modalSheetPadding(sheetContext),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('시트'),
                          FilledButton(
                            key: const ValueKey('sheet-apply'),
                            onPressed: () {
                              tapped = true;
                              Navigator.of(sheetContext).pop();
                            },
                            child: const Text('적용'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('sheet-apply')));
    await tester.tap(find.byKey(const ValueKey('sheet-apply')));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.text('적용'), findsNothing);
  });
}
