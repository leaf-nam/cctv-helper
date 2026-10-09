import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/datetime_field.dart';
import '../providers/cases_provider.dart';

/// 사건 목록 화면 (`/`, #4).
/// 순서 변경(드래그)·등록일자 표시·지우기 버튼 제공. 로컬 저장됨.
class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _titleController.clear();
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('새 사건'),
          content: TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '사건 제목'),
            onSubmitted: (_) => Navigator.of(context).pop(_titleController.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_titleController.text),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
    if (title == null || title.trim().isEmpty) return;
    if (!mounted) return;
    await context.read<CasesProvider>().addCase(title);
  }

  Future<void> _confirmRemove(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('사건 삭제'),
          content: Text('‘$title’을(를) 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<CasesProvider>().removeCase(id);
  }

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CasesProvider>().cases;
    return Scaffold(
      appBar: AppBar(title: const Text('사건 목록')),
      body: cases.isEmpty
          ? const Center(child: Text('등록된 사건이 없습니다.'))
          : ReorderableListView.builder(
              // 하단 FAB와 마지막 행 삭제 버튼이 겹치지 않게 여백
              padding: const EdgeInsets.only(bottom: 96),
              buildDefaultDragHandles: false,
              itemCount: cases.length,
              onReorderItem: (oldIndex, newIndex) => context
                  .read<CasesProvider>()
                  .reorder(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final item = cases[index];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(item.title),
                  subtitle: Text('등록 ${formatDateTime(item.createdAt)}'),
                  onTap: () => context.go('/case/${item.id}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '삭제',
                        onPressed: () => _confirmRemove(item.id, item.title),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
