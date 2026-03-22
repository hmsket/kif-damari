class TabEntity {
  final int? id;         // Primary Key (Auto Increment)
  final String title;    // タブ名
  final int tabOrder;    // 並び順

  TabEntity({
    this.id,
    required this.title,
    required this.tabOrder,
  });

  // DBのMapからインスタンスを生成 (JavaのResultSet変換相当)
  factory TabEntity.fromMap(Map<String, dynamic> map) {
    return TabEntity(
      id: map['id'] as int?,
      title: map['title'] as String,
      tabOrder: map['tab_order'] as int,
    );
  }

  // インスタンスからDB用のMapへ変換 (JavaのContentValues相当)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'tab_order': tabOrder,
    };
  }
}
