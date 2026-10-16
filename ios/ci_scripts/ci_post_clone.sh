#!/bin/sh
# Xcode Cloud: Flutter SDK 준비 + 의존성 설치.
# 워크플로우(빌드·테스트·아카이브·TestFlight 배포)는 App Store Connect에 저장되고,
# 이 스크립트만 저장소에서 관리된다.
set -eux

FLUTTER_SDK="$HOME/flutter-sdk"
if [ ! -x "$FLUTTER_SDK/bin/flutter" ]; then
  rm -rf "$FLUTTER_SDK"
  git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git "$FLUTTER_SDK"
fi
export PATH="$FLUTTER_SDK/bin:$PATH"

flutter --version
flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

cd ios
pod install
