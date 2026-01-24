import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/housekeeping_model.dart';
import 'package:hostelapp/utils/app_constants.dart';

class HousekeepingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    notifyListeners();
  }

  Future<void> checkOut(String logId) async {
    await _firestore
        .collection(AppConstants.housekeepingCollection)
        .doc(logId)
        .update({'checkOutTime': Timestamp.now()});

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
