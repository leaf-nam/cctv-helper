import 'ocr_service_contract.dart';
import 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_mlkit.dart'
    as impl;

export 'ocr_service_contract.dart';

/// 플랫폼에 맞는 OCR 서비스를 생성한다.
///
/// - 모바일/데스크톱(dart:io): ML Kit 기반 구현
/// - 웹: 항상 null을 돌려주는 스텁 (수동 입력 fallback)
OcrService createOcrService() => impl.createOcrService();
