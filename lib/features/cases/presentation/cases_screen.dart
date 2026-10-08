import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/cases_provider.dart';

/// 사건 목록 화면 (`/`, #4).
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

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CasesProvider>().cases;
    return Scaffold(
      appBar: AppBar(title: const Text('사건 목록')),
      body: cases.isEmpty
          ? const Center(child: Text('등록된 사건이 없습니다.'))
          : ListView.builder(
              itemCount: cases.length,
              itemBuilder: (context, index) {
                final item = cases[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      context.read<CasesProvider>().removeCase(item.id),
                  child: ListTile(
                    title: Text(item.title),
                    onTap: () => context.go('/case/${item.id}'),
                    trailing: const Icon(Icons.chevron_right),
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
