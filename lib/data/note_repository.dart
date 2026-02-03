import 'package:hive/hive.dart';

import '../models/note.dart';

class NoteRepository {
  NoteRepository(this._box);

  final Box<Note> _box;

  List<Note> getAllForOwner(String ownerId) {
    return _box.values
        .where((note) => note.ownerId == ownerId)
        .toList(growable: false);
  }

  Note? getById(String id) {
    return _box.get(id);
  }

  Future<void> upsert(Note note) async {
    await _box.put(note.id, note);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
