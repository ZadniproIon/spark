import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageRepository {
  SupabaseStorageRepository(this._client, this._bucket);

  final SupabaseClient _client;
  final String _bucket;

  String _pathFor(String uid, String noteId) => '$uid/$noteId.m4a';

  Future<String?> uploadNoteAudio({
    required String uid,
    required String noteId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return null;
    }

    final path = _pathFor(uid, noteId);
    await _client.storage.from(_bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> deleteNoteAudio({
    required String uid,
    required String noteId,
  }) async {
    try {
      await _client.storage.from(_bucket).remove([_pathFor(uid, noteId)]);
    } catch (_) {
      // Ignore missing files or permission issues on cleanup.
    }
  }
}
