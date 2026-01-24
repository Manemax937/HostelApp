import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/complaint_model.dart';
import 'package:hostelapp/utils/app_constants.dart';
import 'dart:io';

class ComplaintService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> submitComplaint({
    required String userId,
    required String userName,
    required String roomNo,
    required ComplaintCategory category,
    required String description,
    File? photo,
  }) async {
    try {
      String? photoUrl;

      // Upload photo if provided
      if (photo != null) {
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage
            .ref()
            .child(AppConstants.complaintPhotosPath)
            .child(fileName);
        await ref.putFile(photo);
        photoUrl = await ref.getDownloadURL();
      }

      final complaint = ComplaintModel(
        id: '',
        userId: userId,
        userName: userName,
        roomNo: roomNo,
        category: category,
        description: description,
        photoUrl: photoUrl,
        status: ComplaintStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.complaintsCollection)
          .add(complaint.toMap());

      notifyListeners();
    } catch (e) {
      throw 'Failed to submit complaint: $e';
    }
  }

  Future<void> updateComplaintStatus({
    required String complaintId,
    required ComplaintStatus status,
    String? adminNote,
  }) async {
    await _firestore
        .collection(AppConstants.complaintsCollection)
        .doc(complaintId)
        .update({
          'status': status.toString().split('.').last,
          'updatedAt': Timestamp.now(),
          'adminNote': adminNote,
        });

    notifyListeners();
  }

  Stream<List<ComplaintModel>> getUserComplaints(String userId) {
    return _firestore
        .collection(AppConstants.complaintsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<ComplaintModel>> getAllComplaints() {
    return _firestore
        .collection(AppConstants.complaintsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<ComplaintModel>> getComplaintsByStatus(ComplaintStatus status) {
    return _firestore
        .collection(AppConstants.complaintsCollection)
        .where('status', isEqualTo: status.toString().split('.').last)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> deleteComplaint(String complaintId) async {
    await _firestore
        .collection(AppConstants.complaintsCollection)
        .doc(complaintId)
        .delete();

    notifyListeners();
  }
}
