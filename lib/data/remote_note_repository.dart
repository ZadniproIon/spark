import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

class RemoteNoteRepository {
  RemoteNoteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('notes');
  }

  Future<List<Note>> fetchNotes(String uid) async {
    final snapshot = await _notesRef(uid).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  Stream<List<Note>> watchNotes(String uid) {
    return _notesRef(uid).snapshots().map((snapshot) {
      return snapshot.docs.map(_fromDoc).toList();
    });
  }

  Future<void> upsert(String uid, Note note) async {
    await _notesRef(uid)
        .doc(note.id)
        .set(note.toMap(), SetOptions(merge: true));
  }

  Future<void> upsertMany(String uid, Iterable<Note> notes) async {
    final batch = _firestore.batch();
    final ref = _notesRef(uid);
    for (final note in notes) {
      batch.set(ref.doc(note.id), note.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> delete(String uid, String noteId) async {
    await _notesRef(uid).doc(noteId).delete();
  }

  Note _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Note.fromMap(_normalizeFirestoreData(data), id: doc.id);
  }

  Map<String, dynamic> _normalizeFirestoreData(Map<String, dynamic> data) {
    return <String, dynamic>{
      ...data,
      'createdAt': _toDate(data['createdAt']),
      'updatedAt': _toDate(data['updatedAt']),
      'trashedAt': _toDate(data['trashedAt']),
    };
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
