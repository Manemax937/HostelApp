import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/housekeeping_model.dart';
import 'package:hostelapp/services/notification_service.dart';
import 'package:hostelapp/utils/app_constants.dart';

class HousekeepingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Future<void> checkIn({
    required String staffId,
    required String staffName,
    required int floor,
  }) async {
    // Check if there's an active session
    final activeSessions = await _firestore
        .collection(AppConstants.housekeepingCollection)
        .where('staffId', isEqualTo: staffId)
        .where('checkOutTime', isNull: true)
        .get();

    if (activeSessions.docs.isNotEmpty) {
      throw 'Please check out from the current floor first.';
    }

    final log = HousekeepingLog(
      id: '',
      staffId: staffId,
      staffName: staffName,
      floor: floor,
      checkInTime: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.housekeepingCollection)
        .add(log.toMap());

    // Send notification to all students on this floor
    await _notificationService.sendFloorCleaningNotification(
      floor: floor,
      staffName: staffName,
    );

    notifyListeners();
  }

  Future<void> checkOut(String logId) async {
    // Get the log to find the floor number
    final logDoc = await _firestore
        .collection(AppConstants.housekeepingCollection)
        .doc(logId)
        .get();
    
    if (logDoc.exists) {
      final logData = logDoc.data()!;
      final floor = logData['floor'] as int;
      final staffName = logData['staffName'] as String;
      
      await _firestore
          .collection(AppConstants.housekeepingCollection)
          .doc(logId)
          .update({'checkOutTime': Timestamp.now()});

      // Send completion notification
      await _notificationService.sendFloorCleaningCompletedNotification(
        floor: floor,
        staffName: staffName,
      );
    }

    notifyListeners();
  }

  Stream<HousekeepingLog?> getActiveSession(String staffId) {
    return _firestore
        .collection(AppConstants.housekeepingCollection)
        .where('staffId', isEqualTo: staffId)
        .where('checkOutTime', isNull: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return HousekeepingLog.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  Stream<List<HousekeepingLog>> getAllLogs() {
    return _firestore
        .collection(AppConstants.housekeepingCollection)
        .orderBy('checkInTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HousekeepingLog.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<HousekeepingLog>> getStaffLogs(String staffId) {
    return _firestore
        .collection(AppConstants.housekeepingCollection)
        .where('staffId', isEqualTo: staffId)
        .orderBy('checkInTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HousekeepingLog.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<HousekeepingLog>> getFloorLogs(int floor) {
    return _firestore
        .collection(AppConstants.housekeepingCollection)
        .where('floor', isEqualTo: floor)
        .orderBy('checkInTime', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HousekeepingLog.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
