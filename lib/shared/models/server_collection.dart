import 'package:sqlite3/sqlite3.dart';

/// A user-created grouping of connections.
class ServerCollection {
  const ServerCollection({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'color': color,
    'position': position,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static ServerCollection fromRow(Row row) => ServerCollection(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    icon: row['icon'] as String?,
    color: row['color'] as String?,
    position: row['position'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );

  ServerCollection copyWith({
    String? name,
    String? description,
    String? icon,
    String? color,
    int? position,
    DateTime? updatedAt,
  }) => ServerCollection(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    position: position ?? this.position,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
