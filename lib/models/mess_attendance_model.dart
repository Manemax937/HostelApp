import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { breakfast, lunch, dinner }

class MessAttendance {
  final String id;
  final String userId;
  final String userName;
  final String roomNo;
  final String residenceName;
  final DateTime date; // Date for which attendance is marked
  final bool breakfast;
  final bool lunch;
  final bool dinner;
  final DateTime updatedAt;

  MessAttendance({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNo,
    required this.residenceName,
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.updatedAt,
  });

  factory MessAttendance.fromMap(Map<String, dynamic> map, String id) {
    return MessAttendance(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNo: map['roomNo'] ?? '',
      residenceName: map['residenceName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      breakfast: map['breakfast'] ?? false,
      lunch: map['lunch'] ?? false,
      dinner: map['dinner'] ?? false,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNo': roomNo,
      'residenceName': residenceName,
      'date': Timestamp.fromDate(date),
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MessAttendance copyWith({
    String? id,
    String? userId,
    String? userName,
    String? roomNo,
    String? residenceName,
    DateTime? date,
    bool? breakfast,
    bool? lunch,
    bool? dinner,
    DateTime? updatedAt,
  }) {
    return MessAttendance(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      roomNo: roomNo ?? this.roomNo,
      residenceName: residenceName ?? this.residenceName,
      date: date ?? this.date,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the date string in format YYYY-MM-DD for document ID
  static String getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get tomorrow's date key
  static String getTomorrowKey() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return getDateKey(tomorrow);
  }
}
