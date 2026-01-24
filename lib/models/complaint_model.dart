import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintCategory { water, electricity, mess, washroom, roomIssue, other }

enum ComplaintStatus { pending, inProgress, resolved }

class ComplaintModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNo;
  final ComplaintCategory category;
  final String description;
  final String? photoUrl;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminNote;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNo,
    required this.category,
    required this.description,
    this.photoUrl,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.adminNote,
  });

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    return ComplaintModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNo: map['roomNo'] ?? '',
      category: ComplaintCategory.values.firstWhere(
        (e) => e.toString() == 'ComplaintCategory.${map['category']}',
        orElse: () => ComplaintCategory.other,
      ),
      description: map['description'] ?? '',
      photoUrl: map['photoUrl'],
      status: ComplaintStatus.values.firstWhere(
        (e) => e.toString() == 'ComplaintStatus.${map['status']}',
        orElse: () => ComplaintStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      adminNote: map['adminNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNo': roomNo,
      'category': category.toString().split('.').last,
      'description': description,
      'photoUrl': photoUrl,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'adminNote': adminNote,
    };
  }

  String get categoryName {
    switch (category) {
      case ComplaintCategory.water:
        return 'Water';
      case ComplaintCategory.electricity:
        return 'Electricity';
      case ComplaintCategory.mess:
        return 'Mess';
      case ComplaintCategory.washroom:
        return 'Washroom';
      case ComplaintCategory.roomIssue:
        return 'Room Issue';
      case ComplaintCategory.other:
        return 'Other';
    }
  }

  ComplaintModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? roomNo,
    ComplaintCategory? category,
    String? description,
    String? photoUrl,
    ComplaintStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminNote,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      roomNo: roomNo ?? this.roomNo,
      category: category ?? this.category,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}
