import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hostelapp/screens/auth/google_registration_screen.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/utils/app_theme.dart';
import 'package:hostelapp/widgets/custom_button.dart';
import 'package:hostelapp/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _roomNoController = TextEditingController();
  final _floorController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String _userType = 'student'; // 'student', 'housekeeper', 'owner'

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _roomNoController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  void _showOwnerContactDialog({bool requestSubmitted = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              requestSubmitted ? Icons.check_circle : Icons.admin_panel_settings,
              color: requestSubmitted ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(requestSubmitted ? 'Request Submitted' : 'Owner Registration'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requestSubmitted
                  ? 'Your owner account has been created.'
                  : 'Owner registration requires admin approval.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              requestSubmitted
                  ? 'Your account is pending admin approval. You can sign in once approved.'
                  : 'Please contact the operator to get owner access.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOwnerRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.submitOwnerRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _showOwnerContactDialog(requestSubmitted: true);
        // Clear the form
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Submit owner request for admin approval
    if (_userType == 'owner') {
      await _submitOwnerRequest();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_userType == 'housekeeper') {
        await authService.registerHousekeeper(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registration successful! Please check your email and verify before signing in.',
              ),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        await authService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          roomNo: _roomNoController.text.trim(),
          floor: int.parse(_floorController.text),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registration successful! Please check your email and verify before signing in.',
              ),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Show the message - it might be success message about email verification
        final message = e.toString();
        final isSuccess =
            message.contains('successful') ||
            message.contains('verification link');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isSuccess
                ? AppTheme.successColor
                : AppTheme.errorColor,
            duration: Duration(seconds: isSuccess ? 5 : 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.signInWithGoogle();

      if (!mounted) return;

      if (result.isNewUser) {
        // New user - navigate to registration completion screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const GoogleRegistrationScreen(),
          ),
        );
      } else {
        // Existing user - show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an account. Please sign in instead.',
            ),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        // Don't show error for cancelled sign-in
        if (!errorMessage.toLowerCase().contains('cancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Widget _buildRoleChip(String value, String label, IconData icon) {
    final isSelected = _userType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _userType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryBlue
                  : AppTheme.textLight.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppTheme.textLight,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // User Type Selection
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.textLight.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register as:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildRoleChip(
                        'student',
                        'Student',
                        Icons.school_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildRoleChip(
                        'housekeeper',
                        'Staff',
                        Icons.cleaning_services_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildRoleChip(
                        'owner',
                        'Owner',
                        Icons.admin_panel_settings_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            CustomTextField(
              label: _userType == 'owner' ? 'Full Name' : 'Your Full Name',
              hint: _userType == 'owner'
                  ? 'Owner Name'
                  : (_userType == 'housekeeper' ? 'Staff Name' : 'Your Name'),
              controller: _nameController,
              prefixIcon: const Icon(Icons.person_outline),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Room and Floor (for students only)
            if (_userType == 'student') ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      label: 'Room No.',
                      hint: 'B-201',
                      controller: _roomNoController,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      label: 'Floor',
                      hint: '0',
                      controller: _floorController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.layers_outlined),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            CustomTextField(
              label: 'Email',
              hint: 'Enter your email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: 'Password',
              hint: 'Create a password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _userType == 'owner'
                    ? 'REGISTER AS OWNER'
                    : (_userType == 'housekeeper'
                          ? 'REGISTER AS STAFF'
                          : 'REQUEST ACCESS'),
                onPressed: _register,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 16),

            // Divider with "or"
            Row(
              children: [
                Expanded(
                  child: Divider(color: AppTheme.textLight.withOpacity(0.3)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                ),
                Expanded(
                  child: Divider(color: AppTheme.textLight.withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Google Sign-In Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGoogleLoading ? null : _registerWithGoogle,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.textLight.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isGoogleLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 24),
                      ),
                label: Text(
                  'Continue with Google',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _userType == 'owner'
                  ? 'You will receive a verification code via email\nto activate your account.'
                  : 'For email registration, you will receive a\nverification link to confirm your email.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
