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

# Flutter を実績のあるバージョン 3.47.9 に固定する。
# 新しい Flutter stable は Gradle の最小要件を引き上げており
# (3.47.9 以降は Gradle 9.3.1 必須)、本リポジトリの Gradle 8.14 では
# APK ビルドが失敗するため。ワークフローで 3.47.9 が入っていればそれを
# そのまま使い、無い/違う場合はタグ 3.47.9 の SDK を clone して優先する。
FLUTTER_VERSION="3.47.9"

flutter_pinned_version() {
  "$1" --version 2>/dev/null | sed -n 's/^Flutter \([0-9][0-9.]*\).*/\1/p' | head -n 1
}

if [ "$(flutter_pinned_version flutter)" = "$FLUTTER_VERSION" ]; then
  echo "Using preinstalled Flutter $FLUTTER_VERSION."
elif [ -x "$HOME/flutter-sdk/bin/flutter" ] && \
     [ "$(flutter_pinned_version "$HOME/flutter-sdk/bin/flutter")" = "$FLUTTER_VERSION" ]; then
  echo "Using cached Flutter $FLUTTER_VERSION from \$HOME/flutter-sdk."
  export PATH="$HOME/flutter-sdk/bin:$PATH"
else
  echo "Setting up Flutter $FLUTTER_VERSION (pinned)..."
  rm -rf "$HOME/flutter-sdk"
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$HOME/flutter-sdk"
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
