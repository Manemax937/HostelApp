import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/washing_machine_model.dart';
import 'package:hostelapp/services/notification_service.dart';
import 'package:hostelapp/utils/app_constants.dart';

class WashingMachineService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> startSession({
    required String machineId,
    required String userId,
    required String userName,
    required String roomNo,
    required int clothesCount,
  }) async {
    // Check if machine is already in use
    final activeSessions = await _firestore
        .collection(AppConstants.washingMachinesCollection)
        .where('machineId', isEqualTo: machineId)
        .where('status', isEqualTo: 'busy')
        .get();

    if (activeSessions.docs.isNotEmpty) {
      throw 'This machine is already in use.';
    }

    final session = WashingMachineSession(
      id: '',
      machineId: machineId,
      userId: userId,
      userName: userName,
      roomNo: roomNo,
      clothesCount: clothesCount,
      startTime: DateTime.now(),
      status: MachineStatus.busy,
    );

    await _firestore
        .collection(AppConstants.washingMachinesCollection)
        .add(session.toMap());

    // Send notification for machine booking
    await NotificationService().sendMachineBookingNotification(
      machineName: 'Machine $machineId',
      slotTime: 'Now',
      userId: userId,
    );

    notifyListeners();
  }

  Future<void> endSession(String sessionId) async {
    // Get session details first
    final sessionDoc = await _firestore
        .collection(AppConstants.washingMachinesCollection)
        .doc(sessionId)
        .get();
    
    final sessionData = sessionDoc.data();
    
    await _firestore
        .collection(AppConstants.washingMachinesCollection)
        .doc(sessionId)
        .update({'endTime': Timestamp.now(), 'status': 'free'});

    // Send notification that machine is available
    if (sessionData != null) {
      await NotificationService().sendMachineAvailableNotification(
        machineName: 'Machine ${sessionData['machineId']}',
      );
    }

    notifyListeners();
  }

  Stream<WashingMachineSession?> getActiveSession(String machineId) {
    return _firestore
        .collection(AppConstants.washingMachinesCollection)
        .where('machineId', isEqualTo: machineId)
        .where('status', isEqualTo: 'busy')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return WashingMachineSession.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  Stream<List<WashingMachineSession>> getAllSessions() {
    return _firestore
        .collection(AppConstants.washingMachinesCollection)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WashingMachineSession.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<WashingMachineSession>> getUserSessions(String userId) {
    return _firestore
        .collection(AppConstants.washingMachinesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WashingMachineSession.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<Map<String, MachineStatus>> getMachinesStatus() async {
    final status = <String, MachineStatus>{};

    for (final machineId in AppConstants.machineIds) {
      final activeSessions = await _firestore
          .collection(AppConstants.washingMachinesCollection)
          .where('machineId', isEqualTo: machineId)
          .where('status', isEqualTo: 'busy')
          .get();

      status[machineId] = activeSessions.docs.isEmpty
          ? MachineStatus.free
          : MachineStatus.busy;
    }

    return status;
  }

  /// Stream all active (busy) sessions for real-time updates
  Stream<List<WashingMachineSession>> getActiveSessions() {
    return _firestore
        .collection(AppConstants.washingMachinesCollection)
        .where('status', isEqualTo: 'busy')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WashingMachineSession.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get total number of machines
  int getTotalMachines() {
    return AppConstants.machineIds.length;
  }
}
