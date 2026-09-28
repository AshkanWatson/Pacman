/// The four cardinal movement directions plus [none].
///
/// The declaration order of the moving directions (up, left, down, right) is
/// significant: it is the arcade tie-break order used by ghosts when two
/// candidate tiles are equally close to their target.
enum Direction {
  up(0, -1),
  left(-1, 0),
  down(0, 1),
  right(1, 0),
  none(0, 0);

  const Direction(this.dx, this.dy);

  final int dx;
  final int dy;

  /// Moving directions in arcade tie-break priority order.
  static const List<Direction> moving = [up, left, down, right];

  Direction get opposite => switch (this) {
    up => down,
    down => up,
    left => right,
    right => left,
    none => none,
  };

  bool get isHorizontal => this == left || this == right;
  bool get isVertical => this == up || this == down;

  /// Whether [other] lies on the same axis as this direction.
  bool isParallelTo(Direction other) =>
      (isHorizontal && other.isHorizontal) || (isVertical && other.isVertical);
}
