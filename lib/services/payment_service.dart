import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/payment_model.dart';
import 'package:hostelapp/utils/app_constants.dart';
import 'dart:io';

class PaymentService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> submitPayment({
    required String userId,
    required String userName,
    required String roomNo,
    required double amount,
    required String transactionId,
    required String month,
    File? screenshot,
  }) async {
    try {
      String? screenshotUrl;

      // Upload screenshot if provided
      if (screenshot != null) {
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage
            .ref()
            .child(AppConstants.paymentScreenshotsPath)
            .child(fileName);
        await ref.putFile(screenshot);
        screenshotUrl = await ref.getDownloadURL();
      }

      // Create payment document
      final payment = PaymentModel(
        id: '',
        userId: userId,
        userName: userName,
        roomNo: roomNo,
        amount: amount,
        transactionId: transactionId,
        screenshotUrl: screenshotUrl,
        status: PaymentStatus.pending,
        submittedAt: DateTime.now(),
        month: month,
      );

      await _firestore
          .collection(AppConstants.paymentsCollection)
          .add(payment.toMap());

      notifyListeners();
    } catch (e) {
      throw 'Failed to submit payment: $e';
    }
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    String? adminNote,
  }) async {
    await _firestore
        .collection(AppConstants.paymentsCollection)
        .doc(paymentId)
        .update({
          'status': status.toString().split('.').last,
          'verifiedAt': status == PaymentStatus.verified
              ? Timestamp.now()
              : null,
          'adminNote': adminNote,
        });

    notifyListeners();
  }

  Stream<List<PaymentModel>> getUserPayments(String userId) {
    return _firestore
        .collection(AppConstants.paymentsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<PaymentModel>> getAllPayments() {
    return _firestore
        .collection(AppConstants.paymentsCollection)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<PaymentModel>> getPendingPayments() {
    return _firestore
        .collection(AppConstants.paymentsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<PaymentModel?> getPaymentForMonth(String userId, String month) async {
    final snapshot = await _firestore
        .collection(AppConstants.paymentsCollection)
        .where('userId', isEqualTo: userId)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return PaymentModel.fromMap(
      snapshot.docs.first.data(),
      snapshot.docs.first.id,
    );
  }
}
