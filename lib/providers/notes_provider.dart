import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/note_repository.dart';
import '../data/remote_note_repository.dart';
import '../data/supabase_config.dart';
import '../data/supabase_storage_repository.dart';
import '../models/note.dart';
import 'auth_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final box = Hive.box<Note>('notes');
  return NoteRepository(box);
});

final remoteNoteRepositoryProvider = Provider<RemoteNoteRepository>((ref) {
  return RemoteNoteRepository(FirebaseFirestore.instance);
});

final supabaseStorageRepositoryProvider = Provider<SupabaseStorageRepository>((ref) {
  return SupabaseStorageRepository(
    Supabase.instance.client,
    SupabaseConfig.voiceBucket,
  );
});

final notesProvider = ChangeNotifierProvider<NotesController>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final remoteRepo = ref.watch(remoteNoteRepositoryProvider);
  final storageRepo = ref.watch(supabaseStorageRepositoryProvider);
  final controller = NotesController(repo, remoteRepo, storageRepo);
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
  NotesController(this._repository, this._remoteRepository, this._storageRepository);

  final NoteRepository _repository;
  final RemoteNoteRepository _remoteRepository;
  final SupabaseStorageRepository _storageRepository;
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
      _notes = [];
      notifyListeners();
      return;
    }
    await _claimLegacyNotes(_userId!);
    await load();
    await _syncWithRemote();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    if (_userId == null) {
      _notes = [];
    } else {
      _notes = _repository.getAllForOwner(_userId!);
    }
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
      ownerId: _userId ?? '',
      isSynced: false,
    );
    await _repository.upsert(note);
    unawaited(_pushNoteToRemote(note));
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
      ownerId: _userId ?? '',
      isSynced: false,
    );
    await _repository.upsert(note);
    unawaited(_pushNoteToRemote(note));
    await load();
  }

  Future<void> updateNote(Note note, {String? content}) async {
    final updated = note.copyWith(
      content: content ?? note.content,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _repository.upsert(updated);
    unawaited(_pushNoteToRemote(updated));
    await load();
  }

  Future<void> togglePin(Note note) async {
    final updated = note.copyWith(
      isPinned: !note.isPinned,
      isSynced: false,
    );
    await _repository.upsert(updated);
    unawaited(_pushNoteToRemote(updated));
    await load();
  }

  Future<void> moveToTrash(Note note) async {
    final updated = note.copyWith(
      isTrashed: true,
      isPinned: false,
      trashedAt: DateTime.now(),
      isSynced: false,
    );
    await _repository.upsert(updated);
    unawaited(_pushNoteToRemote(updated));
    await load();
  }

  Future<void> restore(Note note) async {
    final updated = note.copyWith(
      isTrashed: false,
      trashedAt: null,
      isSynced: false,
    );
    await _repository.upsert(updated);
    unawaited(_pushNoteToRemote(updated));
    await load();
  }

  Future<void> deleteForever(Note note) async {
    await _repository.delete(note.id);
    await _deleteRemote(note);
    await load();
  }

  Future<void> _syncWithRemote() async {
    if (_userId == null || _isSyncing) {
      return;
    }
    _isSyncing = true;
    try {
      final remoteNotes = await _remoteRepository.fetchNotes(_userId!);
      final normalizedRemote = remoteNotes
          .map((note) => note.copyWith(ownerId: _userId))
          .toList();
      final remoteIds = normalizedRemote.map((note) => note.id).toSet();
      final localById = {for (final note in _notes) note.id: note};
      bool changed = false;

      for (final remote in normalizedRemote) {
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
          await _pushNoteToRemote(local);
        }
      }

      final missingRemote = localById.values
          .where((note) => !remoteIds.contains(note.id))
          .toList();
      for (final note in missingRemote) {
        await _pushNoteToRemote(note);
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
      final prepared = await _ensureAudioUploaded(note);
      await _remoteRepository.upsert(_userId!, prepared);
      final synced = prepared.copyWith(isSynced: true);
      await _repository.upsert(synced);
      _replaceLocalNote(synced);
    } catch (error) {
      debugPrint('Remote note update failed: $error');
    }
  }

  Future<void> _deleteRemote(Note note) async {
    if (_userId == null) {
      return;
    }
    try {
      await _remoteRepository.delete(_userId!, note.id);
      if (note.type == NoteType.voice) {
        await _storageRepository.deleteNoteAudio(
          uid: _userId!,
          noteId: note.id,
        );
      }
    } catch (error) {
      debugPrint('Remote delete failed: $error');
    }
  }

  Future<Note> _ensureAudioUploaded(Note note) async {
    if (_userId == null || note.type != NoteType.voice) {
      return note;
    }
    if (note.audioUrl != null && note.audioUrl!.isNotEmpty) {
      return note;
    }
    final localPath = note.audioPath;
    if (localPath == null || localPath.isEmpty) {
      return note;
    }

    try {
      final url = await _storageRepository.uploadNoteAudio(
        uid: _userId!,
        noteId: note.id,
        localPath: localPath,
      );
      if (url == null) {
        return note;
      }
      final updated = note.copyWith(audioUrl: url);
      await _repository.upsert(updated);
      _replaceLocalNote(updated);
      return updated;
    } catch (error) {
      debugPrint('Supabase upload failed: $error');
      return note;
    }
  }

  void _replaceLocalNote(Note note) {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      return;
    }
    _notes[index] = note;
    notifyListeners();
  }

  bool _notesEqual(Note a, Note b) {
    return a.id == b.id &&
        a.type == b.type &&
        a.content == b.content &&
        a.audioUrl == b.audioUrl &&
        a.createdAt == b.createdAt &&
        a.updatedAt == b.updatedAt &&
        a.ownerId == b.ownerId &&
        a.isPinned == b.isPinned &&
        a.isTrashed == b.isTrashed &&
        a.trashedAt == b.trashedAt;
  }

  Future<void> _claimLegacyNotes(String ownerId) async {
    final legacy = _repository
        .getAllForOwner('')
        .map((note) => note.copyWith(ownerId: ownerId, isSynced: false))
        .toList();
    if (legacy.isEmpty) {
      return;
    }
    for (final note in legacy) {
      await _repository.upsert(note);
    }
  }
}
