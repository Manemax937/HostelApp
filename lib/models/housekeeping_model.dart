import 'package:cloud_firestore/cloud_firestore.dart';

class HousekeepingLog {
  final String id;
  final String staffId;
  final String staffName;
  final int floor;
  final DateTime checkInTime;
  final DateTime? checkOutTime;

  HousekeepingLog({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.floor,
    required this.checkInTime,
    this.checkOutTime,
  });

  factory HousekeepingLog.fromMap(Map<String, dynamic> map, String id) {
    return HousekeepingLog(
      id: id,
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      floor: map['floor'] ?? 0,
      checkInTime: (map['checkInTime'] as Timestamp).toDate(),
      checkOutTime: map['checkOutTime'] != null
          ? (map['checkOutTime'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'floor': floor,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'checkOutTime': checkOutTime != null
          ? Timestamp.fromDate(checkOutTime!)
          : null,
    };
  }

  Duration? get duration {
    if (checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime);
  }

  HousekeepingLog copyWith({
    String? id,
    String? staffId,
    String? staffName,
    int? floor,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) {
    return HousekeepingLog(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      floor: floor ?? this.floor,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
    );
  }
}
