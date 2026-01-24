import 'package:flutter/material.dart';
import 'package:hostelapp/screens/auth/sign_in_screen.dart';
import 'package:hostelapp/screens/auth/register_screen.dart';
import 'package:hostelapp/utils/app_constants.dart';
import 'package:hostelapp/utils/app_theme.dart';
import 'package:hostelapp/widgets/app_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 40,
                  ),
                  child: Column(
                    children: [
                      // Logo
                      const AppLogo(size: 80),
                      const SizedBox(height: 24),

                      // App Title
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        AppConstants.appSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          letterSpacing: 2,
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          labelColor: AppTheme.textPrimary,
                          unselectedLabelColor: AppTheme.textLight,
                          labelStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                          tabs: const [
                            Tab(icon: Icon(Icons.login), text: 'SIGN IN'),
                            Tab(icon: Icon(Icons.person_add), text: 'REGISTER'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tab Views
                      SizedBox(
                        height: 500,
                        child: TabBarView(
                          controller: _tabController,
                          children: const [SignInScreen(), RegisterScreen()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
