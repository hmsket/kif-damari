# kif-damari — instructions for the OpenCode agent

Flutter kifu-playback app. Follow these rules for every task in this repo.

## Hard rules (do not break)

1. NEVER download, install, or set up the Flutter SDK or Dart SDK.
   Do not run `flutter`, `dart`, `fvm`, or any SDK download command
   (including `git clone` of the Flutter repo or `curl` of SDK archives).
   If `flutter` is not already on PATH, skip verification entirely —
   CI verifies every PR.
2. Verification is done by the Flutter CI workflow on the PR, not by you.
   Do NOT run `flutter analyze`, `flutter test`, or `flutter build`.
3. Finish by creating the branch and the pull request. Do not end with
   only a summary comment when code changes were requested.
4. Keep changes minimal and scoped to the request. Do not reformat
   untouched code, and do not change app behavior or appearance unless
   the request explicitly says so.
