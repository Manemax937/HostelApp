import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hostelapp/models/user_model.dart';
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

      // Send email verification link
      await credential.user!.sendEmailVerification();

      // Sign out - user needs to verify email first
      await _auth.signOut();

      if (!isActive) {
        throw 'Residence "$residenceName" not found or not verified. Your account is created but needs admin approval.';
      }

      // Throw message to inform about email verification
      throw 'Registration successful! Please check your email and click the verification link before signing in.';
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

        // For students, check email verification
        if (user.role == UserRole.student && !credential.user!.emailVerified) {
          await _auth.signOut();
          throw 'Please verify your email first. Check your inbox for a verification link.';
        }

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

  /// Sign in with Google - returns credential and whether user is new
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      // First, sign out from any existing Google session to allow account selection
      await _googleSignIn.signOut();
      
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
      if (errorMessage.contains('network') || errorMessage.contains('internet')) {
        throw 'Network error. Please check your internet connection.';
      }
      if (errorMessage.contains('cancel')) {
        throw 'Google sign-in was cancelled';
      }
      if (errorMessage.contains('api') || errorMessage.contains('configuration')) {
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

  /// Complete Google registration for owner
  Future<void> completeGoogleOwnerRegistration({
    required String fullName,
    required String residenceName,
    required String verificationCode,
  }) async {
    if (currentUser == null) throw 'Please sign in first';

    // Create owner document in Firestore
    final userModel = UserModel(
      uid: currentUser!.uid,
      fullName: fullName,
      email: currentUser!.email ?? '',
      role: UserRole.owner,
      residenceName: residenceName,
      createdAt: DateTime.now(),
      isActive: false,
      verificationCode: verificationCode,
      isVerified: false,
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
    required String residenceName,
  }) async {
    if (currentUser == null) throw 'Please sign in first';

    // Check if residence exists
    final ownerQuery = await _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'owner')
        .where('residenceName', isEqualTo: residenceName)
        .where('isVerified', isEqualTo: true)
        .get();

    bool isActive = ownerQuery.docs.isNotEmpty;

    // Create student document in Firestore
    final userModel = UserModel(
      uid: currentUser!.uid,
      fullName: fullName,
      email: currentUser!.email ?? '',
      role: UserRole.student,
      roomNo: roomNo,
      floor: floor,
      createdAt: DateTime.now(),
      isActive: isActive,
      residenceName: residenceName,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .set(userModel.toMap());

    if (!isActive) {
      await _auth.signOut();
      throw 'Residence "$residenceName" not found or not verified. Your account is created but needs admin approval.';
    }

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
