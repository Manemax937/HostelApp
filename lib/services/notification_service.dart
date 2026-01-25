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
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    debugPrint(
      'Notification permission status: ${settings.authorizationStatus}',
    );

    // Create Android notification channel (required for Android 8.0+)
    const androidChannel = AndroidNotificationChannel(
      'comfort_pg_channel',
      'Comfort PG Notifications',
      description: 'Notifications for Comfort PG residents',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Set foreground notification presentation options for iOS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

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

  /// Save FCM token to user's document for push notifications
  Future<void> _saveUserFcmToken() async {
    try {
      final token = await _messaging.getToken();
      final userId = _currentUserId;

      debugPrint('FCM Token: $token');
      debugPrint('Current User ID: $userId');

      if (token != null && userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': Timestamp.now(),
        });
        debugPrint('FCM Token saved for user: $userId');
      } else {
        debugPrint('Cannot save FCM token: token=$token, userId=$userId');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Public method to refresh FCM token (call after login)
  Future<void> refreshFcmToken() async {
    await _saveUserFcmToken();
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
    // Save to Firestore - Cloud Function sends push to all students
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

  /// Send notification when machine is booked (broadcast to residence)
  Future<void> sendMachineBookingNotification({
    required String machineName,
    required String slotTime,
    required String userId,
    String? userName,
    String? residenceName,
  }) async {
    // Save to Firestore for all residence members to see
    if (residenceName != null) {
      await _saveNotification(
        type: NotificationType.machine,
        title: '🧺 Machine Booked',
        body: '${userName ?? "Someone"} booked $machineName',
        residenceName: residenceName,
      );
    }
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

  /// Send notification when machine is available (broadcast to residence)
  Future<void> sendMachineAvailableNotification({
    required String machineName,
    String? residenceName,
  }) async {
    // Broadcast to all residence members
    if (residenceName != null) {
      await _saveNotification(
        type: NotificationType.machine,
        title: '🧺 Machine Available',
        body: '$machineName is now available for booking',
        residenceName: residenceName,
      );
    }
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
    required String ownerId,
  }) async {
    // Send only to the specific owner, not to entire residence (private)
    await _saveNotification(
      type: NotificationType.finance,
      title: '💳 Payment Pending',
      body:
          '$studentName submitted ₹${amount.toStringAsFixed(0)} for verification',
      userId: ownerId,
    );
  }

  // ============ SUPPORT NOTIFICATIONS ============

  /// Send notification when complaint is submitted (broadcast to residence)
  Future<void> sendComplaintSubmittedNotification({
    required String userId,
    required String category,
    String? userName,
    String? residenceName,
  }) async {
    // Save to Firestore for the user
    await _saveNotification(
      type: NotificationType.support,
      title: '📝 Complaint Submitted',
      body: 'Your $category complaint has been submitted',
      userId: userId,
    );

    // Also broadcast to residence so everyone knows
    if (residenceName != null) {
      await _saveNotification(
        type: NotificationType.support,
        title: '🔧 New $category Issue',
        body: '${userName ?? "A resident"} reported a $category issue',
        residenceName: residenceName,
      );
    }
  }

  /// Send notification to owner about new complaint (student submits)
  Future<void> sendNewComplaintNotification({
    required String studentName,
    required String category,
    required String residenceName,
  }) async {
    // Save to Firestore for owner and all residence members to see
    await _saveNotification(
      type: NotificationType.support,
      title: '🆘 New Complaint',
      body: '$studentName raised a $category complaint',
      residenceName: residenceName,
    );
  }

  /// Send notification when complaint is resolved (broadcast to residence)
  Future<void> sendComplaintResolvedNotification({
    required String userId,
    required String category,
    String? residenceName,
  }) async {
    // Notify the student who raised it
    await _saveNotification(
      type: NotificationType.support,
      title: '✅ Complaint Resolved',
      body: 'Your $category complaint has been resolved',
      userId: userId,
    );

    // Also broadcast to residence
    if (residenceName != null) {
      await _saveNotification(
        type: NotificationType.support,
        title: '✅ Issue Resolved',
        body: 'A $category issue has been resolved',
        residenceName: residenceName,
      );
    }
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

  /// Get notifications for a user (personal notifications only)
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

  /// Get all notifications for a student (personal + residence-wide)
  /// This combines user-specific notifications (like finance) with
  /// residence-wide notifications (like notices, machine bookings)
  Stream<List<Map<String, dynamic>>> getStudentNotifications({
    required String userId,
    required String residenceName,
  }) {
    if (userId.isEmpty) return Stream.value([]);

    // If no residence name, just return user notifications
    if (residenceName.isEmpty) {
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

    // Get user-specific notifications stream
    final userStream = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots();

    // Get residence-wide notifications stream (for notices, machine bookings, etc.)
    final residenceStream = _firestore
        .collection('notifications')
        .where('residenceName', isEqualTo: residenceName)
        .snapshots();

    // Combine both streams - when either changes, recombine all notifications
    return userStream.asyncExpand((userSnapshot) {
      return residenceStream.map((residenceSnapshot) {
        final List<Map<String, dynamic>> allNotifications = [];
        final Set<String> addedIds = {};

        // Add user-specific notifications
        for (final doc in userSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          allNotifications.add(data);
          addedIds.add(doc.id);
        }

        // Add residence-wide notifications (avoid duplicates)
        for (final doc in residenceSnapshot.docs) {
          if (!addedIds.contains(doc.id)) {
            final data = doc.data();
            data['id'] = doc.id;
            allNotifications.add(data);
          }
        }

        // Sort by createdAt descending
        allNotifications.sort((a, b) {
          final aTime =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bTime.compareTo(aTime);
        });

        return allNotifications.take(50).toList();
      });
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

  /// Get unread notification count for user (personal notifications only)
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

  /// Get unread notification count for student (personal + residence-wide)
  Stream<int> getUnreadCountForStudent({
    required String userId,
    required String residenceName,
  }) {
    if (userId.isEmpty) return Stream.value(0);

    // If no residence name, just return user unread count
    if (residenceName.isEmpty) {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .where((doc) => doc.data()['isRead'] != true)
                .length,
          );
    }

    // Get user-specific notifications stream
    final userStream = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots();

    // Get residence-wide notifications stream
    final residenceStream = _firestore
        .collection('notifications')
        .where('residenceName', isEqualTo: residenceName)
        .snapshots();

    // Combine both streams for reactive unread count
    return userStream.asyncExpand((userSnapshot) {
      return residenceStream.map((residenceSnapshot) {
        final Set<String> countedIds = {};
        int unreadCount = 0;

        // Count user-specific unread notifications
        for (final doc in userSnapshot.docs) {
          if (doc.data()['isRead'] != true) {
            unreadCount++;
          }
          countedIds.add(doc.id);
        }

        // Count residence-wide unread notifications (avoid duplicates)
        for (final doc in residenceSnapshot.docs) {
          if (!countedIds.contains(doc.id) && doc.data()['isRead'] != true) {
            unreadCount++;
          }
        }

        return unreadCount;
      });
    });
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
