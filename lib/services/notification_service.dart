import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Background message handler - MUST be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.notification?.title}');
  // Background messages are automatically displayed by FCM on Android
  // For iOS, you might need additional setup
}

/// Notification types for the app
enum NotificationType {
  notice,
  attendance,
  machine,
  finance,
  support,
  verification,
  general,
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages - handler is registered in main.dart
    // FirebaseMessaging.onBackgroundMessage is set up there

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get and save FCM token
    await _saveUserFcmToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _saveUserFcmToken();
    });
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // You can navigate to specific screens based on message.data
  }

  /// Background message handler (must be top-level function)
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    debugPrint('Background message: ${message.notification?.title}');
  }

  /// Save FCM token to user's document for push notifications
  Future<void> _saveUserFcmToken() async {
    try {
      final token = await _messaging.getToken();
      final userId = _currentUserId;

      if (token != null && userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': Timestamp.now(),
        });
        debugPrint('FCM Token saved for user: $userId');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Subscribe user to residence topic for broadcast notifications
  Future<void> subscribeToResidence(String residenceName) async {
    final topic = residenceName.replaceAll(' ', '_').toLowerCase();
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Comfort PG',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'comfort_pg_channel',
      'Comfort PG Notifications',
      channelDescription: 'Notifications for Comfort PG residents',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // This would typically be done from a backend server
    // For demo purposes, we'll just show a local notification
    await _showLocalNotification(title: title, body: body);
  }

  // ============ NOTICE NOTIFICATIONS ============

  /// Send notification when a new notice is posted (for residents, not owner)
  Future<void> sendNoticeNotification({
    required String residenceName,
    required String noticeTitle,
    required String noticeContent,
  }) async {
    // DON'T show local notification to owner who posted it
    // Save to Firestore for residents to see in their notification list
    await _saveNotification(
      type: NotificationType.notice,
      title: '📢 New Notice',
      body: noticeTitle,
      residenceName: residenceName,
    );
  }

  // ============ ATTENDANCE NOTIFICATIONS ============

  /// Send notification for attendance reminder (self notification - OK to show)
  Future<void> sendAttendanceReminder({
    required String userId,
    required String userName,
  }) async {
    // This is a reminder for self, so show local notification
    await _showLocalNotification(
      title: '📍 Attendance Reminder',
      body: 'Don\'t forget to mark your attendance today!',
      payload: 'attendance',
    );
  }

  /// Send notification when attendance is marked (self confirmation)
  Future<void> sendAttendanceMarkedNotification({
    required String userName,
    required bool isPresent,
  }) async {
    // This is self-confirmation, show local notification
    await _showLocalNotification(
      title: '✅ Attendance Marked',
      body:
          'Your attendance has been marked as ${isPresent ? "Present" : "Absent"} for today.',
      payload: 'attendance',
    );
  }

  // ============ MACHINE NOTIFICATIONS ============

  /// Send notification when machine booking is confirmed (self confirmation)
  Future<void> sendMachineBookingNotification({
    required String machineName,
    required String slotTime,
    required String userId,
  }) async {
    // Self confirmation - show local
    await _showLocalNotification(
      title: '🧺 Booking Confirmed',
      body: '$machineName booked for $slotTime',
      payload: 'machine',
    );
  }

  /// Send notification when machine slot is about to start
  Future<void> sendMachineSlotReminderNotification({
    required String machineName,
    required int minutesBefore,
  }) async {
    await _showLocalNotification(
      title: '⏰ Slot Starting Soon',
      body: 'Your $machineName slot starts in $minutesBefore minutes',
      payload: 'machine',
    );
  }

  /// Send notification when machine is available
  Future<void> sendMachineAvailableNotification({
    required String machineName,
  }) async {
    await _showLocalNotification(
      title: '🧺 Machine Available',
      body: '$machineName is now available for booking',
      payload: 'machine',
    );
  }

  // ============ FINANCE NOTIFICATIONS ============

  /// Send notification when rent is due (called by owner, notifies student)
  Future<void> sendRentDueNotification({
    required String userId,
    required String userName,
    required double amount,
    required String month,
  }) async {
    // Don't show local notification - owner is sending this
    // Save to Firestore for the student to see
    await _saveNotification(
      type: NotificationType.finance,
      title: 'Rent Due',
      body: 'Your rent of ₹${amount.toStringAsFixed(0)} for $month is due',
      userId: userId,
    );
  }

  /// Send notification when payment is received (confirmation to student)
  Future<void> sendPaymentReceivedNotification({
    required String userId,
    required double amount,
    required String month,
  }) async {
    // Show local notification only if current user is the recipient
    if (_currentUserId == userId) {
      await _showLocalNotification(
        title: '✅ Payment Received',
        body:
            'Your payment of ₹${amount.toStringAsFixed(0)} for $month has been received',
        payload: 'finance',
      );
    }

    await _saveNotification(
      type: NotificationType.finance,
      title: 'Payment Received',
      body: 'Payment of ₹${amount.toStringAsFixed(0)} for $month received',
      userId: userId,
    );
  }

  /// Send notification when payment is verified by owner (notifies student)
  Future<void> sendPaymentVerifiedNotification({
    required String userId,
    required double amount,
  }) async {
    // Don't show local notification - owner is verifying
    // Save to Firestore for the student to see
    await _saveNotification(
      type: NotificationType.finance,
      title: 'Payment Verified',
      body: 'Your payment of ₹${amount.toStringAsFixed(0)} has been verified',
      userId: userId,
    );
  }

  /// Send notification to owner about pending payment verification (student submits)
  Future<void> sendPaymentPendingVerificationNotification({
    required String studentName,
    required double amount,
    required String residenceName,
  }) async {
    // Don't show local notification - student is submitting
    // Save to Firestore for owner to see
    await _saveNotification(
      type: NotificationType.finance,
      title: 'Payment Pending',
      body:
          '$studentName submitted ₹${amount.toStringAsFixed(0)} for verification',
      residenceName: residenceName,
    );
  }

  // ============ SUPPORT NOTIFICATIONS ============

  /// Send notification when complaint is submitted (confirmation to student)
  Future<void> sendComplaintSubmittedNotification({
    required String userId,
    required String category,
  }) async {
    // Show local notification as confirmation to the student who submitted
    if (_currentUserId == userId) {
      await _showLocalNotification(
        title: '📝 Complaint Submitted',
        body: 'Your $category complaint has been submitted',
        payload: 'support',
      );
    }
  }

  /// Send notification to owner about new complaint (student submits)
  Future<void> sendNewComplaintNotification({
    required String studentName,
    required String category,
    required String residenceName,
  }) async {
    // Don't show local notification - student is submitting
    // Save to Firestore for owner to see
    await _saveNotification(
      type: NotificationType.support,
      title: 'New Complaint',
      body: '$studentName raised a $category complaint',
      residenceName: residenceName,
    );
  }

  /// Send notification when complaint is resolved (notifies student)
  Future<void> sendComplaintResolvedNotification({
    required String userId,
    required String category,
  }) async {
    // Don't show local notification - owner is resolving
    // Save to Firestore for student to see
    await _saveNotification(
      type: NotificationType.support,
      title: 'Complaint Resolved',
      body: 'Your $category complaint has been resolved',
      userId: userId,
    );
  }

  // ============ VERIFICATION NOTIFICATIONS ============

  /// Send verification code notification
  Future<void> sendVerificationCodeNotification({required String code}) async {
    await _showLocalNotification(
      title: '🔐 Verification Code',
      body: 'Your verification code is: $code',
      payload: 'verification',
    );
  }

  /// Send email verification success notification
  Future<void> sendEmailVerifiedNotification() async {
    await _showLocalNotification(
      title: '✅ Email Verified',
      body: 'Your email has been verified successfully',
      payload: 'verification',
    );
  }

  // ============ GENERAL NOTIFICATIONS ============

  /// Send welcome notification to new user
  Future<void> sendWelcomeNotification({
    required String userName,
    required String residenceName,
  }) async {
    await _showLocalNotification(
      title: '👋 Welcome to $residenceName!',
      body: 'Hi $userName, your account is ready. Explore the app!',
      payload: 'general',
    );
  }

  // ============ NOTIFICATION STORAGE ============

  /// Save notification to Firestore for history
  Future<void> _saveNotification({
    required NotificationType type,
    required String title,
    required String body,
    String? userId,
    String? residenceName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': type.toString().split('.').last,
        'title': title,
        'body': body,
        'userId': userId,
        'residenceName': residenceName,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  /// Get notifications for a user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          // Sort locally to avoid composite index requirement
          list.sort((a, b) {
            final aTime =
                (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime =
                (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
          return list.take(50).toList();
        });
  }

  /// Get notifications for a residence (for owner)
  Stream<List<Map<String, dynamic>>> getResidenceNotifications(
    String residenceName,
  ) {
    if (residenceName.isEmpty) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('residenceName', isEqualTo: residenceName)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          // Sort locally to avoid composite index requirement
          list.sort((a, b) {
            final aTime =
                (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime =
                (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });
          return list.take(50).toList();
        });
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Get unread notification count for user
  Stream<int> getUnreadCountForUser(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.where((doc) => doc.data()['isRead'] != true).length,
        );
  }

  /// Get unread notification count for residence
  Stream<int> getUnreadCountForResidence(String residenceName) {
    if (residenceName.isEmpty) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('residenceName', isEqualTo: residenceName)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.where((doc) => doc.data()['isRead'] != true).length,
        );
  }

  /// Clear old notifications (older than 30 days)
  Future<void> cleanupOldNotifications() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _firestore
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('Cleaned up ${snapshot.docs.length} old notifications');
    } catch (e) {
      debugPrint('Error cleaning up notifications: $e');
    }
  }
}
