import 'package:equatable/equatable.dart';

/// The kind of a field record.
///
/// The kind drives the badge colour and the icon on the dashboard, so it is
/// kept as a closed enum — a raw string would leak into the UI as lowercase
/// text and break the title-case rule of the design system.
enum FieldRecordKind {
  /// A peer, position or terrain observation.
  observation,

  /// A task the operator still has to close.
  checklist,

  /// An incident that needs the whole squad to look at it.
  incident;

  /// Human readable label — always title case, never raw lowercase.
  String get label {
    switch (this) {
      case FieldRecordKind.observation:
        return 'Observation';
      case FieldRecordKind.checklist:
        return 'Checklist';
      case FieldRecordKind.incident:
        return 'Incident';
    }
  }

  /// Safe lookup that never throws on an unknown persisted value.
  static FieldRecordKind fromName(String? name) {
    for (final kind in FieldRecordKind.values) {
      if (kind.name == name) return kind;
    }
    return FieldRecordKind.observation;
  }
}

/// A single operator-authored record on the home dashboard.
///
/// This is the DTO of the dashboard data layer: it knows how to serialise
/// itself into Hive, how to read itself back and whether it is still a mock
/// seed row. It knows nothing about widgets.
class FieldRecord extends Equatable {
  const FieldRecord({
    required this.id,
    required this.title,
    required this.detail,
    required this.kind,
    required this.createdAt,
    this.isMock = false,
  });

  /// Reads a persisted row.
  factory FieldRecord.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'];
    return FieldRecord(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      kind: FieldRecordKind.fromName(rawKind?.toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isMock: json['isMock'] == true,
    );
  }

  /// Unique key of the record — the de-duplication handle of the store.
  final String id;

  /// Short headline of the record.
  final String title;

  /// Optional body of the record.
  final String detail;

  /// Category badge of the record.
  final FieldRecordKind kind;

  /// Creation stamp.
  final DateTime createdAt;

  /// True while the row is a demo seed that the operator never typed.
  final bool isMock;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'detail': detail,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'isMock': isMock,
      };

  FieldRecord copyWith({
    String? id,
    String? title,
    String? detail,
    FieldRecordKind? kind,
    DateTime? createdAt,
    bool? isMock,
  }) {
    return FieldRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      isMock: isMock ?? this.isMock,
    );
  }

  @override
  List<Object?> get props => [id, title, detail, kind, createdAt, isMock];
}
