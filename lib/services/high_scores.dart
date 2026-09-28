import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'storage.dart';

@immutable
class HighScoreEntry {
  const HighScoreEntry({
    required this.name,
    required this.score,
    required this.level,
    required this.date,
  });

  factory HighScoreEntry.fromJson(Map<String, dynamic> json) => HighScoreEntry(
    name: json['name'] as String? ?? '???',
    score: json['score'] as int? ?? 0,
    level: json['level'] as int? ?? 1,
    date:
        DateTime.tryParse(json['date'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String name;
  final int score;
  final int level;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'level': level,
    'date': date.toIso8601String(),
  };
}

/// Top-10 leaderboard persisted locally.
class HighScoreRepository extends ChangeNotifier {
  HighScoreRepository(this._store) {
    final json = readJson(_store, _key);
    if (json is List) {
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          _entries.add(HighScoreEntry.fromJson(item));
        }
      }
      _sort();
    }
  }

  static const _key = 'high_scores_v1';
  static const maxEntries = 10;

  final KeyValueStore _store;
  final List<HighScoreEntry> _entries = [];

  List<HighScoreEntry> get entries => List.unmodifiable(_entries);

  int get best => _entries.isEmpty ? 0 : _entries.first.score;

  /// Whether [score] would make it onto the board.
  bool qualifies(int score) =>
      score > 0 &&
      (_entries.length < maxEntries || score > _entries.last.score);

  /// Adds [entry] and returns its 0-based rank, or -1 if it didn't place.
  Future<int> add(HighScoreEntry entry) async {
    if (!qualifies(entry.score)) return -1;
    _entries.add(entry);
    _sort();
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    final rank = _entries.indexOf(entry);
    await _save();
    notifyListeners();
    return rank;
  }

  Future<void> clear() async {
    _entries.clear();
    await _store.remove(_key);
    notifyListeners();
  }

  void _sort() => _entries.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.date.compareTo(b.date);
  });

  Future<void> _save() =>
      _store.write(_key, jsonEncode([for (final e in _entries) e.toJson()]));
}
