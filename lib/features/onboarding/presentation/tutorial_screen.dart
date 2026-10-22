import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/tutorial_provider.dart';

/// 첫 실행/다시 보기 튜토리얼.
///
/// 4단계로 사건 등록 → 기준 시각 입력 → 오차 확인 → 기록·타임라인 흐름을
/// 짧게 안내한다. 마지막 페이지 또는 건너뛰기에서 `seen`을 저장한다.
class TutorialScreen extends StatefulWidget {
  final bool replay;

  const TutorialScreen({super.key, this.replay = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  static const _pages =
      <({IconData icon, String title, String body, String image})>[
        (
          icon: Icons.folder_open,
          title: '1. 사건을 만드세요',
          body: '수사 사건을 먼저 만들고, 그 안에 확인할 CCTV를 추가합니다.',
          image: 'assets/tutorial/01-cases.png',
        ),
        (
          icon: Icons.videocam,
          title: '2. 두 시각을 입력하세요',
          body:
              'CCTV 화면에 표시된 시각과 같은 순간의 실제시간을 입력하면 '
              '오차를 자동으로 계산합니다.',
          image: 'assets/tutorial/02-time-sheet.png',
        ),
        (
          icon: Icons.compare_arrows,
          title: '3. 시간을 확인하세요',
          body:
              '녹화장면의 CCTV 시각을 입력하면 보정된 실제시간을 바로 '
              '확인할 수 있습니다.',
          image: 'assets/tutorial/03-time-result.png',
        ),
        (
          icon: Icons.timeline,
          title: '4. 기록으로 남기세요',
          body:
              '사진과 메모를 남기면 보정된 실제시간 순서로 정리됩니다. '
              '사건별로 다시 확인할 수 있습니다.',
          image: 'assets/tutorial/04-records.png',
        ),
      ];

  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<TutorialProvider>().markSeen();
    if (!mounted) return;
    context.go('/');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.replay ? '튜토리얼 다시 보기' : '사용 방법'),
        actions: [
          TextButton(
            key: const ValueKey('tutorial-skip'),
            onPressed: _finish,
            child: const Text('건너뛰기'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 32,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: Image.asset(
                                page.image,
                                key: ValueKey('tutorial-image-$index'),
                                width: double.infinity,
                                fit: BoxFit.fitWidth,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, _, __) => Container(
                                  height: 160,
                                  alignment: Alignment.center,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image_not_supported),
                                      SizedBox(height: 8),
                                      Text('화면 예시를 불러오지 못했습니다.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previous,
                        child: const Text('이전'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: _index > 0 ? 2 : 1,
                    child: FilledButton(
                      key: const ValueKey('tutorial-next'),
                      onPressed: _next,
                      child: Text(_isLast ? '시작하기' : '다음'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
