import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/note_repository.dart';
import '../models/note.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final box = Hive.box<Note>('notes');
  return NoteRepository(box);
});

final notesProvider = ChangeNotifierProvider<NotesController>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final controller = NotesController(repo);
  controller.load();
  return controller;
});

class NotesController extends ChangeNotifier {
  NotesController(this._repository);

  final NoteRepository _repository;
  final Uuid _uuid = const Uuid();

  List<Note> _notes = [];
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  List<Note> get activeNotes {
    final notes = _notes.where((note) => !note.isTrashed).toList();
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return notes;
  }

  List<Note> get trashedNotes {
    final notes = _notes.where((note) => note.isTrashed).toList();
    notes.sort((a, b) {
      final aTime = a.trashedAt ?? a.updatedAt;
      final bTime = b.trashedAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    return notes;
  }

  List<Note> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return activeNotes;
    }
    return activeNotes
        .where((note) => note.content.toLowerCase().contains(normalized))
        .toList();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _notes = _repository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTextNote(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      type: NoteType.text,
      content: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.upsert(note);
    await load();
  }

  Future<void> addVoiceNote(String audioPath) async {
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      type: NoteType.voice,
      content: 'Voice note',
      audioPath: audioPath,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.upsert(note);
    await load();
  }

  Future<void> updateNote(Note note, {String? content}) async {
    final updated = note.copyWith(
      content: content ?? note.content,
      updatedAt: DateTime.now(),
    );
    await _repository.upsert(updated);
    await load();
  }

  Future<void> togglePin(Note note) async {
    final updated = note.copyWith(
      isPinned: !note.isPinned,
      updatedAt: DateTime.now(),
    );
    await _repository.upsert(updated);
    await load();
  }

  Future<void> moveToTrash(Note note) async {
    final updated = note.copyWith(
      isTrashed: true,
      isPinned: false,
      trashedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.upsert(updated);
    await load();
  }

  Future<void> restore(Note note) async {
    final updated = note.copyWith(
      isTrashed: false,
      trashedAt: null,
      updatedAt: DateTime.now(),
    );
    await _repository.upsert(updated);
    await load();
  }

  Future<void> deleteForever(Note note) async {
    await _repository.delete(note.id);
    await load();
  }
}
