# リモート開発セットアップ（Discord不要版 / GitHub完結ループ）

最終更新: 2026-11-05

## 全体の流れ
1. 修正したいことを GitHub Issue に書く（= 台帳 GitHub Projects の1行になる）
2. Issue に `/opencode 直してほしい内容` とコメントする（スマホのGitHubアプリでOK）
3. OpenCode（無料モデル `opencode/big-pickle`）が Actions の中で修正し、PR を作る
4. Flutter CI がその PR で解析・テスト・APK ビルドを行い、APK を Artifacts に置く
5. スマホで PR → Actions の Artifacts から APK をダウンロードしてインストール、実機確認
6. 問題なければ PR をマージ（Issue は自動で閉じる）。NG なら PR を閉じて Issue に理由を書く

家の PC と Muse は日常のループには入らない。

## あなた側の初期設定（1回だけ）

### 1. GitHub Projects（台帳）を作る
これは GitHub の画面でしか作れない（自動化ツール側に作成手段がない）:
1. GitHub の自分のプロフィール → Projects → New project → Table を選ぶ
2. フィールドを用意する:
   - Status（Single select）: 未対応 / 実行中 / 要確認 / 完了
   - Priority（Single select）: 高 / 中 / 低
3. ビューは Table と Board（Statusでグループ化）の2つ
4. 以後、修正 Issue を作ったらこの Project に追加する
   （Project 側の Auto-add ワークフローで、このリポジトリの Issue を自動追加にすると楽）

### 2. 署名用キーストアを作って Secrets に登録する
これをやらないと、CI 製 APK は毎回違う署名になり、上書きインストールできない。
逆に一度設定すれば、以後は常に同じ署名で更新インストールできる。

家の PC（JDK の入っている環境）で:
```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- パスワードとエイリアス名（upload と入力）を決める。この3点は忘れないこと。
- `upload-keystore.jks` 自体は絶対にリポジトリへコミットしない（このリポジトリは公開）。
  家の PC の安全な場所に保管するのが正本。

GitHub の Settings → Secrets and variables → Actions に以下4つを登録する:
- `KEYSTORE_BASE64`: upload-keystore.jks を Base64 化した文字列
  - Mac/Linux: `base64 -i upload-keystore.jks` の出力
  - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))` の出力
- `KEY_ALIAS`: upload
- `KEY_PASSWORD`: キーのパスワード
- `STORE_PASSWORD`: キーストアのパスワード

ついでに家の PC でも release ビルドする時は、同じ内容の `android/key.properties` を
ローカルにだけ置く（.gitignore 済みなのでコミットされない）と同じ署名に揃えられる:
```
storePassword=<STORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=upload
storeFile=upload-keystore.jks
```
この場合 upload-keystore.jks は android/app/ フォルダに置く。

### 3. 最初の1回だけの注意
- 署名が今まで（家の debug キー）と変わるため、最初の CI 製 APK のインストール時に
  「署名が違う」と言われたら、一度アンインストールしてから入れる必要がある。
  アプリ内データ（端末内DB）は消えるので、必要なら先にエクスポートしておく。
- 以後は同じキーストア署名なので、上書き更新できる（データも保持される）。

## 安全メモ
- このリポジトリは公開。Secrets の中身は公開されないが、コードや Issue は誰でも見える。
  APIキー・キーストア・棋譜の権利物データなどを Issue やコードに貼らないこと。
- 無料モデルは期間限定で、混雑時に失敗することがある。失敗したら時間を置いて
  `/opencode` コメントをもう一度送ればよい。有料モデルへの自動フォールバックは
  設定していない（opencode.json で無料モデルに固定済み）。
- OpenCode ワークフローを起動できるのは所有者 (hmsket) のコメントだけに制限済み
  （公開リポジトリで第三者にエージェントを動かされないため）。

## ファイル構成（このPRで追加・変更したもの）
- `.github/workflows/opencode.yml` — /opencode コメントで OpenCode を起動
- `.github/workflows/flutter-ci.yml` — 解析・テスト・APK ビルド + Artifacts アップロード
- `opencode.json` — モデルを無料の big-pickle に固定（小さい内部タスク用モデルも同じ）
- `android/app/build.gradle.kts` — key.properties がある場合だけ release 署名を使うよう変更
- `.gitignore` — key.properties / *.jks / *.keystore をコミット対象外に追加
