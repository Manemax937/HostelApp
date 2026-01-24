import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/mess_attendance_model.dart';

class MessAttendanceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'mess_attendance';

  /// Get or create attendance record for a user for tomorrow
  Future<MessAttendance> getOrCreateTomorrowAttendance({
    required String userId,
    required String userName,
    required String roomNo,
    required String residenceName,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateKey = MessAttendance.getDateKey(tomorrow);
    final docId = '${userId}_$dateKey';

    final doc = await _firestore.collection(_collection).doc(docId).get();

    if (doc.exists) {
      return MessAttendance.fromMap(doc.data()!, doc.id);
    }

    // Create new attendance record with all meals marked as attending (default)
    final attendance = MessAttendance(
      id: docId,
      userId: userId,
      userName: userName,
      roomNo: roomNo,
      residenceName: residenceName,
      date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      breakfast: true,
      lunch: true,
      dinner: true,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection(_collection).doc(docId).set(attendance.toMap());
    return attendance;
  }

  /// Update meal attendance for tomorrow
  Future<void> updateMealAttendance({
    required String userId,
    required String userName,
    required String roomNo,
    required String residenceName,
    required MealType mealType,
    required bool isAttending,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateKey = MessAttendance.getDateKey(tomorrow);
    final docId = '${userId}_$dateKey';

    final doc = await _firestore.collection(_collection).doc(docId).get();

    if (doc.exists) {
      // Update existing record
      await _firestore.collection(_collection).doc(docId).update({
        mealType.name: isAttending,
        'updatedAt': Timestamp.now(),
      });
    } else {
      // Create new record with this meal's attendance
      final attendance = MessAttendance(
        id: docId,
        userId: userId,
        userName: userName,
        roomNo: roomNo,
        residenceName: residenceName,
        date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        breakfast: mealType == MealType.breakfast ? isAttending : true,
        lunch: mealType == MealType.lunch ? isAttending : true,
        dinner: mealType == MealType.dinner ? isAttending : true,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collection)
          .doc(docId)
          .set(attendance.toMap());
    }

    notifyListeners();
  }

  /// Stream user's tomorrow attendance
  Stream<MessAttendance?> getUserTomorrowAttendance(String userId) {
    final dateKey = MessAttendance.getTomorrowKey();
    final docId = '${userId}_$dateKey';

    return _firestore.collection(_collection).doc(docId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MessAttendance.fromMap(doc.data()!, doc.id);
    });
  }

  /// Stream all students' attendance for tomorrow (for owner view)
  Stream<List<MessAttendance>> getTomorrowAttendanceByResidence(
    String residenceName,
  ) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startOfDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collection)
        .where('residenceName', isEqualTo: residenceName)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessAttendance.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get attendance for a specific date (for owner view)
  Stream<List<MessAttendance>> getAttendanceByDate(
    String residenceName,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collection)
        .where('residenceName', isEqualTo: residenceName)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessAttendance.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get meal counts for tomorrow (for owner dashboard stats)
  Future<Map<String, int>> getTomorrowMealCounts(String residenceName) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startOfDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('residenceName', isEqualTo: residenceName)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    int breakfastCount = 0;
    int lunchCount = 0;
    int dinnerCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['breakfast'] == true) breakfastCount++;
      if (data['lunch'] == true) lunchCount++;
      if (data['dinner'] == true) dinnerCount++;
    }

    return {
      'breakfast': breakfastCount,
      'lunch': lunchCount,
      'dinner': dinnerCount,
      'total': snapshot.docs.length,
    };
  }
}
