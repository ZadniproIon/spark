import 'package:hive/hive.dart';

enum NoteType { text, voice }

class Note {
  Note({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    this.audioPath,
    this.audioUrl,
    this.createdAtLocal,
    this.updatedAtLocal,
    this.isPinned = false,
    this.isTrashed = false,
    this.trashedAt,
    this.isSynced = true,
  });

  final String id;
  final NoteType type;
  final String content;
  final String? audioPath;
  final String? audioUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String ownerId;
  final String? createdAtLocal;
  final String? updatedAtLocal;
  final bool isPinned;
  final bool isTrashed;
  final DateTime? trashedAt;
  final bool isSynced;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'audio_url': audioUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_at_local': createdAtLocal,
      'updated_at_local': updatedAtLocal,
      'owner_id': ownerId,
      'is_pinned': isPinned,
      'is_trashed': isTrashed,
      'trashed_at': trashedAt?.toIso8601String(),
    };
  }

  static Note fromMap(Map<String, dynamic> map, {String? id}) {
    NoteType resolvedType = NoteType.text;
    final rawType = map['type'];
    if (rawType is String) {
      resolvedType = NoteType.values.firstWhere(
        (type) => type.name == rawType,
        orElse: () => NoteType.text,
      );
    } else if (rawType is int &&
        rawType >= 0 &&
        rawType < NoteType.values.length) {
      resolvedType = NoteType.values[rawType];
    }

    final createdAt =
        _readDate(map['created_at'] ?? map['createdAt']);
    final updatedAt =
        _readDate(map['updated_at'] ?? map['updatedAt'], fallback: createdAt);
    final trashedAt =
        _readNullableDate(map['trashed_at'] ?? map['trashedAt']);

    return Note(
      id: id ?? (map['id'] as String? ?? ''),
      type: resolvedType,
      content: map['content'] as String? ?? '',
      audioPath: map['audioPath'] as String?,
      audioUrl: map['audio_url'] as String? ?? map['audioUrl'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      ownerId: map['owner_id'] as String? ?? map['ownerId'] as String? ?? '',
      createdAtLocal: map['created_at_local'] as String? ??
          map['createdAtLocal'] as String?,
      updatedAtLocal: map['updated_at_local'] as String? ??
          map['updatedAtLocal'] as String?,
      isPinned: map['is_pinned'] as bool? ?? map['isPinned'] as bool? ?? false,
      isTrashed:
          map['is_trashed'] as bool? ?? map['isTrashed'] as bool? ?? false,
      trashedAt: trashedAt,
      isSynced: map['isSynced'] as bool? ?? true,
    );
  }

  static DateTime _readDate(dynamic value, {DateTime? fallback}) {
    return _readNullableDate(value) ?? fallback ?? DateTime.now();
  }

  static DateTime? _readNullableDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Note copyWith({
    String? id,
    NoteType? type,
    String? content,
    String? audioPath,
    String? audioUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerId,
    String? createdAtLocal,
    String? updatedAtLocal,
    bool? isPinned,
    bool? isTrashed,
    DateTime? trashedAt,
    bool? isSynced,
  }) {
    return Note(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerId: ownerId ?? this.ownerId,
      createdAtLocal: createdAtLocal ?? this.createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
      isPinned: isPinned ?? this.isPinned,
      isTrashed: isTrashed ?? this.isTrashed,
      trashedAt: trashedAt ?? this.trashedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 1;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      type: NoteType.values[fields[1] as int],
      content: fields[2] as String,
      audioPath: fields[3] as String?,
      audioUrl: fields[9] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[5] as int),
      ownerId: fields[11] as String? ?? '',
      createdAtLocal: fields[12] as String?,
      updatedAtLocal: fields[13] as String?,
      isPinned: fields[6] as bool,
      isTrashed: fields[7] as bool,
      trashedAt: fields[8] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[8] as int),
      isSynced: fields[10] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.index)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.audioPath)
      ..writeByte(4)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.updatedAt.millisecondsSinceEpoch)
      ..writeByte(6)
      ..write(obj.isPinned)
      ..writeByte(7)
      ..write(obj.isTrashed)
      ..writeByte(8)
      ..write(obj.trashedAt?.millisecondsSinceEpoch)
      ..writeByte(9)
      ..write(obj.audioUrl)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.ownerId)
      ..writeByte(12)
      ..write(obj.createdAtLocal)
      ..writeByte(13)
      ..write(obj.updatedAtLocal);
  }
}
