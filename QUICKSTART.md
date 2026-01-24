# Quick Start Guide - Comfort PG App

## 🚀 Getting Started in 5 Minutes

### Step 1: Run the App
\`\`\`bash
flutter run
\`\`\`

### Step 2: Create Your First Admin Account

1. **Tap "REGISTER" tab** in the app
2. Fill in the registration form:
   - Full Name: Your Name
   - Room No: ADMIN
   - Floor: 0
   - Email: admin@comfortpg.com
   - Password: admin123
3. **Tap "REQUEST ACCESS"**

### Step 3: Activate Admin Account

Since you've already run `flutterfire configure`, Firebase is set up. Now:

1. **Open Firebase Console**: https://console.firebase.google.com/
2. **Go to Firestore Database**
3. **Find the `users` collection**
4. **Click on your newly created user document**
5. **Edit the document**:
   - Change `role` from "student" to **"admin"**
   - Change `isActive` from false to **true**
6. **Save the changes**

### Step 4: Sign In as Admin

1. **Close and reopen the app** (or hot restart)
2. **Tap "SIGN IN" tab**
3. **Enter**:
   - Email: admin@comfortpg.com
   - Password: admin123
4. **Tap "SIGN IN"**

🎉 **You're now logged in as Admin!**

---

## 📱 What You Can Do Now

### As Admin:

#### **Dashboard Tab**
- View statistics
- See pending approvals
- Monitor all activities

#### **Users Tab**
- See all registered users
- Toggle user active status (approve/reject registrations)
- View user details

#### **Payments Tab**
- View all payment submissions
- Approve or reject payments
- See transaction IDs and screenshots

#### **Complaints Tab**
- View all complaints
- Update complaint status
- Add admin notes

---

## 👥 Testing Different User Roles

### Create a Student Account:

1. Sign out from admin
2. Register with:
   - Full Name: John Doe
   - Room No: B-201
   - Floor: 2
   - Email: john@test.com
   - Password: test123
3. As admin, approve this user:
   - Go to Firebase Console → Firestore → users collection
   - Find John Doe's document
   - Set `isActive: true`
4. Sign in as John to test student features

### Create a Housekeeping Staff Account:

1. Register new account
2. In Firebase Console:
   - Set `role: "housekeeping"`
   - Set `isActive: true`
3. Sign in to test housekeeping features

---

## 🔥 Firebase Collections Created Automatically

When you use the app, these collections will be created in Firestore:

- ✅ **users** - All registered users
- ✅ **payments** - Payment submissions
- ✅ **washing_machines** - Machine bookings
- ✅ **complaints** - Student complaints
- ✅ **housekeeping_logs** - Cleaning sessions

---

## 🎨 UI Features (Matching Your Design)

The app matches your provided UI with:

✅ Dark navy buttons and headers
✅ Clean white cards with subtle borders
✅ Light gray background
✅ Professional typography (Inter font)
✅ Consistent spacing and padding
✅ Smooth animations

---

## ⚠️ Important Notes

### Firebase Security Rules (Set these up!)

1. **Go to Firebase Console → Firestore Database → Rules**
2. **Replace with**:

\`\`\`javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
\`\`\`

3. **Publish the rules**

### For Storage (if using image uploads):

1. **Go to Firebase Console → Storage → Rules**
2. **Replace with**:

\`\`\`javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
\`\`\`

---

## 🐛 Troubleshooting

### "No Firebase App" Error
\`\`\`bash
flutterfire configure
# Select your project and platforms
\`\`\`

### "User not active" after login
- Check Firestore → users → your user document
- Ensure `isActive: true`

### Can't see data
- Check Firebase Console → Firestore
- Data should appear after using features

### App crashes on startup
\`\`\`bash
flutter clean
flutter pub get
flutter run
\`\`\`

---

## 📞 Next Steps

1. ✅ Test all admin features
2. ✅ Create test student and staff accounts
3. ✅ Submit a test payment
4. ✅ Book a washing machine
5. ✅ File a test complaint
6. ✅ Test housekeeping check-in/out

---

## 🎯 Key Features to Test

### Payment Flow:
1. Student submits payment with transaction ID
2. Admin receives notification (in app)
3. Admin verifies payment
4. Student sees "Verified" status

### Washing Machine:
1. Check machine status (Free/Busy)
2. Book a machine
3. Enter clothes count
4. Start session
5. End session when done

### Complaints:
1. Select category
2. Enter description
3. Optionally add photo
4. Submit
5. Admin updates status

### Housekeeping:
1. Staff selects floor
2. Checks in
3. Floor residents get notified
4. Staff checks out when done

---

Enjoy your Comfort PG app! 🏠✨
