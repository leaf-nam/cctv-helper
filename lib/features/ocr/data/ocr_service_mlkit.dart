import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_service_contract.dart';

/// 온디바이스 ML Kit 텍스트 인식 구현 (#27).
///
/// 사진은 서버로 전송하지 않는다. 인식 실패·플러그인 미지원 시 null을
/// 돌려주고 UI는 수동 입력 fallback을 제공한다.
class MlkitOcrService implements OcrService {
  const MlkitOcrService();

  @override
  Future<String?> recognizeText(String imagePath) async {
    TextRecognizer? recognizer;
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.korean);
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      if (result.text.trim().isNotEmpty) return result.text;

      // 한글 모델이 숫자만 있는 타임스탬프를 놓치는 경우 라틴 모델로 재시도.
      await recognizer.close();
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final fallback = await recognizer.processImage(input);
      return fallback.text.trim().isEmpty ? null : fallback.text;
    } catch (_) {
      return null;
    } finally {
      await recognizer?.close();
    }
  }
}

OcrService createOcrService() => const MlkitOcrService();
