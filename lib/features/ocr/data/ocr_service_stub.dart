import 'ocr_service_contract.dart';

/// 웹 등 ML Kit을 지원하지 않는 플랫폼용 스텁.
///
/// OCR은 온디바이스 모바일 기능이므로 웹에서는 수동 입력으로 대체한다.
class UnsupportedOcrService implements OcrService {
  const UnsupportedOcrService();

  @override
  Future<String?> recognizeText(String imagePath) async => null;
}

OcrService createOcrService() => const UnsupportedOcrService();
