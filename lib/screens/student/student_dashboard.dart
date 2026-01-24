import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/models/payment_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/payment_service.dart';
import 'package:hostelapp/services/complaint_service.dart';
import 'package:hostelapp/utils/app_theme.dart';
import 'package:hostelapp/utils/app_constants.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeScreen(),
      _WashingMachineScreen(),
      _PaymentsScreen(),
      _ComplaintsScreen(),
      _ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForIndex()),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_laundry_service),
            label: 'Washing',
          ),
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
      case 0:
        return AppConstants.appName;
      case 1:
        return 'Washing Machine';
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

class _HomeScreen extends StatelessWidget {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.fullName}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Room ${user.roomNo} - Floor ${user.floor}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildQuickAction(
          'Pay Monthly Rent',
          'Submit your payment details',
          Icons.payment,
          AppTheme.primaryBlue,
          () {},
        ),
        const SizedBox(height: 12),
        _buildQuickAction(
          'Book Washing Machine',
          'Check availability and book',
          Icons.local_laundry_service,
          AppTheme.successColor,
          () {},
        ),
        const SizedBox(height: 12),
        _buildQuickAction(
          'Raise Complaint',
          'Report an issue',
          Icons.report_problem,
          AppTheme.warningColor,
          () {},
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _WashingMachineScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Machines',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildMachineCard('Machine 1', true),
                const SizedBox(height: 12),
                _buildMachineCard('Machine 2', false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMachineCard(String name, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAvailable
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable ? AppTheme.successColor : AppTheme.errorColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_laundry_service,
            color: isAvailable ? AppTheme.successColor : AppTheme.errorColor,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isAvailable ? 'Available' : 'In Use',
                  style: TextStyle(
                    color: isAvailable
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isAvailable)
            ElevatedButton(onPressed: () {}, child: const Text('BOOK')),
        ],
      ),
    );
  }
}

class _PaymentsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final paymentService = Provider.of<PaymentService>(context);
    final user = authService.currentUserModel!;

    return StreamBuilder(
      stream: paymentService.getUserPayments(user.uid),
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Submit Payment'),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (!snapshot.hasData || snapshot.data!.isEmpty)
              const Center(child: Text('No payments yet'))
            else
              ...snapshot.data!.map((payment) {
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('₹${payment.amount}'),
                    subtitle: Text(
                      '${payment.month}\nTxn ID: ${payment.transactionId}',
                    ),
                    trailing: Chip(
                      label: Text(
                        payment.status.toString().split('.').last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      backgroundColor: statusColor,
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _ComplaintsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final complaintService = Provider.of<ComplaintService>(context);
    final user = authService.currentUserModel!;

    return StreamBuilder(
      stream: complaintService.getUserComplaints(user.uid),
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Raise Complaint'),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (!snapshot.hasData || snapshot.data!.isEmpty)
              const Center(child: Text('No complaints'))
            else
              ...snapshot.data!.map((complaint) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(complaint.categoryName),
                    subtitle: Text(complaint.description),
                    trailing: Chip(
                      label: Text(
                        complaint.status.toString().split('.').last,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                );
              }),
          ],
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
                Text(
                  'Room ${user.roomNo} - Floor ${user.floor}',
                  style: Theme.of(context).textTheme.bodyLarge,
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
