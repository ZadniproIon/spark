import 'dart:async';
import 'dart:io';
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
import '../utils/note_utils.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final box = Hive.box<Note>('notes');
  return NoteRepository(box);
});

final remoteNoteRepositoryProvider = Provider<RemoteNoteRepository>((ref) {
  return RemoteNoteRepository(Supabase.instance.client);
});

final supabaseStorageRepositoryProvider = Provider<SupabaseStorageRepository>((
  ref,
) {
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
  ref.listen<AsyncValue<dynamic>>(authStateProvider, (previous, next) {
    controller.setAuthUser(next.valueOrNull?.id);
  }, fireImmediately: true);
  return controller;
});

class NotesController extends ChangeNotifier {
  NotesController(
    this._repository,
    this._remoteRepository,
    this._storageRepository,
  ) : _pendingRemoteDeleteBox = Hive.box<dynamic>('pending_remote_deletes');

  final NoteRepository _repository;
  final RemoteNoteRepository _remoteRepository;
  final SupabaseStorageRepository _storageRepository;
  final Box<dynamic> _pendingRemoteDeleteBox;
  final Uuid _uuid = const Uuid();
  static const String _guestOwnerId = 'guest-local';
  static const Duration _syncInterval = Duration(seconds: 10);
  static const Duration _trashRetention = Duration(days: 30);

  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _userId;
  Timer? _syncTimer;

  String get _activeOwnerId => _userId ?? _guestOwnerId;

  bool get isLoading => _isLoading;

  bool get _hasUnsyncedNotes =>
      _notes.any((note) => !note.isSynced) || _hasPendingRemoteDeletes;

  bool get _hasPendingRemoteDeletes {
    if (_userId == null) {
      return false;
    }
    final prefix = '${_userId!}::';
    return _pendingRemoteDeleteBox.keys.any(
      (key) => key.toString().startsWith(prefix),
    );
  }

  DateTime _lastEditedSortTime(Note note) {
    final localStamp = note.updatedAtLocal;
    if (localStamp != null && localStamp.isNotEmpty) {
      final parsed = parseLocalTimestamp(localStamp);
      if (parsed != null) {
        return parsed;
      }
    }
    return note.updatedAt;
  }

  List<Note> get activeNotes {
    final notes = _notes.where((note) => !note.isTrashed).toList();
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return _lastEditedSortTime(b).compareTo(_lastEditedSortTime(a));
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

  int daysUntilTrashAutoDelete(Note note) {
    if (!note.isTrashed) {
      return _trashRetention.inDays;
    }
    final now = DateTime.now();
    final trashedAt = note.trashedAt ?? note.updatedAt;
    final today = DateTime(now.year, now.month, now.day);
    final expiresOn = DateTime(
      trashedAt.year,
      trashedAt.month,
      trashedAt.day,
    ).add(_trashRetention);
    final days = expiresOn.difference(today).inDays;
    if (days < 0) {
      return 0;
    }
    if (days > _trashRetention.inDays) {
      return _trashRetention.inDays;
    }
    return days;
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
      await _claimLegacyNotesForGuest();
      await load();
      _stopSyncLoop();
      return;
    }
    await _claimLegacyNotes(_userId!);
    await _migrateGuestNotesToUser(_userId!);
    await load();
    await _syncWithRemote();
    _ensureSyncLoop();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _notes = _repository.getAllForOwner(_activeOwnerId);
    await _purgeExpiredTrashedNotes();
    _isLoading = false;
    notifyListeners();
    _ensureSyncLoop();
  }

  Future<void> addTextNote(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final localStamp = formatNoteLocalString(now);
    final note = Note(
      id: _uuid.v4(),
      type: NoteType.text,
      content: trimmed,
      createdAt: now,
      updatedAt: now,
      ownerId: _activeOwnerId,
      createdAtLocal: localStamp,
      updatedAtLocal: localStamp,
      isSynced: false,
    );
    await _repository.upsert(note);
    unawaited(_pushNoteToRemote(note));
    await load();
  }

