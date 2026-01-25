import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/complaint_model.dart';
import 'package:hostelapp/services/notification_service.dart';
import 'package:hostelapp/utils/app_constants.dart';
import 'dart:io';

class ComplaintService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> submitComplaint({
    required String userId,
    required String userName,
    required String roomNo,
    required String residenceName,
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
        residenceName: residenceName,
        category: category,
        description: description,
        photoUrl: photoUrl,
        status: ComplaintStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.complaintsCollection)
          .add(complaint.toMap());

      // Send notifications
      final notificationService = NotificationService();

      // Notify student that complaint is submitted
      await notificationService.sendComplaintSubmittedNotification(
        userId: userId,
        category: complaint.categoryName,
      );

      // Notify owner about new complaint
      await notificationService.sendNewComplaintNotification(
        studentName: userName,
        category: complaint.categoryName,
        residenceName: residenceName,
      );

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
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort locally to avoid needing composite index
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Filter out resolved complaints older than 24 hours
          return _filterOldResolvedComplaints(list);
        });
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

  /// Get complaints by residence name (for owner)
  Stream<List<ComplaintModel>> getComplaintsByResidence(String residenceName) {
    // If residenceName is empty, return empty list
    if (residenceName.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.complaintsCollection)
        .where('residenceName', isEqualTo: residenceName)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort locally to avoid needing composite index
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // Filter out resolved complaints older than 24 hours
          return _filterOldResolvedComplaints(list);
        });
  }

  /// Filter out resolved complaints older than 24 hours
  List<ComplaintModel> _filterOldResolvedComplaints(
    List<ComplaintModel> complaints,
  ) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));

    return complaints.where((complaint) {
      // Keep all non-resolved complaints
      if (complaint.status != ComplaintStatus.resolved) {
        return true;
      }
      // For resolved complaints, check if resolved within last 24 hours
      final resolvedAt = complaint.updatedAt ?? complaint.createdAt;
      return resolvedAt.isAfter(cutoff);
    }).toList();
  }

  /// Clean up old resolved complaints from Firestore (run periodically)
  Future<void> cleanupOldResolvedComplaints() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      final snapshot = await _firestore
          .collection(AppConstants.complaintsCollection)
          .where('status', isEqualTo: 'resolved')
          .get();

      final batch = _firestore.batch();
      int deleteCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final updatedAt = data['updatedAt'] as Timestamp?;
        final createdAt = data['createdAt'] as Timestamp?;
        final resolvedTime = updatedAt?.toDate() ?? createdAt?.toDate();

        if (resolvedTime != null && resolvedTime.isBefore(cutoff)) {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }

      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('Cleaned up $deleteCount old resolved complaints');
      }
    } catch (e) {
      debugPrint('Error cleaning up old complaints: $e');
    }
  }

  /// Mark complaint as resolved
  Future<void> resolveComplaint(String complaintId, {String? adminNote}) async {
    // Get complaint details first for notification
    final doc = await _firestore
        .collection(AppConstants.complaintsCollection)
        .doc(complaintId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final userId = data['userId'] as String;
      final category = data['category'] as String;

      await _firestore
          .collection(AppConstants.complaintsCollection)
          .doc(complaintId)
          .update({
            'status': 'resolved',
            'updatedAt': Timestamp.now(),
            'adminNote': adminNote,
          });

      // Send notification to student
      await NotificationService().sendComplaintResolvedNotification(
        userId: userId,
        category: category,
      );
    }

    notifyListeners();
  }

  Future<void> deleteComplaint(String complaintId) async {
    await _firestore
        .collection(AppConstants.complaintsCollection)
        .doc(complaintId)
        .delete();

    notifyListeners();
  }
}
