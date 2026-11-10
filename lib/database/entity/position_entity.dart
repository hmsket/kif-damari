class PositionEntity {
  final int? id;
  final String positionKey;
  final bool isRoot;
  final String comment;

  PositionEntity({
    this.id,
    required this.positionKey,
    this.isRoot = false,
    this.comment = '',
  });

  factory PositionEntity.fromMap(Map<String, dynamic> map) {
    return PositionEntity(
      id: map['id'] as int?,
      positionKey: map['position_key'] as String,
      isRoot: (map['is_root'] as int? ?? 0) == 1,
      comment: (map['comment'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'position_key': positionKey,
      'is_root': isRoot ? 1 : 0,
      'comment': comment,
    };
  }
}
