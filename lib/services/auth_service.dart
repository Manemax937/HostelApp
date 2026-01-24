import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/utils/app_constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _currentUserModel = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        _currentUserModel = UserModel.fromMap(doc.data()!, uid);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String roomNo,
    required int floor,
    required String residenceName,
  }) async {
    try {
      // Create auth user first
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Now check if residence exists (authenticated user can read)
      final ownerQuery = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: 'owner')
          .where('residenceName', isEqualTo: residenceName)
          .where('isVerified', isEqualTo: true)
          .get();

      bool isActive = ownerQuery.docs.isNotEmpty;

      // Create user document in Firestore
      final userModel = UserModel(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: UserRole.student,
        roomNo: roomNo,
        floor: floor,
        createdAt: DateTime.now(),
        isActive: isActive, // Auto-approved if residence exists
        residenceName: residenceName,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(userModel.toMap());

      // Sign out immediately
      await _auth.signOut();

      if (!isActive) {
        throw 'Residence "$residenceName" not found or not verified. Your account is created but needs admin approval.';
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> registerOwner({
    required String email,
    required String password,
    required String fullName,
    required String residenceName,
  }) async {
    try {
      // Create auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Generate 6-digit verification code
      final verificationCode =
          (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

      // Create owner document in Firestore
      final userModel = UserModel(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: UserRole.owner,
        residenceName: residenceName,
        createdAt: DateTime.now(),
        isActive: false,
        verificationCode: verificationCode,
        isVerified: false,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(userModel.toMap());

      // Send verification email with code
      // Note: In production, use a cloud function to send custom email with the code
      // For now, the code is stored in Firestore and can be retrieved by admin/email service
      await credential.user!.sendEmailVerification();

      // Don't sign out - keep owner signed in to verify immediately
      // await _auth.signOut();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> verifyOwner(String code) async {
    if (currentUser == null) throw 'Please sign in first';

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .get();

    if (!doc.exists) throw 'User not found';

    final user = UserModel.fromMap(doc.data()!, doc.id);

    if (user.role != UserRole.owner) throw 'Only owners can verify';

    if (user.verificationCode != code) {
      throw 'Invalid verification code';
    }

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .update({'isVerified': true, 'isActive': true});

    await _loadUserData(currentUser!.uid);
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is active
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .get();

      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        if (!user.isActive) {
          await _auth.signOut();
          throw 'Your account is pending admin approval.';
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUserModel = null;
    notifyListeners();
  }

  Future<void> updateUserProfile({
    String? fullName,
    String? phone,
    String? roomNo,
    int? floor,
  }) async {
    if (currentUser == null) return;

    final updates = <String, dynamic>{};
    if (fullName != null) updates['fullName'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (roomNo != null) updates['roomNo'] = roomNo;
    if (floor != null) updates['floor'] = floor;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .update(updates);

    await _loadUserData(currentUser!.uid);
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  // Admin functions
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'isActive': isActive});
  }

  Future<void> deleteUser(String userId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .delete();
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role.toString().split('.').last)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
