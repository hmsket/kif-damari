class KifEntity {
  final int? id;
  final int tabId;
  final int kifId;
  final String title;
  final String? detail;
  final int kifOrder;
  final String? kifPath;
  final String? imgPath;
  final int? color;

  KifEntity({
    this.id,
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
      id: map['id'] as int?,
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
      if (id != null) 'id': id,
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
