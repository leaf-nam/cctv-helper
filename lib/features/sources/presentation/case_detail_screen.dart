import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../cases/providers/cases_provider.dart';
import '../providers/sources_provider.dart';
import 'cctv_card.dart';

/// 사건 상세 화면 (`/case/:id`, #4).
/// CCTV 추가·이름 변경·순서 변경 + 시간 입력 진입점을 제공한다.
class CaseDetailScreen extends StatefulWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showAddSource() async {
    _nameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CCTV 추가'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'CCTV 이름'),
            onSubmitted: (_) =>
                Navigator.of(context).pop(_nameController.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_nameController.text),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;
    if (!mounted) return;
    await context.read<SourcesProvider>().addSource(widget.caseId, name);
  }

  @override
  Widget build(BuildContext context) {
    final caseFile = context.watch<CasesProvider>().getById(widget.caseId);
    if (caseFile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('사건을 찾을 수 없습니다.')),
      );
    }
    final sources = context.watch<SourcesProvider>().byCase(widget.caseId);
    return Scaffold(
      appBar: AppBar(
        title: Text(caseFile.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: sources.isEmpty
          ? const Center(child: Text('CCTV를 추가하세요.'))
          : ReorderableListView.builder(
              // 하단 FAB(+버튼)와 마지막 카드 삭제 버튼이 겹치지 않게 여백
              padding: const EdgeInsets.only(bottom: 96),
              // 기본 우측 핸들 대신 카드 맨 위 핸들 사용
              buildDefaultDragHandles: false,
              itemCount: sources.length,
              onReorderItem: (oldIndex, newIndex) => context
                  .read<SourcesProvider>()
                  .reorder(widget.caseId, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final source = sources[index];
                return CctvCard(
                  key: ValueKey(source.id),
                  caseId: widget.caseId,
                  source: source,
                  index: index,
                  onRename: (id, name) => context
                      .read<SourcesProvider>()
                      .renameSource(id, name),
                  onRemove: (id) => context
                      .read<SourcesProvider>()
                      .removeSource(id),
                  onUpdateTimes: (
                    id, {
                    DateTime? Function()? displayedAt,
                    DateTime? Function()? actualAt,
                  }) =>
                      context.read<SourcesProvider>().updateTimes(
                        id,
                        displayedAt: displayedAt,
                        actualAt: actualAt,
                      ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSource,
        child: const Icon(Icons.add),
      ),
    );
  }
}
