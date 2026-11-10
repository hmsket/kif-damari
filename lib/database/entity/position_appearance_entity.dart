class PositionAppearanceEntity {
  final int? id;
  final int positionId;
  final int kifId;
  final int moveNumber;

  PositionAppearanceEntity({
    this.id,
    required this.positionId,
    required this.kifId,
    required this.moveNumber,
  });

  factory PositionAppearanceEntity.fromMap(Map<String, dynamic> map) {
    return PositionAppearanceEntity(
      id: map['id'] as int?,
      positionId: map['position_id'] as int,
      kifId: map['kif_id'] as int,
      moveNumber: map['move_number'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'position_id': positionId,
      'kif_id': kifId,
      'move_number': moveNumber,
    };
  }
}