  Future<void> addVoiceNote(String audioPath) async {
    final now = DateTime.now();
    final localStamp = formatNoteLocalString(now);
    final note = Note(
      id: _uuid.v4(),
      type: NoteType.voice,
      content: 'Voice note',
      audioPath: audioPath,
      createdAt: now,
      updatedAt: now,
      ownerId: _activeOwnerId,
      createdAtLocal: localStamp,
      updatedAtLocal: localStamp,
      isSynced: false,
    );
    await _repository.upsert(note);
    unawaited(_pushNoteToRemote(note));
    await load();
  }

  Future<void> updateNote(Note note, {String? content}) async {
    final now = DateTime.now();
    final localStamp = formatNoteLocalString(now);
    final updated = note.copyWith(
      content: content ?? note.content,
      updatedAt: now,
      updatedAtLocal: localStamp,
      isSynced: false,
    );
    await _repository.upsert(updated);
    unawaited(_pushNoteToRemote(updated));
    await load();
  }

  Future<void> togglePin(Note note) async {
    final updated = note.copyWith(isPinned: !note.isPinned, isSynced: false);
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

  Future<void> purgeRemoteDataForCurrentUser() async {
    if (_userId == null) {
      return;
    }
    final uid = _userId!;
    final remoteNotes = await _remoteRepository.fetchNotes(uid);
    for (final note in remoteNotes) {
      await _remoteRepository.delete(uid, note.id);
      if (note.type == NoteType.voice) {
        await _storageRepository.deleteNoteAudio(uid: uid, noteId: note.id);
      }
    }
  }

  Future<void> wipeAllLocalData() async {
    _stopSyncLoop();
    final allLocalNotes = Hive.box<Note>(
      'notes',
    ).values.toList(growable: false);
    for (final note in allLocalNotes) {
      if (note.type != NoteType.voice) {
        continue;
      }
      final path = note.audioPath;
      if (path == null || path.isEmpty) {
        continue;
      }
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('Local audio delete failed: $error');
      }
    }

    await _repository.clear();
    if (_userId != null) {
      final prefix = '${_userId!}::';
      final pendingKeys = _pendingRemoteDeleteBox.keys
          .where((key) => key.toString().startsWith(prefix))
          .toList(growable: false);
      for (final key in pendingKeys) {
        await _pendingRemoteDeleteBox.delete(key);
      }
    }
    _notes = [];
    notifyListeners();
  }

