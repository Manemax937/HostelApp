import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, student, housekeeping, owner }

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final String? roomNo;
  final int? floor;
  final DateTime createdAt;
  final bool isActive;
  final String? residenceName;
  final String? verificationCode;
  final bool? isVerified;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.roomNo,
    this.floor,
    required this.createdAt,
    this.isActive = true,
    this.residenceName,
    this.verificationCode,
    this.isVerified,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${map['role']}',
        orElse: () => UserRole.student,
      ),
      roomNo: map['roomNo'],
      floor: map['floor'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      residenceName: map['residenceName'],
      verificationCode: map['verificationCode'],
      isVerified: map['isVerified'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'roomNo': roomNo,
      'floor': floor,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'residenceName': residenceName,
      'verificationCode': verificationCode,
      'isVerified': isVerified,
    };
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? roomNo,
    int? floor,
    DateTime? createdAt,
    bool? isActive,
    String? residenceName,
    String? verificationCode,
    bool? isVerified,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roomNo: roomNo ?? this.roomNo,
      floor: floor ?? this.floor,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      residenceName: residenceName ?? this.residenceName,
      verificationCode: verificationCode ?? this.verificationCode,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
