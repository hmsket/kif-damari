class TabEntity {
  final int? id;
  final String title;
  final int tabOrder;

  TabEntity({
    this.id,
    required this.title,
    required this.tabOrder,
  });

  factory TabEntity.fromMap(Map<String, dynamic> map) {
    return TabEntity(
      id: map['id'] as int?,
      title: map['title'] as String,
      tabOrder: map['tab_order'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'tab_order': tabOrder,
    };
  }
}
