import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hostelapp/models/rent_due_model.dart';
import 'package:hostelapp/models/payment_model.dart';
import 'package:hostelapp/services/notification_service.dart';

class RentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _rentDuesCollection =>
      _firestore.collection('rentDues');
  CollectionReference get _paymentsCollection =>
      _firestore.collection('payments');
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Get current month in format "Jan 2026"
  String getCurrentMonth() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  /// Set rent due for a specific student
  Future<void> setRentDue({
    required String userId,
    required String userName,
    required String roomNo,
    required String residenceName,
    required double amount,
    String? month,
    DateTime? dueDate,
  }) async {
    final rentMonth = month ?? getCurrentMonth();
    final docId = RentDue.getDocId(userId, rentMonth);

    final rentDue = RentDue(
      id: docId,
      userId: userId,
      userName: userName,
      roomNo: roomNo,
      residenceName: residenceName,
      amount: amount,
      month: rentMonth,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      isPaid: false,
    );

    await _rentDuesCollection.doc(docId).set(rentDue.toMap());

    // Send notification to student about rent due
    await NotificationService().sendRentDueNotification(
      userId: userId,
      userName: userName,
      amount: amount,
      month: rentMonth,
    );
  }

  /// Update rent amount for a specific student
  Future<void> updateRentAmount({
    required String userId,
    required String month,
    required double newAmount,
  }) async {
    final docId = RentDue.getDocId(userId, month);
    await _rentDuesCollection.doc(docId).update({'amount': newAmount});
  }

  /// Get rent due for a specific student and month
  Future<RentDue?> getRentDue(String userId, {String? month}) async {
    final rentMonth = month ?? getCurrentMonth();
    final docId = RentDue.getDocId(userId, rentMonth);

    final doc = await _rentDuesCollection.doc(docId).get();
    if (doc.exists) {
      return RentDue.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Stream of rent due for a specific student
  Stream<RentDue?> streamRentDue(String userId, {String? month}) {
    final rentMonth = month ?? getCurrentMonth();
    final docId = RentDue.getDocId(userId, rentMonth);

    return _rentDuesCollection.doc(docId).snapshots().map((doc) {
      if (doc.exists) {
        return RentDue.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// Stream all rent dues for a residence
  Stream<List<RentDue>> streamAllRentDues(
    String residenceName, {
    String? month,
  }) {
    final rentMonth = month ?? getCurrentMonth();

    return _rentDuesCollection
        .where('residenceName', isEqualTo: residenceName)
        .where('month', isEqualTo: rentMonth)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    RentDue.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();
        });
  }

  /// Submit rent payment by student
  Future<String> submitRentPayment({
    required String userId,
    required String userName,
    required String roomNo,
    required String residenceName,
    required double amount,
    required String transactionId,
    String? month,
    String? screenshotUrl,
  }) async {
    final rentMonth = month ?? getCurrentMonth();

    // Create payment document
    final paymentRef = _paymentsCollection.doc();
    final payment = PaymentModel(
      id: paymentRef.id,
      userId: userId,
      userName: userName,
      roomNo: roomNo,
      amount: amount,
      transactionId: transactionId,
      status: PaymentStatus.pending,
      month: rentMonth,
      submittedAt: DateTime.now(),
      screenshotUrl: screenshotUrl,
    );

    await paymentRef.set(payment.toMap());

    // Update rent due to link payment
    final rentDocId = RentDue.getDocId(userId, rentMonth);
    await _rentDuesCollection.doc(rentDocId).update({
      'paymentId': paymentRef.id,
    });

    // Send notification to owner about pending payment (private - only owner sees)
    // First, find the owner of this residence
    final ownerQuery = await _usersCollection
        .where('role', isEqualTo: 'owner')
        .where('residenceName', isEqualTo: residenceName)
        .where('isVerified', isEqualTo: true)
        .limit(1)
        .get();

    if (ownerQuery.docs.isNotEmpty) {
      final ownerId = ownerQuery.docs.first.id;
      await NotificationService().sendPaymentPendingVerificationNotification(
        studentName: userName,
        amount: amount,
        ownerId: ownerId,
      );
    }

    return paymentRef.id;
  }

  /// Get payment for a rent due
  Future<PaymentModel?> getPaymentForRent(String? paymentId) async {
    if (paymentId == null) return null;

    final doc = await _paymentsCollection.doc(paymentId).get();
    if (doc.exists) {
      return PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Stream payment status
  Stream<PaymentModel?> streamPayment(String paymentId) {
    return _paymentsCollection.doc(paymentId).snapshots().map((doc) {
      if (doc.exists) {
        return PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// Verify payment (owner action)
  Future<void> verifyPayment(String paymentId, String rentDueId) async {
    // Get payment details for notification
    final paymentDoc = await _paymentsCollection.doc(paymentId).get();
    final paymentData = paymentDoc.data() as Map<String, dynamic>?;

    await _paymentsCollection.doc(paymentId).update({
      'status': 'verified',
      'verifiedAt': Timestamp.now(),
    });

    await _rentDuesCollection.doc(rentDueId).update({'isPaid': true});

    // Send notification to student
    if (paymentData != null) {
      await NotificationService().sendPaymentVerifiedNotification(
        userId: paymentData['userId'] ?? '',
        amount: (paymentData['amount'] ?? 0).toDouble(),
      );
    }
  }

  /// Reject payment (owner action)
  Future<void> rejectPayment(String paymentId, {String? reason}) async {
    await _paymentsCollection.doc(paymentId).update({
      'status': 'rejected',
      'adminNote': reason,
    });
  }

  /// Get all pending payments for a residence
  Stream<List<PaymentModel>> streamPendingPayments(String residenceName) {
    return _paymentsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => PaymentModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Get all payments history
  Stream<List<PaymentModel>> streamAllPayments(
    String residenceName, {
    int limit = 50,
  }) {
    return _paymentsCollection
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => PaymentModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Set rent for all students in a residence at once
  Future<void> setRentForAllStudents({
    required String residenceName,
    required double amount,
    String? month,
    DateTime? dueDate,
  }) async {
    final rentMonth = month ?? getCurrentMonth();

    // Get all students in the residence
    final usersSnapshot = await _usersCollection
        .where('residenceName', isEqualTo: residenceName)
        .where('role', isEqualTo: 'student')
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _firestore.batch();

    for (final doc in usersSnapshot.docs) {
      final userData = doc.data() as Map<String, dynamic>;
      final oderId = doc.id;
      final userName = userData['fullName'] ?? '';
      final roomNo = userData['roomNo'] ?? '';

      final docId = RentDue.getDocId(oderId, rentMonth);
      final rentDue = RentDue(
        id: docId,
        userId: oderId,
        userName: userName,
        roomNo: roomNo,
        residenceName: residenceName,
        amount: amount,
        month: rentMonth,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        isPaid: false,
      );

      batch.set(_rentDuesCollection.doc(docId), rentDue.toMap());
    }

    await batch.commit();
  }

  /// Delete rent due
  Future<void> deleteRentDue(String docId) async {
    await _rentDuesCollection.doc(docId).delete();
  }

  /// Get rent statistics for a residence
  Future<Map<String, dynamic>> getRentStats(
    String residenceName, {
    String? month,
  }) async {
    final rentMonth = month ?? getCurrentMonth();

    final snapshot = await _rentDuesCollection
        .where('residenceName', isEqualTo: residenceName)
        .where('month', isEqualTo: rentMonth)
        .get();

    double totalDue = 0;
    double totalPaid = 0;
    int paidCount = 0;
    int pendingCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      final isPaid = data['isPaid'] ?? false;

      totalDue += amount;
      if (isPaid) {
        totalPaid += amount;
        paidCount++;
      } else {
        pendingCount++;
      }
    }

    return {
      'totalDue': totalDue,
      'totalPaid': totalPaid,
      'totalPending': totalDue - totalPaid,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
      'totalStudents': snapshot.docs.length,
    };
  }

  /// Stream rent statistics for a residence (real-time updates)
  Stream<Map<String, dynamic>> streamRentStats(
    String residenceName, {
    String? month,
  }) {
    final rentMonth = month ?? getCurrentMonth();

    return _rentDuesCollection
        .where('residenceName', isEqualTo: residenceName)
        .where('month', isEqualTo: rentMonth)
        .snapshots()
        .map((snapshot) {
          double totalDue = 0;
          double totalPaid = 0;
          int paidCount = 0;
          int pendingCount = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0).toDouble();
            final isPaid = data['isPaid'] ?? false;

            totalDue += amount;
            if (isPaid) {
              totalPaid += amount;
              paidCount++;
            } else {
              pendingCount++;
            }
          }

          return {
            'totalDue': totalDue,
            'totalPaid': totalPaid,
            'totalPending': totalDue - totalPaid,
            'paidCount': paidCount,
            'pendingCount': pendingCount,
            'totalStudents': snapshot.docs.length,
          };
        });
  }
}
