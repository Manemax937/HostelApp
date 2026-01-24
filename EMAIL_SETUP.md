# Email Verification Setup for Owners

## Current Implementation

When an owner registers, a 6-digit verification code is:
1. Generated automatically
2. Stored in the user's Firestore document under `verificationCode`
3. Needs to be sent via email to the owner

## Option 1: Firebase Cloud Functions (Recommended)

Create a Cloud Function to send emails with the verification code:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure your email service (e.g., Gmail, SendGrid, etc.)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com',
    pass: 'your-app-password'
  }
});

exports.sendVerificationEmail = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const user = snap.data();
    
    // Only send for owners who need verification
    if (user.role === 'owner' && user.verificationCode && !user.isVerified) {
      const mailOptions = {
        from: 'Comfort PG <noreply@comfortpg.com>',
        to: user.email,
        subject: 'Verify Your Owner Account - Comfort PG',
        html: `
          <h2>Welcome to Comfort PG!</h2>
          <p>Hello ${user.fullName},</p>
          <p>Thank you for registering <strong>${user.residenceName}</strong> on Comfort PG.</p>
          <p>Your verification code is:</p>
          <h1 style="color: #1976D2; letter-spacing: 5px;">${user.verificationCode}</h1>
          <p>Please enter this code in the app to activate your account.</p>
          <p>This code is valid for 24 hours.</p>
          <br>
          <p>Best regards,<br>Comfort PG Team</p>
        `
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log('Verification email sent to:', user.email);
      } catch (error) {
        console.error('Error sending email:', error);
      }
    }
  });
```

### Setup Steps:
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Initialize functions: `firebase init functions`
3. Install nodemailer: `cd functions && npm install nodemailer`
4. Deploy: `firebase deploy --only functions`

## Option 2: SendGrid API

1. Sign up at https://sendgrid.com
2. Get API key
3. Add to cloud function or backend service
4. Send templated emails

## Option 3: Email Service Integration

Use services like:
- **Mailgun**: Good for transactional emails
- **AWS SES**: Cost-effective for high volume
- **Postmark**: Excellent deliverability
- **Resend**: Modern email API

## Temporary Testing Solution

For development/testing, you can:
1. Check Firestore console for the verification code
2. Manually send it to test email
3. Or display it in Firebase Functions logs

## Important Notes

- Store email credentials securely (use Firebase Functions config or environment variables)
- Enable "Less secure app access" for Gmail or use App Passwords
- Consider rate limiting to prevent abuse
- Implement code expiration (e.g., 24 hours)
- Add resend code functionality for user convenience

## Security Best Practices

1. Use environment variables for email credentials
2. Implement rate limiting on verification attempts
3. Add code expiration time
4. Log verification attempts for security monitoring
5. Use HTTPS for all communications
