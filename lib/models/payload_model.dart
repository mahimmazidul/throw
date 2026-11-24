/// What a payload is.
enum PayloadKind {
  file,
  text,
  clipboard,
}

/// Which way a payload is moving.
enum PayloadDirection {
  sent,
  received,
}

/// A single unit of transfer: one file, or a blob of text.
class PayloadModel {
  const PayloadModel({
    required this.id,
    required this.kind,
    required this.direction,
    this.name,
    this.sizeBytes = 0,
    this.text,
    this.path,
    required this.createdAt,
  });

  /// Payload id assigned by the transport (Nearby payload id, local uuid, …).
  final String id;

  final PayloadKind kind;

  final PayloadDirection direction;

  /// File name — null for text payloads.
  final String? name;

  /// File size in bytes; 0 for text.
  final int sizeBytes;

  /// Text content for [PayloadKind.text] and [PayloadKind.clipboard].
  final String? text;

  /// Absolute path on disk for received files, ready for [open_file].
  final String? path;

  final DateTime createdAt;

  /// Short human label for lists and progress rows.
  String get label {
    if (kind == PayloadKind.file ||
        kind == PayloadKind.clipboard && name != null) {
      return name ?? text ?? '';
    }
    final body = text ?? '';
    return body.length > 40 ? '${body.substring(0, 40)}…' : body;
  }

  PayloadModel copyWith({
    String? id,
    PayloadKind? kind,
    PayloadDirection? direction,
    String? name,
    int? sizeBytes,
    String? text,
    String? path,
    DateTime? createdAt,
  }) {
    return PayloadModel(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      direction: direction ?? this.direction,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      text: text ?? this.text,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'direction': direction.name,
        'name': name,
        'sizeBytes': sizeBytes,
        'text': text,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PayloadModel.fromJson(Map<String, dynamic> json) {
    return PayloadModel(
      id: json['id'] as String,
      kind: PayloadKind.values.byName(json['kind'] as String),
      direction: PayloadDirection.values.byName(json['direction'] as String),
      name: json['name'] as String?,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      text: json['text'] as String?,
      path: json['path'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) => other is PayloadModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
