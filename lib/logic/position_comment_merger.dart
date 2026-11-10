class PositionCommentMerger {
  static String merge(String existing, String incoming) {
    if (incoming.trim().isEmpty) return existing;
    if (existing.trim().isEmpty) return incoming;

    final lines = existing.split('\n');
    for (final line in incoming.split('\n')) {
      if (!lines.contains(line)) {
        lines.add(line);
      }
    }
    return lines.join('\n');
  }
}
