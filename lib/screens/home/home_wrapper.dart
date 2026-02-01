import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/screens/dashboard/unified_dashboard.dart';
import 'package:hostelapp/screens/housekeeping/housekeeper_dashboard.dart';

class HomeWrapper extends StatelessWidget {
  const HomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Route housekeepers to their dedicated dashboard
    if (user.role == UserRole.housekeeping) {
      return const HousekeeperDashboard();
    }

    // All other users get the unified dashboard
    return const UnifiedDashboard();
  }
}
