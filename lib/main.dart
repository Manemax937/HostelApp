import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/firebase_options.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/payment_service.dart';
import 'package:hostelapp/services/washing_machine_service.dart';
import 'package:hostelapp/services/machine_service.dart';
import 'package:hostelapp/services/complaint_service.dart';
import 'package:hostelapp/services/housekeeping_service.dart';
import 'package:hostelapp/services/notification_service.dart';
import 'package:hostelapp/services/notice_service.dart';
import 'package:hostelapp/services/pg_attendance_service.dart';
import 'package:hostelapp/services/banner_service.dart';
import 'package:hostelapp/screens/auth/auth_screen.dart';
import 'package:hostelapp/screens/home/home_wrapper.dart';
import 'package:hostelapp/utils/app_theme.dart';
import 'package:hostelapp/utils/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler - must be done after Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Notification Service
  await NotificationService().initialize();

  // Clean up old resolved complaints (older than 24 hours)
  ComplaintService().cleanupOldResolvedComplaints();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PaymentService()),
        ChangeNotifierProvider(create: (_) => WashingMachineService()),
        ChangeNotifierProvider(create: (_) => MachineService()),
        ChangeNotifierProvider(create: (_) => ComplaintService()),
        ChangeNotifierProvider(create: (_) => HousekeepingService()),
        ChangeNotifierProvider(create: (_) => NoticeService()),
        ChangeNotifierProvider(create: (_) => PgAttendanceService()),
        ChangeNotifierProvider(create: (_) => BannerService()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && authService.currentUserModel != null) {
          final user = authService.currentUserModel!;

          // Check if owner needs verification
          if (user.role == UserRole.owner && user.isVerified == false) {
            return const OwnerVerificationScreen();
          }

          if (user.isActive) {
            return const HomeWrapper();
          } else {
            // User is not active yet
            return const PendingApprovalScreen();
          }
        }

        return const AuthScreen();
      },
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pending, size: 80, color: AppTheme.warningColor),
              const SizedBox(height: 24),
              Text(
                'Pending Approval',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Your account is waiting for admin approval.\nYou will be notified once approved.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Provider.of<AuthService>(context, listen: false).signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OwnerVerificationScreen extends StatefulWidget {
  const OwnerVerificationScreen({super.key});

  @override
  State<OwnerVerificationScreen> createState() =>
      _OwnerVerificationScreenState();
}

class _OwnerVerificationScreenState extends State<OwnerVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.verifyOwner(_codeController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account verified successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user,
                  size: 80,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Account',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check your email for the verification code.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Enter Verification Code',
                    hintText: '6-digit code',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 4),
                  maxLength: 6,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('VERIFY'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Provider.of<AuthService>(context, listen: false).signOut();
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
