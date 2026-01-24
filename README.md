# Comfort PG - Resident Operating System

A comprehensive Flutter application for managing PG (Paying Guest) operations including student management, payments, washing machine bookings, housekeeping tracking, and complaints.

## Features

### 👤 User Roles

#### 1. **Admin (Owner)**
- Add/remove students and housekeeping staff
- Approve/reject student registrations
- Verify payment transactions
- View all washing machine usage logs
- Track housekeeping staff activities
- Manage complaints (mark as pending/in-progress/resolved)
- Receive instant notifications for all events

#### 2. **Student (Resident)**
- Register and login with email
- Submit monthly payment with transaction ID and screenshot
- View payment status (Pending/Verified/Rejected)
- Book washing machines and track usage
- Check machine availability (Free/Busy)
- File complaints with categories and photos
- View housekeeping status for their floor

#### 3. **Housekeeping Staff**
- Check-in when starting cleaning on a floor
- Check-out when done
- View cleaning history
- Floor residents get notified when staff starts cleaning

## Setup Instructions

### 1. Install Dependencies
\`\`\`bash
flutter pub get
\`\`\`

### 2. Firebase Setup
\`\`\`bash
# Configure Firebase (already done via flutterfire configure)
# Ensure firebase_options.dart exists
\`\`\`

### 3. Enable Firebase Services in Console
- **Authentication**: Enable Email/Password
- **Firestore**: Create database
- **Storage**: Enable for file uploads
- **Cloud Messaging**: Enable for notifications

### 4. Create First Admin User
1. Run app and register
2. Go to Firestore Console
3. Find user in \`users\` collection
4. Set \`role: "admin"\` and \`isActive: true\`

### 5. Run Application
\`\`\`bash
flutter run
\`\`\`

## Tech Stack
- Flutter 3.10.7
- Firebase (Auth, Firestore, Storage, Messaging)
- Provider (State Management)
- Google Fonts, Image Picker

## Project Structure
\`\`\`
lib/
├── models/          # Data models
├── screens/         # UI screens (auth, admin, student, housekeeping)
├── services/        # Firebase services
├── widgets/         # Reusable widgets
└── utils/          # Constants & themes
\`\`\`

## Created By
Comfort PG Management System - Built with Flutter & Firebase
