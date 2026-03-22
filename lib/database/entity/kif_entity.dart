class KifEntity {
  final int tabId;       // 複合キー1 / Foreign Key
  final int kifId;       // 複合キー2
  final String title;    // 棋譜タイトル
  final String? detail;  // 詳細メモ
  final int kifOrder;    // タブ内での並び順
  final String? kifPath; // KIFファイルパス
  final String? imgPath; // 画像パス
  final int? color;      // 表示色 (0xFF... のint値)

  KifEntity({
    required this.tabId,
    required this.kifId,
    required this.title,
    this.detail,
    required this.kifOrder,
    this.kifPath,
    this.imgPath,
    this.color,
  });

  factory KifEntity.fromMap(Map<String, dynamic> map) {
    return KifEntity(
      tabId: map['tab_id'] as int,
      kifId: map['kif_id'] as int,
      title: map['title'] as String,
      detail: map['detail'] as String?,
      kifOrder: map['kif_order'] as int,
      kifPath: map['kif_path'] as String?,
      imgPath: map['img_path'] as String?,
      color: map['color'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tab_id': tabId,
      'kif_id': kifId,
      'title': title,
      'detail': detail,
      'kif_order': kifOrder,
      'kif_path': kifPath,
      'img_path': imgPath,
      'color': color,
    };
  }
}
