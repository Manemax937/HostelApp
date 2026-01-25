import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/machine_model.dart';

class MachineService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'machines';

  /// Add a new machine (Owner only)
  Future<void> addMachine({
    required String name,
    required String residenceName,
  }) async {
    final machine = Machine(
      id: '',
      name: name,
      residenceName: residenceName,
      status: MachineStatus.available,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collection).add(machine.toMap());
    notifyListeners();
  }

  /// Update machine details (Owner only)
  Future<void> updateMachine({
    required String machineId,
    required String name,
    MachineStatus? status,
  }) async {
    final updates = <String, dynamic>{'name': name};
    if (status != null) {
      updates['status'] = status.toString().split('.').last;
      // If setting to available or maintenance, clear session data
      if (status != MachineStatus.busy) {
        updates['currentUserId'] = null;
        updates['currentUserName'] = null;
        updates['currentRoomNo'] = null;
        updates['sessionStartTime'] = null;
        updates['clothesCount'] = null;
      }
    }

    await _firestore.collection(_collection).doc(machineId).update(updates);
    notifyListeners();
  }

  /// Delete a machine (Owner only)
  Future<void> deleteMachine(String machineId) async {
    await _firestore.collection(_collection).doc(machineId).delete();
    notifyListeners();
  }

  /// Start a washing session (Student)
  Future<void> startSession({
    required String machineId,
    required String userId,
    required String userName,
    required String roomNo,
    required int clothesCount,
  }) async {
    // Check if machine is available
    final doc = await _firestore.collection(_collection).doc(machineId).get();
    if (!doc.exists) throw 'Machine not found';

    final machine = Machine.fromMap(doc.data()!, doc.id);
    if (machine.status != MachineStatus.available) {
      throw 'Machine is not available';
    }

    // Check if user already has an active session
    final userSessions = await _firestore
        .collection(_collection)
        .where('currentUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'busy')
        .get();

    if (userSessions.docs.isNotEmpty) {
      throw 'You already have an active washing session';
    }

    await _firestore.collection(_collection).doc(machineId).update({
      'status': 'busy',
      'currentUserId': userId,
      'currentUserName': userName,
      'currentRoomNo': roomNo,
      'clothesCount': clothesCount,
      'sessionStartTime': Timestamp.now(),
    });

    notifyListeners();
  }

  /// End a washing session (Student or Owner)
  Future<void> endSession(String machineId) async {
    await _firestore.collection(_collection).doc(machineId).update({
      'status': 'available',
      'currentUserId': null,
      'currentUserName': null,
      'currentRoomNo': null,
      'clothesCount': null,
      'sessionStartTime': null,
    });

    notifyListeners();
  }

  /// Stream all machines for a residence
  Stream<List<Machine>> getMachinesByResidence(String residenceName) {
    return _firestore
        .collection(_collection)
        .where('residenceName', isEqualTo: residenceName)
        .snapshots()
        .map((snapshot) {
          final machines = snapshot.docs
              .map((doc) => Machine.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by createdAt locally to avoid composite index requirement
          machines.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return machines;
        });
  }

  /// Stream a single machine
  Stream<Machine?> getMachine(String machineId) {
    return _firestore.collection(_collection).doc(machineId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return Machine.fromMap(doc.data()!, doc.id);
    });
  }

  /// Get machine count and status for a residence
  Stream<Map<String, int>> getMachineStats(String residenceName) {
    return _firestore
        .collection(_collection)
        .where('residenceName', isEqualTo: residenceName)
        .snapshots()
        .map((snapshot) {
          int total = snapshot.docs.length;
          int busy = 0;
          int available = 0;
          int maintenance = 0;

          for (final doc in snapshot.docs) {
            final status = doc.data()['status'] as String?;
            if (status == 'busy') {
              busy++;
            } else if (status == 'maintenance') {
              maintenance++;
            } else {
              available++;
            }
          }

          return {
            'total': total,
            'busy': busy,
            'available': available,
            'maintenance': maintenance,
          };
        });
  }

  /// Get user's active session if any
  Stream<Machine?> getUserActiveSession(String userId) {
    return _firestore
        .collection(_collection)
        .where('currentUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'busy')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return Machine.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }
}
