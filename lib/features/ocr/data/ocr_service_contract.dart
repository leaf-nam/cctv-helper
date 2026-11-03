/// OCR 서비스 계약 (#27). 테스트에서는 가짜 구현으로 대체한다.
abstract class OcrService {
  /// 이미지 파일에서 텍스트를 인식한다. 실패하면 null.
  Future<String?> recognizeText(String imagePath);
}
