import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/housekeeping_service.dart';
import 'package:hostelapp/utils/app_theme.dart';

class HousekeepingDashboard extends StatelessWidget {
  const HousekeepingDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final housekeepingService = Provider.of<HousekeepingService>(context);
    final user = authService.currentUserModel!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Housekeeping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: housekeepingService.getActiveSession(user.uid),
        builder: (context, snapshot) {
          final activeSession = snapshot.data;

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
                        'Housekeeping Staff',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (activeSession != null)
                Card(
                  color: AppTheme.successColor.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.cleaning_services,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Currently Cleaning',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Floor ${activeSession.floor}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Started at ${TimeOfDay.fromDateTime(activeSession.checkInTime).format(context)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              housekeepingService.checkOut(activeSession.id);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                            ),
                            child: const Text('CHECK OUT'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Floor to Clean',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(5, (index) {
                            final floor = index;
                            return SizedBox(
                              width: 80,
                              child: ElevatedButton(
                                onPressed: () {
                                  housekeepingService.checkIn(
                                    staffId: user.uid,
                                    staffName: user.fullName,
                                    floor: floor,
                                  );
                                },
                                child: Text('Floor $floor'),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Cleaning History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder(
                        stream: housekeepingService.getStaffLogs(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text('No cleaning history yet');
                          }

                          return Column(
                            children: snapshot.data!.take(5).map((log) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryBlue,
                                  child: Text('${log.floor}'),
                                ),
                                title: Text('Floor ${log.floor}'),
                                subtitle: Text(
                                  '${TimeOfDay.fromDateTime(log.checkInTime).format(context)}',
                                ),
                                trailing: log.duration != null
                                    ? Text('${log.duration!.inMinutes} min')
                                    : null,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
