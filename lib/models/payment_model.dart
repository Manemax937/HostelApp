import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, verified, rejected }

enum PaymentMethod { online, cash }

class PaymentModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNo;
  final double amount;
  final String transactionId;
  final String? screenshotUrl;
  final PaymentStatus status;
  final DateTime submittedAt;
  final DateTime? verifiedAt;
  final String? adminNote;
  final String month; // Format: "Jan 2026"
  final PaymentMethod paymentMethod; // online or cash

  PaymentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNo,
    required this.amount,
    required this.transactionId,
    this.screenshotUrl,
    required this.status,
    required this.submittedAt,
    this.verifiedAt,
    this.adminNote,
    required this.month,
    this.paymentMethod = PaymentMethod.online,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNo: map['roomNo'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      transactionId: map['transactionId'] ?? '',
      screenshotUrl: map['screenshotUrl'],
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == 'PaymentStatus.${map['status']}',
        orElse: () => PaymentStatus.pending,
      ),
      submittedAt: (map['submittedAt'] as Timestamp).toDate(),
      verifiedAt: map['verifiedAt'] != null
          ? (map['verifiedAt'] as Timestamp).toDate()
          : null,
      adminNote: map['adminNote'],
      month: map['month'] ?? '',
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == 'PaymentMethod.${map['paymentMethod']}',
        orElse: () => PaymentMethod.online,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNo': roomNo,
      'amount': amount,
      'transactionId': transactionId,
      'screenshotUrl': screenshotUrl,
      'status': status.toString().split('.').last,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'adminNote': adminNote,
      'month': month,
      'paymentMethod': paymentMethod.toString().split('.').last,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? roomNo,
    double? amount,
    String? transactionId,
    String? screenshotUrl,
    PaymentStatus? status,
    DateTime? submittedAt,
    DateTime? verifiedAt,
    String? adminNote,
    String? month,
    PaymentMethod? paymentMethod,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      roomNo: roomNo ?? this.roomNo,
      amount: amount ?? this.amount,
      transactionId: transactionId ?? this.transactionId,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      adminNote: adminNote ?? this.adminNote,
      month: month ?? this.month,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}
