import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/services/housekeeping_service.dart';
import 'package:hostelapp/models/housekeeping_model.dart';
import 'package:hostelapp/utils/app_theme.dart';

class HousekeepingAdminView extends StatelessWidget {
  const HousekeepingAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final housekeepingService = Provider.of<HousekeepingService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Housekeeping Logs'),
      ),
      body: StreamBuilder<List<HousekeepingLog>>(
        stream: housekeepingService.getAllLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const Center(child: Text('No housekeeping logs yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final log = logs[index];
              final started = log.checkInTime.toLocal();
              final ended = log.checkOutTime?.toLocal();

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue,
                    child: Text('${log.floor}'),
                  ),
                  title: Text('${log.staffName} — Floor ${log.floor}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Started: ${started.toString()}'),
                      if (ended != null) Text('Ended: ${ended.toString()}'),
                    ],
                  ),
                  trailing: ended != null
                      ? Text('${log.duration!.inMinutes} min')
                      : ElevatedButton(
                          onPressed: () {
                            // allow admin to force-checkout
                            housekeepingService.checkOut(log.id);
                          },
                          child: const Text('End'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
