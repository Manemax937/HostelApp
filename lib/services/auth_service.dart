import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/services/notification_service.dart';
import 'package:hostelapp/utils/app_constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if email is verified (for students)
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

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
  }) async {
    try {
      // Create auth user first
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      // Students are active immediately, just need email verification
      final userModel = UserModel(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: UserRole.student,
        roomNo: roomNo,
        floor: floor,
        createdAt: DateTime.now(),
        isActive: true, // Active immediately
        residenceName: AppConstants.hostelName,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(userModel.toMap());

      // Send email verification link
      await credential.user!.sendEmailVerification();

      // Sign out - user needs to verify email first
      await _auth.signOut();

      // Throw message to inform about email verification
      throw 'Registration successful! Please check your email and click the verification link to sign in.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Register a new housekeeper
  Future<UserCredential> registerHousekeeper({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create auth user first
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create housekeeper document in Firestore
      final userModel = UserModel(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: UserRole.housekeeping,
        createdAt: DateTime.now(),
        isActive: true, // Housekeepers active immediately
        residenceName: AppConstants.hostelName,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(userModel.toMap());

      // Send email verification link
      await credential.user!.sendEmailVerification();

      // Sign out - user needs to verify email first
      await _auth.signOut();

      // Throw message to inform about email verification
      throw 'Registration successful! Please check your email and click the verification link to sign in.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register owner with pending status - admin approves by setting isActive to true in Firebase Console
  Future<void> submitOwnerRequest({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create the Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create owner document with isActive: false (pending approval)
      final userModel = UserModel(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: UserRole.owner,
        residenceName: AppConstants.hostelName,
        createdAt: DateTime.now(),
        isActive: false, // Pending admin approval - toggle to true in Firebase Console
        isVerified: true, // No email verification needed for owners
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(userModel.toMap());

      // Sign out - owner can't use app until admin approves
      await _auth.signOut();

      debugPrint('Owner registered with pending status: $email');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Error registering owner: $e');
      rethrow;
    }
  }

  Future<UserCredential> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create owner document in Firestore
      // Note: Cloud Function will generate verification code and send email
      final userModel = UserModel(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: UserRole.owner,
        residenceName: AppConstants.hostelName,
        createdAt: DateTime.now(),
        isActive: false,
        isVerified: false,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(credential.user!.uid)
          .set(userModel.toMap());

      // Don't sign out - keep owner signed in to verify immediately
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

    // Check code expiration (24 hours)
    final codeExpiresAt = doc.data()?['verificationCodeExpiresAt'];
    if (codeExpiresAt != null) {
      final expiryTime = (codeExpiresAt as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryTime)) {
        throw 'Verification code has expired. Please request a new one.';
      }
    }

    // Get the hashed code from database and compare
    final storedCodeHash = doc.data()?['verificationCodeHash'] as String?;
    if (storedCodeHash == null) {
      throw 'No verification code found. Please register again.';
    }

    // Hash the input code and compare
    final inputCodeHash = _hashCode(code);
    if (storedCodeHash != inputCodeHash) {
      throw 'Invalid verification code';
    }

    // Clear the verification code after successful verification
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .update({
          'isVerified': true,
          'isActive': true,
          'verificationCodeHash': FieldValue.delete(),
          'verificationCodeExpiresAt': FieldValue.delete(),
        });

    await _loadUserData(currentUser!.uid);
  }

  /// Hash verification code using SHA256
  String _hashCode(String code) {
    final bytes = utf8.encode(code);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

        // For students, check email verification
        if (user.role == UserRole.student && !credential.user!.emailVerified) {
          await _auth.signOut();
          throw 'Please verify your email first. Check your inbox for a verification link.';
        }

        if (!user.isActive) {
          await _auth.signOut();
          throw 'Your account is pending admin approval.';
        }

        // Refresh FCM token after successful login
        await NotificationService().refreshFcmToken();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google - returns credential and whether user is new
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      // First, try to sign out from any existing Google session to allow account selection
      // Wrapped in try-catch as it may fail if no session exists
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign out skipped (no existing session): $e');
        // Continue with sign-in even if sign-out fails
      }

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Google sign-in was cancelled';
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication;
      } catch (e) {
        debugPrint('Google auth error: $e');
        throw 'Failed to authenticate with Google. Please try again.';
      }

      // Verify we have the required tokens
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw 'Failed to get authentication tokens from Google.';
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if user already exists in Firestore
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userCredential.user!.uid)
          .get();

      if (doc.exists) {
        // Existing user - load their data and return
        final user = UserModel.fromMap(doc.data()!, doc.id);

        if (!user.isActive) {
          await _googleSignIn.signOut();
          await _auth.signOut();
          throw 'Your account is pending admin approval.';
        }

        // Refresh FCM token for existing user
        await NotificationService().refreshFcmToken();

        return GoogleSignInResult(
          credential: userCredential,
          isNewUser: false,
          userRole: user.role,
        );
      }

      // New user - they need to complete registration
      return GoogleSignInResult(
        credential: userCredential,
        isNewUser: true,
        userRole: null,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      await _googleSignIn.signOut();
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (e is String) rethrow;
      // Check for common error patterns
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('network') ||
          errorMessage.contains('internet')) {
        throw 'Network error. Please check your internet connection.';
      }
      if (errorMessage.contains('cancel')) {
        throw 'Google sign-in was cancelled';
      }
      if (errorMessage.contains('api') ||
          errorMessage.contains('configuration')) {
        throw 'Google Sign-In is not properly configured. Please contact support.';
      }
      throw 'Google sign-in failed: ${e.toString()}';
    }
  }

  /// Sign out from Google (for cancelling registration flow)
  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Complete Google registration for owner (pending admin approval)
  Future<void> completeGoogleOwnerRegistration({
    required String fullName,
  }) async {
    if (currentUser == null) throw 'Please sign in first';

    // Create owner document with pending status (isActive: false)
    // Admin approves by setting isActive to true in Firebase Console
    final userModel = UserModel(
      uid: currentUser!.uid,
      fullName: fullName,
      email: currentUser!.email ?? '',
      role: UserRole.owner,
      residenceName: AppConstants.hostelName,
      createdAt: DateTime.now(),
      isActive: false, // Pending admin approval - toggle to true in Firebase Console
      isVerified: true, // No email verification needed for Google accounts
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .set(userModel.toMap());

    await _loadUserData(currentUser!.uid);
  }

  /// Complete Google registration for student
  Future<void> completeGoogleStudentRegistration({
    required String fullName,
    required String roomNo,
    required int floor,
  }) async {
    if (currentUser == null) throw 'Please sign in first';

    // Create student document in Firestore
    // Google accounts are already verified, so students are active immediately
    final userModel = UserModel(
      uid: currentUser!.uid,
      fullName: fullName,
      email: currentUser!.email ?? '',
      role: UserRole.student,
      roomNo: roomNo,
      floor: floor,
      createdAt: DateTime.now(),
      isActive: true, // Active immediately for Google sign-in
      residenceName: AppConstants.hostelName,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .set(userModel.toMap());

    await _loadUserData(currentUser!.uid);
  }

  /// Complete Google registration for housekeeper/staff
  Future<void> completeGoogleHousekeeperRegistration({
    required String fullName,
  }) async {
    if (currentUser == null) throw 'Please sign in first';

    // Create housekeeper document in Firestore
    // Google accounts are already verified, so staff are active immediately
    final userModel = UserModel(
      uid: currentUser!.uid,
      fullName: fullName,
      email: currentUser!.email ?? '',
      role: UserRole.housekeeping,
      createdAt: DateTime.now(),
      isActive: true, // Active immediately for Google sign-in
      residenceName: AppConstants.hostelName,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .set(userModel.toMap());

    await _loadUserData(currentUser!.uid);
  }

  /// Send email verification link
  Future<void> sendEmailVerification() async {
    if (currentUser == null) throw 'No user signed in';
    await currentUser!.sendEmailVerification();
  }

  /// Reload user to check email verification status
  Future<bool> checkEmailVerification() async {
    if (currentUser == null) return false;
    await currentUser!.reload();
    return _auth.currentUser?.emailVerified ?? false;
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

  // Get pending owner requests
  Stream<List<Map<String, dynamic>>> getPendingOwnerRequests() {
    return _firestore
        .collection('owner_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Approve owner request
  Future<void> approveOwnerRequest(String requestId) async {
    final doc = await _firestore.collection('owner_requests').doc(requestId).get();
    if (!doc.exists) throw 'Request not found';

    final data = doc.data()!;
    
    // Update request status
    await _firestore.collection('owner_requests').doc(requestId).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': currentUser?.uid,
    });

    // Create the user document (they'll need to create auth account by signing in)
    // We store the approved email so when they register, we can auto-approve
    await _firestore.collection('approved_owners').doc(data['email']).set({
      'email': data['email'],
      'fullName': data['fullName'],
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': currentUser?.uid,
    });

    debugPrint('Owner request approved for: ${data['email']}');
  }

  // Reject owner request
  Future<void> rejectOwnerRequest(String requestId) async {
    await _firestore.collection('owner_requests').doc(requestId).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': currentUser?.uid,
    });
  }

  // Check if email is pre-approved as owner
  Future<bool> isApprovedOwner(String email) async {
    final doc = await _firestore.collection('approved_owners').doc(email).get();
    return doc.exists;
  }
}

/// Result from Google Sign-In
class GoogleSignInResult {
  final UserCredential credential;
  final bool isNewUser;
  final UserRole? userRole;

  GoogleSignInResult({
    required this.credential,
    required this.isNewUser,
    this.userRole,
  });
}
