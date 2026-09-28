import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/core/direction.dart';
import 'package:pyman/game/core/maze.dart';
import 'package:pyman/game/core/tile.dart';

void main() {
  group('Maze', () {
    test('has arcade dimensions and collectible counts', () {
      final maze = Maze();
      expect(maze.width, 28);
      expect(maze.height, 31);
      var semicolons = 0;
      var braces = 0;
      for (var r = 0; r < maze.height; r++) {
        for (var c = 0; c < maze.width; c++) {
          switch (maze.itemAt(Tile(c, r))) {
            case Collectible.semicolon:
              semicolons++;
            case Collectible.powerBrace:
              braces++;
            case Collectible.none:
              break;
          }
        }
      }
      expect(semicolons, 240);
      expect(braces, 4);
      expect(maze.remaining, 244);
      expect(maze.total, 244);
    });

    test('taking a collectible removes it once', () {
      final maze = Maze();
      const t = Tile(1, 1);
      expect(maze.take(t), Collectible.semicolon);
      expect(maze.take(t), Collectible.none);
      expect(maze.remaining, 243);
      expect(maze.eaten, 1);
      maze.reset();
      expect(maze.remaining, 244);
    });

    test('tunnel wraps horizontally', () {
      final maze = Maze();
      expect(maze.isWalkableForPlayer(const Tile(-1, 14)), isTrue);
      expect(maze.isWalkableForPlayer(const Tile(28, 14)), isTrue);
      expect(maze.isTunnel(const Tile(2, 14)), isTrue);
      expect(maze.isTunnel(const Tile(10, 14)), isFalse);
      expect(maze.isWall(const Tile(-1, 13)), isTrue);
    });

    test('door is only passable for ghosts when allowed', () {
      final maze = Maze();
      const door = Tile(13, 12);
      expect(maze.cellAt(door), Cell.door);
      expect(maze.isWalkableForPlayer(door), isFalse);
      expect(maze.isWalkableForGhost(door), isFalse);
      expect(maze.isWalkableForGhost(door, throughDoor: true), isTrue);
    });

    test('every path cell is reachable from Python\'s start', () {
      final maze = Maze();
      final seen = <Tile>{const Tile(13, 23)};
      final queue = [const Tile(13, 23)];
      while (queue.isNotEmpty) {
        final t = queue.removeLast();
        for (final d in Direction.moving) {
          var n = t.step(d);
          n = Tile((n.col + maze.width) % maze.width, n.row);
          if (maze.isWalkableForPlayer(n) && seen.add(n)) queue.add(n);
        }
      }
      for (var r = 0; r < maze.height; r++) {
        for (var c = 0; c < maze.width; c++) {
          final t = Tile(c, r);
          if (maze.itemAt(t) != Collectible.none) {
            expect(seen.contains(t), isTrue, reason: '$t unreachable');
          }
        }
      }
    });
  });
}
