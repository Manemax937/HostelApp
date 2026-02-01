import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FloorConfigService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _configCollection = 'app_config';
  static const String _floorsDocId = 'floors';

  /// Get the list of available floors as a stream
  Stream<List<int>> getFloorsStream() {
    return _firestore
        .collection(_configCollection)
        .doc(_floorsDocId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            // Return default floors if not configured
            return [1, 2, 3, 4, 5];
          }
          final data = snapshot.data()!;
          final floors = List<int>.from(data['floors'] ?? [1, 2, 3, 4, 5]);
          floors.sort();
          return floors;
        });
  }

  /// Get floors once (not stream)
  Future<List<int>> getFloors() async {
    final snapshot = await _firestore
        .collection(_configCollection)
        .doc(_floorsDocId)
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      // Initialize with default floors
      await _initializeDefaultFloors();
      return [1, 2, 3, 4, 5];
    }

    final data = snapshot.data()!;
    final floors = List<int>.from(data['floors'] ?? [1, 2, 3, 4, 5]);
    floors.sort();
    return floors;
  }

  /// Initialize default floors
  Future<void> _initializeDefaultFloors() async {
    await _firestore.collection(_configCollection).doc(_floorsDocId).set({
      'floors': [1, 2, 3, 4, 5],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a new floor
  Future<void> addFloor(int floor) async {
    final currentFloors = await getFloors();

    if (currentFloors.contains(floor)) {
      throw 'Floor $floor already exists';
    }

    if (floor < 0 || floor > 50) {
      throw 'Floor number must be between 0 and 50';
    }

    currentFloors.add(floor);
    currentFloors.sort();

    await _firestore.collection(_configCollection).doc(_floorsDocId).set({
      'floors': currentFloors,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    notifyListeners();
  }

  /// Remove a floor
  Future<void> removeFloor(int floor) async {
    final currentFloors = await getFloors();

    if (!currentFloors.contains(floor)) {
      throw 'Floor $floor does not exist';
    }

    if (currentFloors.length <= 1) {
      throw 'Cannot remove the last floor';
    }

    currentFloors.remove(floor);

    await _firestore.collection(_configCollection).doc(_floorsDocId).set({
      'floors': currentFloors,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    notifyListeners();
  }

  /// Set all floors at once
  Future<void> setFloors(List<int> floors) async {
    if (floors.isEmpty) {
      throw 'At least one floor is required';
    }

    final uniqueFloors = floors.toSet().toList();
    uniqueFloors.sort();

    await _firestore.collection(_configCollection).doc(_floorsDocId).set({
      'floors': uniqueFloors,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    notifyListeners();
  }
}
