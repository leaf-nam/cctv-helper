# ML Kit 텍스트 인식 플러그인은 선택 스크립트(중국어·데바나가리·일본어)를
# compileOnly로 참조한다. 한국어는 앱에서 모델을 직접 번들하므로 제외하고,
# 번들하지 않은 나머지 스크립트의 누락 클래스 경고만 억제한다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
