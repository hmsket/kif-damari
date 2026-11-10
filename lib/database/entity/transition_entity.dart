class TransitionEntity {
  final int? id;
  final int fromPositionId;
  final int toPositionId;
  final String moveLabel;

  TransitionEntity({
    this.id,
    required this.fromPositionId,
    required this.toPositionId,
    required this.moveLabel,
  });

  factory TransitionEntity.fromMap(Map<String, dynamic> map) {
    return TransitionEntity(
      id: map['id'] as int?,
      fromPositionId: map['from_position_id'] as int,
      toPositionId: map['to_position_id'] as int,
      moveLabel: map['move_label'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'from_position_id': fromPositionId,
      'to_position_id': toPositionId,
      'move_label': moveLabel,
    };
  }
}
