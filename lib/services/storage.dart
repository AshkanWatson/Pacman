import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key/value persistence, so repositories can be tested without
/// platform plugins.
abstract class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? initial]) : _data = {...?initial};
  final Map<String, String> _data;

  @override
  String? read(String key) => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}

class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<SharedPrefsStore> open() async =>
      SharedPrefsStore(await SharedPreferences.getInstance());

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Decodes JSON stored under [key], falling back to null on corruption.
Object? readJson(KeyValueStore store, String key) {
  final raw = store.read(key);
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}
