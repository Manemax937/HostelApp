import 'package:cloud_firestore/cloud_firestore.dart';

class RentDue {
  final String id;
  final String userId;
  final String userName;
  final String roomNo;
  final String residenceName;
  final double amount;
  final String month; // Format: "Jan 2026"
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isPaid;
  final String? paymentId; // Reference to payment document

  RentDue({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNo,
    required this.residenceName,
    required this.amount,
    required this.month,
    required this.createdAt,
    this.dueDate,
    this.isPaid = false,
    this.paymentId,
  });

  factory RentDue.fromMap(Map<String, dynamic> map, String id) {
    return RentDue(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNo: map['roomNo'] ?? '',
      residenceName: map['residenceName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      month: map['month'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      dueDate: map['dueDate'] != null
          ? (map['dueDate'] as Timestamp).toDate()
          : null,
      isPaid: map['isPaid'] ?? false,
      paymentId: map['paymentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNo': roomNo,
      'residenceName': residenceName,
      'amount': amount,
      'month': month,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isPaid': isPaid,
      'paymentId': paymentId,
    };
  }

  RentDue copyWith({
    String? id,
    String? userId,
    String? userName,
    String? roomNo,
    String? residenceName,
    double? amount,
    String? month,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? isPaid,
    String? paymentId,
  }) {
    return RentDue(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      roomNo: roomNo ?? this.roomNo,
      residenceName: residenceName ?? this.residenceName,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      paymentId: paymentId ?? this.paymentId,
    );
  }

  /// Get document ID for a specific user and month
  static String getDocId(String userId, String month) {
    return '${userId}_${month.replaceAll(' ', '_')}';
  }
}
