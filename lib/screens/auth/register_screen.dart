import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _residenceNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOwner = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _roomNoController.dispose();
    _floorController.dispose();
    _residenceNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_isOwner) {
        await authService.registerOwner(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          residenceName: _residenceNameController.text.trim(),
        );

        // Owner stays signed in and will see verification screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Registration successful! Please verify your account with the code sent to your email.',
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
          residenceName: _residenceNameController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! You can now sign in.'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
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
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Owner/Student Toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.textLight.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Register as:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Student',
                        style: TextStyle(
                          color: !_isOwner
                              ? AppTheme.primaryBlue
                              : AppTheme.textLight,
                          fontWeight: !_isOwner
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Switch(
                        value: _isOwner,
                        onChanged: (value) {
                          setState(() => _isOwner = value);
                        },
                      ),
                      Text(
                        'Owner',
                        style: TextStyle(
                          color: _isOwner
                              ? AppTheme.primaryBlue
                              : AppTheme.textLight,
                          fontWeight: _isOwner
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Residence Name field
            if (_isOwner) ...[
              CustomTextField(
                label: 'Residence/Hostel Name',
                hint: 'Enter your residence name',
                controller: _residenceNameController,
                prefixIcon: const Icon(Icons.home_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter residence name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ] else ...[
              CustomTextField(
                label: 'Residence/Hostel Name',
                hint: 'Enter residence name',
                controller: _residenceNameController,
                prefixIcon: const Icon(Icons.home_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter residence name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],

            CustomTextField(
              label: _isOwner ? 'Full Name' : 'Your Full Name',
              hint: _isOwner ? 'Owner Name' : 'Your Name',
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
            if (!_isOwner) ...[
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isOwner ? 'REGISTER AS OWNER' : 'REQUEST ACCESS',
                onPressed: _register,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isOwner
                  ? 'You will receive a verification code via email\nto activate your account.'
                  : 'By clicking Request Access, you agree to the Comfort PG\nresident guidelines.',
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
