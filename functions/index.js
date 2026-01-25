/**
 * Firebase Cloud Functions for Comfort PG Hostel App
 * Handles push notifications when notifications are created in Firestore
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Send push notification when a new notification document is created
 * This triggers for notifications saved to Firestore
 */
exports.sendPushNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      const notification = snap.data();
      const {title, body, userId, residenceName, type} = notification;

      console.log("New notification:", {title, userId, residenceName, type});

      try {
        // If notification is for a specific user
        if (userId) {
          await sendToUser(userId, title, body, type);
        }

        // If notification is for a residence (owner notification)
        if (residenceName) {
          await sendToResidenceOwner(residenceName, title, body, type);
        }

        return {success: true};
      } catch (error) {
        console.error("Error sending push notification:", error);
        return {success: false, error: error.message};
      }
    });

/**
 * Send push notification to a specific user by their FCM token
 */
async function sendToUser(userId, title, body, type) {
  const userDoc = await db.collection("users").doc(userId).get();

  if (!userDoc.exists) {
    console.log("User not found:", userId);
    return;
  }

  const userData = userDoc.data();
  const fcmToken = userData.fcmToken;

  if (!fcmToken) {
    console.log("No FCM token for user:", userId);
    return;
  }

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: type || "general",
      userId: userId,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    token: fcmToken,
    android: {
      notification: {
        channelId: "comfort_pg_channel",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.send(message);
    console.log("Successfully sent to user:", userId, response);
  } catch (error) {
    if (error.code === "messaging/registration-token-not-registered") {
      // Token is invalid, remove it
      await db.collection("users").doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
      console.log("Removed invalid token for user:", userId);
    }
    throw error;
  }
}

/**
 * Send push notification to residence owner
 */
async function sendToResidenceOwner(residenceName, title, body, type) {
  // Find owner of this residence
  const ownersSnapshot = await db.collection("users")
      .where("role", "==", "owner")
      .where("residenceName", "==", residenceName)
      .where("isVerified", "==", true)
      .get();

  if (ownersSnapshot.empty) {
    console.log("No verified owner found for residence:", residenceName);
    return;
  }

  // Send to all owners of this residence
  const sendPromises = ownersSnapshot.docs.map(async (doc) => {
    const ownerData = doc.data();
    const fcmToken = ownerData.fcmToken;

    if (!fcmToken) {
      console.log("No FCM token for owner:", doc.id);
      return;
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type || "general",
        residenceName: residenceName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: "comfort_pg_channel",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log("Successfully sent to owner:", doc.id, response);
    } catch (error) {
      if (error.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(doc.id).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log("Removed invalid token for owner:", doc.id);
      }
      throw error;
    }
  });

  await Promise.allSettled(sendPromises);
}

/**
 * Send verification code email to owner
 * Triggered when a new owner registers
 */
exports.sendOwnerVerificationEmail = functions.firestore
    .document("users/{userId}")
    .onCreate(async (snap, context) => {
      const userData = snap.data();
      const {email, fullName, role, verificationCode} = userData;

      // Only process owner registrations
      if (role !== "owner" || !verificationCode) {
        return null;
      }

      console.log("New owner registered:", email);

      // Note: For production, you would use a proper email service
      // like SendGrid, Mailgun, or Firebase Extensions
      // This is a placeholder for the email sending logic

      // Option 1: Use Firebase Auth custom claims + email verification
      // Option 2: Use third-party email service

      // For now, we'll just log it - in production, integrate email service
      console.log(`
        ========================================
        VERIFICATION CODE EMAIL
        ========================================
        To: ${email}
        Name: ${fullName}
        Verification Code: ${verificationCode}
        ========================================
      `);

      // Mark that verification code was sent
      await db.collection("users").doc(context.params.userId).update({
        verificationEmailSent: true,
        verificationEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {success: true};
    });

/**
 * Clean up old notifications (older than 30 days)
 * Runs daily at midnight
 */
exports.cleanupOldNotifications = functions.pubsub
    .schedule("0 0 * * *")
    .timeZone("Asia/Kolkata")
    .onRun(async (context) => {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 30);

      const oldNotifications = await db.collection("notifications")
          .where("createdAt", "<", admin.firestore.Timestamp.fromDate(cutoffDate))
          .get();

      const batch = db.batch();
      oldNotifications.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Deleted ${oldNotifications.size} old notifications`);

      return null;
    });
