import 'package:cloud_firestore/cloud_firestore.dart';

enum MachineStatus { free, busy }

class WashingMachineSession {
  final String id;
  final String machineId;
  final String userId;
  final String userName;
  final String roomNo;
  final int clothesCount;
  final DateTime startTime;
  final DateTime? endTime;
  final MachineStatus status;

  WashingMachineSession({
    required this.id,
    required this.machineId,
    required this.userId,
    required this.userName,
    required this.roomNo,
    required this.clothesCount,
    required this.startTime,
    this.endTime,
    required this.status,
  });

  factory WashingMachineSession.fromMap(Map<String, dynamic> map, String id) {
    return WashingMachineSession(
      id: id,
      machineId: map['machineId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNo: map['roomNo'] ?? '',
      clothesCount: map['clothesCount'] ?? 0,
      startTime: map['startTime'] != null
          ? (map['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      status: MachineStatus.values.firstWhere(
        (e) => e.toString() == 'MachineStatus.${map['status']}',
        orElse: () => MachineStatus.free,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'machineId': machineId,
      'userId': userId,
      'userName': userName,
      'roomNo': roomNo,
      'clothesCount': clothesCount,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.toString().split('.').last,
    };
  }

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  WashingMachineSession copyWith({
    String? id,
    String? machineId,
    String? userId,
    String? userName,
    String? roomNo,
    int? clothesCount,
    DateTime? startTime,
    DateTime? endTime,
    MachineStatus? status,
  }) {
    return WashingMachineSession(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      roomNo: roomNo ?? this.roomNo,
      clothesCount: clothesCount ?? this.clothesCount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }
}
