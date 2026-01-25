import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hostelapp/models/pg_attendance_model.dart';
import 'package:hostelapp/services/notification_service.dart';

class PgAttendanceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _attendanceCollection = 'pg_attendance';
  static const String _locationCollection = 'pg_locations';

  /// Check if location services are enabled and permissions granted
  Future<LocationPermission> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Check if mock location is enabled (Android only)
  Future<bool> isMockLocation(Position position) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        return position.isMocked;
      }
    } catch (e) {
      debugPrint('Mock location check error: $e');
    }
    return false;
  }

  /// Get current location with validation - returns Position or error string
  Future<({Position? position, String? error})>
  getCurrentLocationWithError() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          position: null,
          error: 'Location services are disabled. Please enable GPS.',
        );
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Current permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('After request permission: $permission');
        if (permission == LocationPermission.denied) {
          return (
            position: null,
            error: 'Location permission denied. Please allow location access.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return (
          position: null,
          error:
              'Location permission permanently denied. Please enable in app settings.',
        );
      }

      debugPrint('Getting current position...');

      // Get current position with longer timeout
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Location request timed out. Please try again.',
            ),
          );

      debugPrint('Got location: ${position.latitude}, ${position.longitude}');
      return (position: position, error: null);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return (position: null, error: 'Error: ${e.toString()}');
    }
  }

  /// Get current location with validation (legacy method)
  Future<Position?> getCurrentLocation() async {
    final result = await getCurrentLocationWithError();
    return result.position;
  }

  /// Calculate distance between two points in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Set PG location (Owner only)
  Future<void> setPgLocation({
    required String residenceName,
    required double latitude,
    required double longitude,
    int radiusMeters = 50,
    int startHour = 22,
    int startMinute = 0,
    int endHour = 0,
    int endMinute = 0,
    bool isTimeWindowEnabled = false,
  }) async {
    final docId = residenceName.replaceAll(' ', '_').toLowerCase();

    final location = PgLocation(
      id: docId,
      residenceName: residenceName,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      updatedAt: DateTime.now(),
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      isTimeWindowEnabled: isTimeWindowEnabled,
    );

    await _firestore
        .collection(_locationCollection)
        .doc(docId)
        .set(location.toMap());
    notifyListeners();
  }

  /// Update time window only
  Future<void> updateTimeWindow({
    required String residenceName,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required bool isEnabled,
  }) async {
    final docId = residenceName.replaceAll(' ', '_').toLowerCase();

    await _firestore.collection(_locationCollection).doc(docId).update({
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'isTimeWindowEnabled': isEnabled,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    notifyListeners();
  }

  /// Get PG location
  Future<PgLocation?> getPgLocation(String residenceName) async {
    final docId = residenceName.replaceAll(' ', '_').toLowerCase();
    final doc = await _firestore
        .collection(_locationCollection)
        .doc(docId)
        .get();

    if (!doc.exists) return null;
    return PgLocation.fromMap(doc.data()!, doc.id);
  }

  /// Stream PG location
  Stream<PgLocation?> streamPgLocation(String residenceName) {
    final docId = residenceName.replaceAll(' ', '_').toLowerCase();
    return _firestore
        .collection(_locationCollection)
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return PgLocation.fromMap(doc.data()!, doc.id);
        });
  }

  /// Mark attendance with location validation
  Future<AttendanceResult> markAttendance({
    required String userId,
    required String userName,
    required String roomNo,
    required String residenceName,
  }) async {
    // 1. Get current location
    final position = await getCurrentLocation();
    if (position == null) {
      return AttendanceResult(
        success: false,
        message:
            'Unable to get your location. Please enable location services.',
      );
    }

    // 2. Check for mock location
    if (await isMockLocation(position)) {
      return AttendanceResult(
        success: false,
        message: 'Fake GPS detected. Please disable mock location apps.',
      );
    }

    // 3. Check location accuracy (reject if too vague)
    if (position.accuracy > 100) {
      return AttendanceResult(
        success: false,
        message: 'Location accuracy too low. Please try again in an open area.',
      );
    }

    // 4. Get PG location
    final pgLocation = await getPgLocation(residenceName);
    if (pgLocation == null) {
      return AttendanceResult(
        success: false,
        message: 'PG location not set. Please contact the owner.',
      );
    }

    // 5. Check time window
    if (!pgLocation.isWithinTimeWindow()) {
      return AttendanceResult(
        success: false,
        message:
            'Attendance can only be marked between ${pgLocation.getTimeWindowString()}.',
      );
    }

    // 6. Calculate distance
    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      pgLocation.latitude,
      pgLocation.longitude,
    );

    // 7. Check if within radius
    if (distance > pgLocation.radiusMeters) {
      return AttendanceResult(
        success: false,
        message:
            'You are ${distance.toInt()}m away from PG. Must be within ${pgLocation.radiusMeters}m.',
      );
    }

    // 8. Check if already marked today
    final today = DateTime.now();
    final dateKey = PgAttendance.getDateKey(today);
    final docId = '${userId}_$dateKey';

    final existingDoc = await _firestore
        .collection(_attendanceCollection)
        .doc(docId)
        .get();
    if (existingDoc.exists) {
      return AttendanceResult(
        success: false,
        message: 'Attendance already marked for today.',
      );
    }

    // 9. Mark attendance
    final attendance = PgAttendance(
      id: docId,
      userId: userId,
      userName: userName,
      roomNo: roomNo,
      residenceName: residenceName,
      date: DateTime(today.year, today.month, today.day),
      markedAt: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      isPresent: true,
    );

    await _firestore
        .collection(_attendanceCollection)
        .doc(docId)
        .set(attendance.toMap());

    // Send notification to user
    await NotificationService().sendAttendanceMarkedNotification(
      userName: userName,
      isPresent: true,
    );

    notifyListeners();

    return AttendanceResult(
      success: true,
      message: 'Attendance marked successfully!',
    );
  }

  /// Check if user has marked attendance today
  Future<bool> hasMarkedToday(String userId) async {
    final dateKey = PgAttendance.getTodayKey();
    final docId = '${userId}_$dateKey';
    final doc = await _firestore
        .collection(_attendanceCollection)
        .doc(docId)
        .get();
    return doc.exists;
  }

  /// Stream user's today attendance
  Stream<PgAttendance?> getUserTodayAttendance(String userId) {
    final dateKey = PgAttendance.getTodayKey();
    final docId = '${userId}_$dateKey';

    return _firestore
        .collection(_attendanceCollection)
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return PgAttendance.fromMap(doc.data()!, doc.id);
        });
  }

  /// Stream today's attendance for a residence (Owner view)
  Stream<List<PgAttendance>> getTodayAttendanceByResidence(
    String residenceName,
  ) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_attendanceCollection)
        .where('residenceName', isEqualTo: residenceName)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PgAttendance.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get today's attendance count
  Stream<int> getTodayAttendanceCount(String residenceName) {
    return getTodayAttendanceByResidence(
      residenceName,
    ).map((list) => list.length);
  }

  /// Get attendance for a specific date
  Stream<List<PgAttendance>> getAttendanceByDate(
    String residenceName,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_attendanceCollection)
        .where('residenceName', isEqualTo: residenceName)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PgAttendance.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}

class AttendanceResult {
  final bool success;
  final String message;

  AttendanceResult({required this.success, required this.message});
}
