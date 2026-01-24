import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/utils/app_theme.dart';

// Import separate screen widgets - Owner screens
import 'widgets/dashboard_screen.dart';
import 'widgets/residents_screen.dart';
import 'widgets/finance_screen.dart';
import 'widgets/support_screen.dart';
import 'widgets/operations_screen.dart';
import 'widgets/account_screen.dart';

// Student specific screens
import 'widgets/student_dashboard_screen.dart';
import 'widgets/student_finance_screen.dart';
import 'widgets/student_support_screen.dart';
import 'widgets/student_account_screen.dart';

class UnifiedDashboard extends StatefulWidget {
  const UnifiedDashboard({super.key});

  @override
  State<UnifiedDashboard> createState() => _UnifiedDashboardState();
}

class _UnifiedDashboardState extends State<UnifiedDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final isStudent = user?.role == UserRole.student;

    // Different screens for owner vs student
    final ownerScreens = [
      const DashboardScreen(),
      const ResidentsScreen(),
      const FinanceScreen(),
      const SupportScreen(),
      const OperationsScreen(),
      const AccountScreen(),
    ];

    final studentScreens = [
      const StudentDashboardScreen(),
      const StudentFinanceScreen(),
      const StudentSupportScreen(),
      const StudentAccountScreen(),
    ];

    final screens = isStudent ? studentScreens : ownerScreens;

    // Ensure currentIndex doesn't exceed screen count
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.home, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Comfort PG',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          // Settings icon for students
          if (isStudent)
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isStudent ? Colors.green : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  user?.role.toString().split('.').last.toUpperCase() ?? 'USER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black87,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: isStudent ? _studentNavItems : _ownerNavItems,
      ),
    );
  }

  // Owner navigation items (6 tabs)
  List<BottomNavigationBarItem> get _ownerNavItems => const [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'FACILITY',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: 'RESIDENTS',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet_outlined),
      activeIcon: Icon(Icons.account_balance_wallet),
      label: 'FINANCE',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.support_agent_outlined),
      activeIcon: Icon(Icons.support_agent),
      label: 'SUPPORT',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'OPERATIONS',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'ACCOUNT',
    ),
  ];

  // Student navigation items (4 tabs)
  List<BottomNavigationBarItem> get _studentNavItems => const [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'FACILITY',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet_outlined),
      activeIcon: Icon(Icons.account_balance_wallet),
      label: 'FINANCE',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.support_agent_outlined),
      activeIcon: Icon(Icons.support_agent),
      label: 'SUPPORT',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'ACCOUNT',
    ),
  ];
}
