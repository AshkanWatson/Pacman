import 'direction.dart';

/// An integer grid coordinate in the maze.
class Tile {
  const Tile(this.col, this.row);

  final int col;
  final int row;

  Tile operator +(Tile other) => Tile(col + other.col, row + other.row);

  Tile step(Direction dir, [int count = 1]) =>
      Tile(col + dir.dx * count, row + dir.dy * count);

  /// Squared euclidean distance, which is what the arcade compares when a
  /// ghost picks the neighbouring tile closest to its target.
  int distanceSquaredTo(Tile other) {
    final dc = col - other.col;
    final dr = row - other.row;
    return dc * dc + dr * dr;
  }

  @override
  bool operator ==(Object other) =>
      other is Tile && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'Tile($col, $row)';
}
