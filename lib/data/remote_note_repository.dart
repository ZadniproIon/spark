import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note.dart';

class RemoteNoteRepository {
  RemoteNoteRepository(this._client);

  final SupabaseClient _client;

  Future<List<Note>> fetchNotes(String uid) async {
    final data = await _client
        .from('notes')
        .select()
        .eq('owner_id', uid)
        .order('updated_at', ascending: false);
    final rows = (data as List).cast<Map<String, dynamic>>();
    return rows.map(Note.fromMap).toList();
  }

  Future<void> upsert(String uid, Note note) async {
    final payload = note.copyWith(ownerId: uid).toMap();
    await _client.from('notes').upsert(payload);
  }

  Future<void> delete(String uid, String noteId) async {
    await _client.from('notes').delete().eq('owner_id', uid).eq('id', noteId);
  }
}
