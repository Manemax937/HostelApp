/**
 * Firebase Cloud Functions for Comfort PG Hostel App
 * Handles push notifications when notifications are created in Firestore
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Email transporter configuration
// For production, use environment variables: firebase functions:config:set email.user="your-email" email.pass="your-app-password"
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().email?.user || process.env.EMAIL_USER,
    pass: functions.config().email?.pass || process.env.EMAIL_PASS,
  },
});

/**
 * Generate a secure 6-digit verification code
 */
function generateVerificationCode() {
  return crypto.randomInt(100000, 999999).toString();
}

/**
 * Hash a verification code using SHA256
 */
function hashCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

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

        // If notification is for a residence
        if (residenceName) {
          // For notice notifications, send to all STUDENTS in the residence
          if (type === "notice" || type === "machine" || type === "complaint") {
            await sendToResidenceStudents(residenceName, title, body, type);
          } else {
            // For other types, send to owner
            await sendToResidenceOwner(residenceName, title, body, type);
          }
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
 * Send push notification to all students in a residence
 * Used for notices, machine bookings, complaints etc.
 */
async function sendToResidenceStudents(residenceName, title, body, type) {
  // Find all students in this residence
  const studentsSnapshot = await db.collection("users")
      .where("role", "==", "student")
      .where("residenceName", "==", residenceName)
      .get();

  if (studentsSnapshot.empty) {
    console.log("No students found for residence:", residenceName);
    return;
  }

  console.log(`Sending to ${studentsSnapshot.size} students in ${residenceName}`);

  // Send to all students with FCM tokens
  const sendPromises = studentsSnapshot.docs.map(async (doc) => {
    const studentData = doc.data();
    const fcmToken = studentData.fcmToken;

    if (!fcmToken) {
      console.log("No FCM token for student:", doc.id);
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
      console.log("Successfully sent to student:", doc.id, response);
    } catch (error) {
      if (error.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(doc.id).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        console.log("Removed invalid token for student:", doc.id);
      }
      // Don't throw - continue with other students
      console.error("Error sending to student:", doc.id, error.message);
    }
  });

  await Promise.allSettled(sendPromises);
}

/**
 * Send verification code email to owner
 * Triggered when a new owner registers
 * Generates code server-side, stores HASH only, sends plain code via email
 */
exports.sendOwnerVerificationEmail = functions.firestore
    .document("users/{userId}")
    .onCreate(async (snap, context) => {
      const userData = snap.data();
      const {email, fullName, residenceName, role} = userData;

      // Only process owner registrations
      if (role !== "owner") {
        return null;
      }

      console.log("New owner registered:", email);

      // Generate verification code server-side (SECURE)
      const verificationCode = generateVerificationCode();
      const verificationCodeHash = hashCode(verificationCode);

      // Set expiration time (24 hours from now)
      const expiresAt = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 24 * 60 * 60 * 1000),
      );

      // Store ONLY the hash (not the plain code) with expiration
      await db.collection("users").doc(context.params.userId).update({
        verificationCodeHash: verificationCodeHash,
        verificationCodeExpiresAt: expiresAt,
        verificationEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const mailOptions = {
        from: "Comfort PG <noreply@comfortpg.com>",
        to: email,
        subject: "Verify Your Owner Account - Comfort PG",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #1976D2, #42A5F5); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
              <h1 style="color: white; margin: 0;">Comfort PG</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 5px 0 0 0;">Resident Operating System</p>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
              <h2 style="color: #333; margin-top: 0;">Welcome, ${fullName}!</h2>
              <p style="color: #666; font-size: 16px;">Thank you for registering <strong>${residenceName || "your residence"}</strong> on Comfort PG.</p>
              <p style="color: #666; font-size: 16px;">To complete your registration, please enter the following verification code in the app:</p>
              <div style="background: #f5f5f5; border-radius: 8px; padding: 20px; text-align: center; margin: 25px 0;">
                <h1 style="color: #1976D2; letter-spacing: 8px; font-size: 36px; margin: 0;">${verificationCode}</h1>
              </div>
              <p style="color: #999; font-size: 14px;">This code is valid for 24 hours. If you did not register for Comfort PG, please ignore this email.</p>
              <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
              <p style="color: #999; font-size: 12px; text-align: center; margin: 0;">Best regards,<br>The Comfort PG Team</p>
            </div>
          </div>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log("Verification email sent to:", email);

        // Update status (don't log the code!)
        await db.collection("users").doc(context.params.userId).update({
          verificationEmailSent: true,
        });

        return {success: true};
      } catch (error) {
        console.error("Error sending verification email:", error);

        // Mark email sending failed
        await db.collection("users").doc(context.params.userId).update({
          verificationEmailSent: false,
          verificationEmailError: error.message,
        });

        return {success: false, error: error.message};
      }
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
