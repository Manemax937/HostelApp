import 'package:cloud_firestore/cloud_firestore.dart';

enum NoticePriority { high, medium, low }

class Notice {
  final String id;
  final String title;
  final String description;
  final NoticePriority priority;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final String? residenceName;

  Notice({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.residenceName,
  });

  factory Notice.fromMap(Map<String, dynamic> map, String id) {
    return Notice(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: NoticePriority.values.firstWhere(
        (e) => e.toString() == 'NoticePriority.${map['priority']}',
        orElse: () => NoticePriority.medium,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      residenceName: map['residenceName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'residenceName': residenceName,
    };
  }

  Notice copyWith({
    String? id,
    String? title,
    String? description,
    NoticePriority? priority,
    DateTime? createdAt,
    String? createdBy,
    String? createdByName,
    String? residenceName,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      residenceName: residenceName ?? this.residenceName,
    );
  }
}
