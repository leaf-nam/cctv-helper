import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/photo_storage_service.dart';
import '../../../core/widgets/datetime_field.dart';
import '../domain/case_photo.dart';

/// 사진을 전체화면으로 보여 준다 (#46).
///
/// 사진 타일을 누르면 바로 열리고, 핀치 줌·팬으로 확대할 수 있다.
/// 메타데이터·메모 수정은 [onShowDetail] 콜백으로 기존 상세 시트에 위임한다.
Future<void> showPhotoViewer(
  BuildContext context, {
  required CasePhoto photo,
  required String sourceName,
  required VoidCallback onShowDetail,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewer(
        photo: photo,
        sourceName: sourceName,
        onShowDetail: onShowDetail,
      ),
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  final CasePhoto photo;
  final String sourceName;
  final VoidCallback onShowDetail;

  const _PhotoViewer({
    required this.photo,
    required this.sourceName,
    required this.onShowDetail,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).pop();
    // 전체화면 라우트가 닫힌 뒤 상세 시트를 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) => onShowDetail());
  }

  @override
  Widget build(BuildContext context) {
    final time = photo.correctedAt ?? photo.capturedAt;
    return Scaffold(
      key: const ValueKey('photo-viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '$sourceName · ${photo.kind.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const ValueKey('photo-viewer-info'),
            tooltip: '상세 정보',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _openDetail(context),
          ),
          IconButton(
            key: const ValueKey('photo-viewer-close'),
            tooltip: '닫기',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: photo.filePath.isEmpty
            ? const _ViewerPlaceholder()
            : InteractiveViewer(
                key: const ValueKey('photo-viewer-zoom'),
                minScale: 0.8,
                maxScale: 5,
                child: Image.file(
                  File(PhotoStorageService.resolve(photo.filePath)),
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, __) => const _ViewerPlaceholder(),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateTime(time),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (photo.memo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    photo.memo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerPlaceholder extends StatelessWidget {
  const _ViewerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, color: Colors.white54, size: 48),
          SizedBox(height: 8),
          Text('사진을 불러올 수 없습니다.', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