  Future<void> _syncWithRemote() async {
    if (_userId == null || _isSyncing) {
      return;
    }
    _isSyncing = true;
    try {
      await _flushPendingRemoteDeletes();
      final remoteNotes = await _remoteRepository.fetchNotes(_userId!);
      final normalizedRemote = remoteNotes
          .map((note) => note.copyWith(ownerId: _userId))
          .toList();
      final localById = {for (final note in _notes) note.id: note};
      bool changed = false;
      final activeRemote = <Note>[];

      for (final remote in normalizedRemote) {
        if (_isTrashExpired(remote)) {
          await _deleteRemoteIfPossible(remote);
          if (localById.remove(remote.id) != null) {
            await _repository.delete(remote.id);
            changed = true;
          }
          continue;
        }
        activeRemote.add(remote);
      }

      final remoteIds = activeRemote.map((note) => note.id).toSet();

      for (final remote in activeRemote) {
        final local = localById[remote.id];
        if (local == null) {
          await _repository.upsert(remote);
          localById[remote.id] = remote;
          changed = true;
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          final merged = remote.copyWith(
            createdAtLocal: remote.createdAtLocal ?? local.createdAtLocal,
            updatedAtLocal: remote.updatedAtLocal ?? local.updatedAtLocal,
          );
          await _repository.upsert(merged);
          localById[remote.id] = merged;
          changed = true;
        } else if (!_notesEqual(local, remote)) {
          await _pushNoteToRemote(local);
        } else if (!local.isSynced) {
          final synced = local.copyWith(isSynced: true);
          await _repository.upsert(synced);
          localById[remote.id] = synced;
          changed = true;
        }
      }

      final missingRemote = localById.values
          .where((note) => !remoteIds.contains(note.id))
          .toList();
      for (final note in missingRemote) {
        if (_isTrashExpired(note)) {
          await _repository.delete(note.id);
          localById.remove(note.id);
          changed = true;
          continue;
        }
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
      _ensureSyncLoop();
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
      _ensureSyncLoop();
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
      await _removePendingRemoteDelete(_userId!, note.id);
    } catch (error) {
      debugPrint('Remote delete failed: $error');
      await _queuePendingRemoteDelete(note);
      _ensureSyncLoop();
    }
  }

  Future<void> _deleteRemoteIfPossible(Note note) async {
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
      await _removePendingRemoteDelete(_userId!, note.id);
    } catch (error) {
      debugPrint('Remote expired-trash delete failed: $error');
      await _queuePendingRemoteDelete(note);
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

  Future<void> _claimLegacyNotesForGuest() async {
    final legacy = _repository
        .getAllForOwner('')
        .map((note) => note.copyWith(ownerId: _guestOwnerId, isSynced: false))
        .toList();
    if (legacy.isEmpty) {
      return;
    }
    for (final note in legacy) {
      await _repository.upsert(note);
    }
  }

  Future<void> _migrateGuestNotesToUser(String ownerId) async {
    final guestNotes = _repository
        .getAllForOwner(_guestOwnerId)
        .map((note) => note.copyWith(ownerId: ownerId, isSynced: false))
        .toList();
    if (guestNotes.isEmpty) {
      return;
    }
    for (final note in guestNotes) {
      await _repository.upsert(note);
      unawaited(_pushNoteToRemote(note));
    }
  }

  void _ensureSyncLoop() {
    if (_userId == null) {
      _stopSyncLoop();
      return;
    }
    if (!_hasUnsyncedNotes) {
      _stopSyncLoop();
      return;
    }
    _syncTimer ??= Timer.periodic(_syncInterval, (_) => _syncWithRemote());
  }

  bool _isTrashExpired(Note note) {
    if (!note.isTrashed) {
      return false;
    }
    final trashedAt = note.trashedAt ?? note.updatedAt;
    final expiresAt = trashedAt.add(_trashRetention);
    return !DateTime.now().isBefore(expiresAt);
  }

  Future<void> _purgeExpiredTrashedNotes() async {
    final expired = _notes.where(_isTrashExpired).toList(growable: false);
    if (expired.isEmpty) {
      return;
    }
    final expiredIds = expired.map((note) => note.id).toSet();
    for (final note in expired) {
      await _repository.delete(note.id);
      await _deleteRemoteIfPossible(note);
    }
    _notes.removeWhere((note) => expiredIds.contains(note.id));
  }

  String _pendingRemoteDeleteKey(String uid, String noteId) => '$uid::$noteId';

  Future<void> _queuePendingRemoteDelete(Note note) async {
    if (_userId == null) {
      return;
    }
    final key = _pendingRemoteDeleteKey(_userId!, note.id);
    await _pendingRemoteDeleteBox.put(key, note.type == NoteType.voice);
  }

  Future<void> _removePendingRemoteDelete(String uid, String noteId) async {
    final key = _pendingRemoteDeleteKey(uid, noteId);
    if (_pendingRemoteDeleteBox.containsKey(key)) {
      await _pendingRemoteDeleteBox.delete(key);
    }
  }

  Future<void> _flushPendingRemoteDeletes() async {
    if (_userId == null) {
      return;
    }
    final uid = _userId!;
    final prefix = '$uid::';
    final keys = _pendingRemoteDeleteBox.keys.toList(growable: false);
    for (final key in keys) {
      final keyString = key.toString();
      if (!keyString.startsWith(prefix)) {
        continue;
      }
      final noteId = keyString.substring(prefix.length);
      final value = _pendingRemoteDeleteBox.get(key);
      final isVoice = value is bool ? value : false;
      try {
        await _remoteRepository.delete(uid, noteId);
        if (isVoice) {
          await _storageRepository.deleteNoteAudio(uid: uid, noteId: noteId);
        }
        await _pendingRemoteDeleteBox.delete(key);
      } catch (error) {
        debugPrint('Pending remote delete failed: $error');
      }
    }
  }

  void _stopSyncLoop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    _stopSyncLoop();
    super.dispose();
  }
}
