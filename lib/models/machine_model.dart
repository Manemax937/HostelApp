import 'package:cloud_firestore/cloud_firestore.dart';

enum MachineStatus { available, busy, maintenance }

class Machine {
  final String id;
  final String name;
  final String residenceName;
  final MachineStatus status;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentRoomNo;
  final DateTime? sessionStartTime;
  final int? clothesCount;
  final DateTime createdAt;

  Machine({
    required this.id,
    required this.name,
    required this.residenceName,
    required this.status,
    this.currentUserId,
    this.currentUserName,
    this.currentRoomNo,
    this.sessionStartTime,
    this.clothesCount,
    required this.createdAt,
  });

  factory Machine.fromMap(Map<String, dynamic> map, String id) {
    return Machine(
      id: id,
      name: map['name'] ?? '',
      residenceName: map['residenceName'] ?? '',
      status: MachineStatus.values.firstWhere(
        (e) => e.toString() == 'MachineStatus.${map['status']}',
        orElse: () => MachineStatus.available,
      ),
      currentUserId: map['currentUserId'],
      currentUserName: map['currentUserName'],
      currentRoomNo: map['currentRoomNo'],
      sessionStartTime: map['sessionStartTime'] != null
          ? (map['sessionStartTime'] as Timestamp).toDate()
          : null,
      clothesCount: map['clothesCount'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'residenceName': residenceName,
      'status': status.toString().split('.').last,
      'currentUserId': currentUserId,
      'currentUserName': currentUserName,
      'currentRoomNo': currentRoomNo,
      'sessionStartTime': sessionStartTime != null
          ? Timestamp.fromDate(sessionStartTime!)
          : null,
      'clothesCount': clothesCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Machine copyWith({
    String? id,
    String? name,
    String? residenceName,
    MachineStatus? status,
    String? currentUserId,
    String? currentUserName,
    String? currentRoomNo,
    DateTime? sessionStartTime,
    int? clothesCount,
    DateTime? createdAt,
  }) {
    return Machine(
      id: id ?? this.id,
      name: name ?? this.name,
      residenceName: residenceName ?? this.residenceName,
      status: status ?? this.status,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserName: currentUserName ?? this.currentUserName,
      currentRoomNo: currentRoomNo ?? this.currentRoomNo,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      clothesCount: clothesCount ?? this.clothesCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isBusy => status == MachineStatus.busy;
  bool get isAvailable => status == MachineStatus.available;
  bool get isUnderMaintenance => status == MachineStatus.maintenance;
}
