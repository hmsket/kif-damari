#!/usr/bin/env bash
# kif-damari の CI ビルド本体 (解析・テスト・署名・APK ビルド・dev リリース公開)。
# flutter-ci.yml と、opencode.yml の ci-build ジョブの両方から呼ばれる共有スクリプト。
# 内容は flutter-ci.yml の従来ステップと同一。片方を変えたら両方の呼び出し側と
# このファイルの整合を確認すること。
#
# 必要な環境変数:
#   KEYSTORE_BASE64 / KEY_ALIAS / KEY_PASSWORD / STORE_PASSWORD (任意・署名用)
#   GH_TOKEN (dev リリース公開用)
# 前提: リポジトリをチェックアウト済みで、このスクリプトはリポジトリ直下で実行する。
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.21-9/x64}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found; setting up Flutter (stable)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter-sdk"
  export PATH="$HOME/flutter-sdk/bin:$PATH"
fi
flutter --version

flutter pub get

flutter analyze --no-fatal-infos --no-fatal-warnings

if [ -d test ]; then
  flutter test
else
  echo "test/ directory not found - skipping tests."
fi

if [ -n "${KEYSTORE_BASE64:-}" ]; then
  echo "$KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks
  cat > android/key.properties <<EOF
storePassword=${STORE_PASSWORD:-}
keyPassword=${KEY_PASSWORD:-}
keyAlias=${KEY_ALIAS:-}
storeFile=upload-keystore.jks
EOF
  echo "Release signing configured from secrets."
else
  echo "::warning::KEYSTORE_BASE64 is not set. The APK will be signed with an ephemeral debug key and cannot update previous installs."
fi

flutter build apk --release --split-per-abi

mkdir -p build/ci-artifact
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/ci-artifact/kifdamari-apk-arm64.apk

cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk kifdamari.apk
if ! gh release view dev > /dev/null 2>&1; then
  gh release create dev --prerelease --title "dev (検証用・最新ビルド)" --notes "CI が自動で更新する検証用リリースです。" || true
fi
gh release upload dev kifdamari.apk --clobber
gh release edit dev --notes "最新の成功ビルド: ${GITHUB_EVENT_NAME:-manual} / ${GITHUB_SHA:-unknown} / run ${GITHUB_RUN_NUMBER:-0}"
echo "Published: https://github.com/hmsket/kif-damari/releases/download/dev/kifdamari.apk"
