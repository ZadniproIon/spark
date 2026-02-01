import 'package:hive/hive.dart';

enum NoteType { text, voice }

class Note {
  Note({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.audioPath,
    this.isPinned = false,
    this.isTrashed = false,
    this.trashedAt,
  });

  final String id;
  final NoteType type;
  final String content;
  final String? audioPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isTrashed;
  final DateTime? trashedAt;

  Note copyWith({
    String? id,
    NoteType? type,
    String? content,
    String? audioPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isTrashed,
    DateTime? trashedAt,
  }) {
    return Note(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isTrashed: isTrashed ?? this.isTrashed,
      trashedAt: trashedAt ?? this.trashedAt,
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[5] as int),
      isPinned: fields[6] as bool,
      isTrashed: fields[7] as bool,
      trashedAt: fields[8] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[8] as int),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.trashedAt?.millisecondsSinceEpoch);
  }
}
