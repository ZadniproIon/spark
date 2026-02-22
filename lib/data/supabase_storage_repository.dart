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
    await _client.storage
        .from(_bucket)
        .upload(
          path,
          file,
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    return path;
  }

  Future<String> createSignedUrlForPath({
    required String path,
    int expiresInSeconds = 3600,
  }) {
    return _client.storage
        .from(_bucket)
        .createSignedUrl(path, expiresInSeconds);
  }

  Future<String> createSignedUrlForNote({
    required String uid,
    required String noteId,
    int expiresInSeconds = 3600,
  }) {
    return createSignedUrlForPath(
      path: _pathFor(uid, noteId),
      expiresInSeconds: expiresInSeconds,
    );
  }

  String? tryExtractPathFromReference(String reference) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return trimmed;
    }

    final segments = uri.pathSegments;
    if (segments.length < 6) {
      return null;
    }

    final storageIndex = segments.indexOf('storage');
    if (storageIndex == -1 || segments.length <= storageIndex + 5) {
      return null;
    }

    final isStorageObjectEndpoint =
        segments[storageIndex + 1] == 'v1' &&
        segments[storageIndex + 2] == 'object';
    if (!isStorageObjectEndpoint) {
      return null;
    }

    final accessKind = segments[storageIndex + 3];
    if (accessKind != 'public' &&
        accessKind != 'sign' &&
        accessKind != 'authenticated') {
      return null;
    }

    final bucketId = segments[storageIndex + 4];
    if (bucketId != _bucket) {
      return null;
    }

    final objectPathSegments = segments.sublist(storageIndex + 5);
    if (objectPathSegments.isEmpty) {
      return null;
    }
    return objectPathSegments.join('/');
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
