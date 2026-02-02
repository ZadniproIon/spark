import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/note_repository.dart';
import '../data/remote_note_repository.dart';
import '../models/note.dart';
import 'auth_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final box = Hive.box<Note>('notes');
  return NoteRepository(box);
});

final remoteNoteRepositoryProvider = Provider<RemoteNoteRepository>((ref) {
  return RemoteNoteRepository(FirebaseFirestore.instance);
});

final notesProvider = ChangeNotifierProvider<NotesController>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final remoteRepo = ref.watch(remoteNoteRepositoryProvider);
  final controller = NotesController(repo, remoteRepo);
  controller.load();
  ref.listen<AsyncValue<dynamic>>(
    authStateProvider,
    (previous, next) {
      controller.setAuthUser(next.valueOrNull?.uid);
    },
    fireImmediately: true,
  );
  return controller;
});

class NotesController extends ChangeNotifier {
  NotesController(this._repository, this._remoteRepository);

  final NoteRepository _repository;
  final RemoteNoteRepository _remoteRepository;
  final Uuid _uuid = const Uuid();

  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _userId;

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

  Future<void> setAuthUser(String? userId) async {
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    if (_userId == null) {
      return;
    }
    await _syncWithRemote();
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
    await _pushNoteToRemote(note);
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
    await _pushNoteToRemote(note);
    await load();
  }

  Future<void> updateNote(Note note, {String? content}) async {
    final updated = note.copyWith(
      content: content ?? note.content,
      updatedAt: DateTime.now(),
    );
    await _repository.upsert(updated);
    await _pushNoteToRemote(updated);
    await load();
  }

  Future<void> togglePin(Note note) async {
    final updated = note.copyWith(
      isPinned: !note.isPinned,
    );
    await _repository.upsert(updated);
    await _pushNoteToRemote(updated);
    await load();
  }

  Future<void> moveToTrash(Note note) async {
    final updated = note.copyWith(
      isTrashed: true,
      isPinned: false,
      trashedAt: DateTime.now(),
    );
    await _repository.upsert(updated);
    await _pushNoteToRemote(updated);
    await load();
  }

  Future<void> restore(Note note) async {
    final updated = note.copyWith(
      isTrashed: false,
      trashedAt: null,
    );
    await _repository.upsert(updated);
    await _pushNoteToRemote(updated);
    await load();
  }

  Future<void> deleteForever(Note note) async {
    await _repository.delete(note.id);
    await _deleteRemote(note.id);
    await load();
  }

  Future<void> _syncWithRemote() async {
    if (_userId == null || _isSyncing) {
      return;
    }
    _isSyncing = true;
    try {
      final remoteNotes = await _remoteRepository.fetchNotes(_userId!);
      final remoteIds = remoteNotes.map((note) => note.id).toSet();
      final localById = {for (final note in _notes) note.id: note};
      bool changed = false;

      for (final remote in remoteNotes) {
        final local = localById[remote.id];
        if (local == null) {
          await _repository.upsert(remote);
          localById[remote.id] = remote;
          changed = true;
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          await _repository.upsert(remote);
          localById[remote.id] = remote;
          changed = true;
        } else if (!_notesEqual(local, remote)) {
          await _remoteRepository.upsert(_userId!, local);
        }
      }

      final missingRemote = localById.values
          .where((note) => !remoteIds.contains(note.id))
          .toList();
      if (missingRemote.isNotEmpty) {
        await _remoteRepository.upsertMany(_userId!, missingRemote);
      }

      if (changed) {
        _notes = localById.values.toList();
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Remote sync failed: $error');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushNoteToRemote(Note note) async {
    if (_userId == null) {
      return;
    }
    try {
      await _remoteRepository.upsert(_userId!, note);
    } catch (error) {
      debugPrint('Remote note update failed: $error');
    }
  }

  Future<void> _deleteRemote(String noteId) async {
    if (_userId == null) {
      return;
    }
    try {
      await _remoteRepository.delete(_userId!, noteId);
    } catch (error) {
      debugPrint('Remote delete failed: $error');
    }
  }

  bool _notesEqual(Note a, Note b) {
    return a.id == b.id &&
        a.type == b.type &&
        a.content == b.content &&
        a.audioPath == b.audioPath &&
        a.createdAt == b.createdAt &&
        a.updatedAt == b.updatedAt &&
        a.isPinned == b.isPinned &&
        a.isTrashed == b.isTrashed &&
        a.trashedAt == b.trashedAt;
  }
}
