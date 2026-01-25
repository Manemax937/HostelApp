import 'package:cloud_firestore/cloud_firestore.dart';

class PgAttendance {
  final String id;
  final String userId;
  final String userName;
  final String roomNo;
  final String residenceName;
  final DateTime date;
  final DateTime markedAt;
  final double latitude;
  final double longitude;
  final bool isPresent;

  PgAttendance({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNo,
    required this.residenceName,
    required this.date,
    required this.markedAt,
    required this.latitude,
    required this.longitude,
    required this.isPresent,
  });

  factory PgAttendance.fromMap(Map<String, dynamic> map, String id) {
    return PgAttendance(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNo: map['roomNo'] ?? '',
      residenceName: map['residenceName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      markedAt: (map['markedAt'] as Timestamp).toDate(),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      isPresent: map['isPresent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNo': roomNo,
      'residenceName': residenceName,
      'date': Timestamp.fromDate(date),
      'markedAt': Timestamp.fromDate(markedAt),
      'latitude': latitude,
      'longitude': longitude,
      'isPresent': isPresent,
    };
  }

  /// Get date key for document ID (YYYY-MM-DD)
  static String getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String getTodayKey() {
    return getDateKey(DateTime.now());
  }
}

class PgLocation {
  final String id;
  final String residenceName;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final DateTime updatedAt;
  final int startHour; // 0-23 format (e.g., 22 for 10 PM)
  final int startMinute;
  final int endHour; // 0-23 format (e.g., 0 for 12 AM)
  final int endMinute;
  final bool isTimeWindowEnabled;

  PgLocation({
    required this.id,
    required this.residenceName,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 50,
    required this.updatedAt,
    this.startHour = 22, // Default: 10 PM
    this.startMinute = 0,
    this.endHour = 0, // Default: 12 AM (midnight)
    this.endMinute = 0,
    this.isTimeWindowEnabled = false,
  });

  factory PgLocation.fromMap(Map<String, dynamic> map, String id) {
    return PgLocation(
      id: id,
      residenceName: map['residenceName'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      radiusMeters: map['radiusMeters'] ?? 50,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      startHour: map['startHour'] ?? 22,
      startMinute: map['startMinute'] ?? 0,
      endHour: map['endHour'] ?? 0,
      endMinute: map['endMinute'] ?? 0,
      isTimeWindowEnabled: map['isTimeWindowEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'residenceName': residenceName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'isTimeWindowEnabled': isTimeWindowEnabled,
    };
  }

  /// Check if current time is within the attendance window
  bool isWithinTimeWindow() {
    if (!isTimeWindowEnabled) return true;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Handle overnight window (e.g., 10 PM to 12 AM)
    if (startMinutes > endMinutes) {
      // Window crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    } else {
      // Normal window (e.g., 8 AM to 10 AM)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
  }

  /// Get formatted time window string
  String getTimeWindowString() {
    if (!isTimeWindowEnabled) return 'Anytime';

    String formatTime(int hour, int minute) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }

    return '${formatTime(startHour, startMinute)} - ${formatTime(endHour, endMinute)}';
  }
}
