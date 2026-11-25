/// 棋譜ファイルの保存方法（保存先の振り分け）を表すモード。
enum KifSaveMode {
  /// 既存のローカルファイル（取り込み済み棋譜など）へ上書き保存する
  overwriteLocal,

  /// 既存の content:// ファイル（Google Drive 等）へ上書き保存する
  overwriteRemote,

  /// アプリ内部フォルダ（Documents/Kifdamari）へ新規作成する
  newInternal,

  /// 設定されたデフォルト保存先（SAF ツリー）へ新規作成する
  newRemote,

  /// 送信待ち棋譜の退避ファイルを更新し、保存先への再送信を試みる
  pendingUpdate,
}

/// 1回の保存で書き込む場所を決めた結果。
class KifSavePlan {
  final KifSaveMode mode;

  /// 上書き対象 / 退避先のローカルファイルパス（該当しないモードでは null）
  final String? targetPath;

  /// デフォルト保存先の SAF ツリー URI（newRemote / pendingUpdate のみ）
  final String? treeUri;

  const KifSavePlan({
    required this.mode,
    this.targetPath,
    this.treeUri,
  });
}

/// 保存時の状態から、棋譜ファイルの保存先を決定する。
class KifSavePlanner {
  /// 保存先を決める。
  ///
  /// - [currentPath] : 現在の棋譜の kifPath（空なら新規作成棋譜）
  /// - [pendingTreeUri] : 送信待ち状態なら保存先ツリー URI
  /// - [defaultTreeUri] : 設定のデフォルト保存先ツリー URI（未設定は空文字）
  /// - [fileExists] : ローカルパスの存在確認（テストで差し替え可能）
  static Future<KifSavePlan> plan({
    required String currentPath,
    required String? pendingTreeUri,
    required String defaultTreeUri,
    required Future<bool> Function(String path) fileExists,
  }) async {
    if (pendingTreeUri != null && pendingTreeUri.isNotEmpty) {
      return KifSavePlan(
        mode: KifSaveMode.pendingUpdate,
        treeUri: pendingTreeUri,
        targetPath: currentPath.isEmpty ? null : currentPath,
      );
    }

    if (currentPath.isEmpty) {
      return _newPlan(defaultTreeUri);
    }

    if (currentPath.startsWith('content://')) {
      return KifSavePlan(mode: KifSaveMode.overwriteRemote, targetPath: currentPath);
    }

    if (currentPath.startsWith('file://')) {
      final localPath = Uri.parse(currentPath).toFilePath();
      if (await fileExists(localPath)) {
        return KifSavePlan(
          mode: KifSaveMode.overwriteLocal,
          targetPath: currentPath,
        );
      }
      return _newPlan(defaultTreeUri);
    }

    if (await fileExists(currentPath)) {
      return KifSavePlan(mode: KifSaveMode.overwriteLocal, targetPath: currentPath);
    }

    return _newPlan(defaultTreeUri);
  }

  static KifSavePlan _newPlan(String defaultTreeUri) {
    if (defaultTreeUri.isEmpty) {
      return const KifSavePlan(mode: KifSaveMode.newInternal);
    }
    return KifSavePlan(mode: KifSaveMode.newRemote, treeUri: defaultTreeUri);
  }
}
