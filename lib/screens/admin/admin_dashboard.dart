import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/models/payment_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/payment_service.dart';
import 'package:hostelapp/services/complaint_service.dart';
import 'package:hostelapp/utils/app_theme.dart';
import 'package:hostelapp/utils/app_constants.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardOverview(),
      _UsersManagement(),
      _PaymentsManagement(),
      _ComplaintsManagement(),
      _ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? AppConstants.appName : _getTitleForIndex(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  String _getTitleForIndex() {
    switch (_currentIndex) {
      case 1:
        return 'User Management';
      case 2:
        return 'Payments';
      case 3:
        return 'Complaints';
      case 4:
        return 'Profile';
      default:
        return AppConstants.appName;
    }
  }
}

class _DashboardOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Total Students',
          '24',
          Icons.people,
          AppTheme.primaryBlue,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Pending Approvals',
          '3',
          Icons.pending,
          AppTheme.warningColor,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Pending Payments',
          '5',
          Icons.payment,
          AppTheme.errorColor,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Active Complaints',
          '2',
          Icons.report_problem,
          AppTheme.warningColor,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Washing Machines',
          '2 Available',
          Icons.local_laundry_service,
          AppTheme.successColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersManagement extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<List<UserModel>>(
      stream: authService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        final users = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.isActive
                      ? AppTheme.primaryBlue
                      : AppTheme.textLight,
                  child: Text(user.fullName[0].toUpperCase()),
                ),
                title: Text(user.fullName),
                subtitle: Text(
                  '${user.role.toString().split('.').last.toUpperCase()} - Room ${user.roomNo ?? "N/A"}',
                ),
                trailing: Switch(
                  value: user.isActive,
                  onChanged: (value) {
                    authService.toggleUserStatus(user.uid, value);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentsManagement extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final paymentService = Provider.of<PaymentService>(context);

    return StreamBuilder(
      stream: paymentService.getAllPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No payments found'));
        }

        final payments = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            Color statusColor;
            switch (payment.status) {
              case PaymentStatus.verified:
                statusColor = AppTheme.successColor;
                break;
              case PaymentStatus.rejected:
                statusColor = AppTheme.errorColor;
                break;
              default:
                statusColor = AppTheme.warningColor;
            }

            return Card(
              child: ListTile(
                title: Text(payment.userName),
                subtitle: Text(
                  '₹${payment.amount} - ${payment.transactionId}\n${payment.month}',
                ),
                trailing: Chip(
                  label: Text(
                    payment.status.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  backgroundColor: statusColor,
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _ComplaintsManagement extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final complaintService = Provider.of<ComplaintService>(context);

    return StreamBuilder(
      stream: complaintService.getAllComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No complaints found'));
        }

        final complaints = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final complaint = complaints[index];

            return Card(
              child: ListTile(
                title: Text(complaint.categoryName),
                subtitle: Text(
                  '${complaint.userName} - ${complaint.roomNo}\n${complaint.description}',
                ),
                trailing: Chip(
                  label: Text(
                    complaint.status.toString().split('.').last,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    user.role.toString().split('.').last.toUpperCase(),
                  ),
                  backgroundColor: AppTheme.primaryBlue,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Sign Out'),
            onTap: () {
              authService.signOut();
            },
          ),
        ),
      ],
    );
  }
}
