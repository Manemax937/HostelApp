import 'package:flutter/material.dart';
import 'package:hostelapp/models/housekeeping_model.dart';
import 'package:hostelapp/services/housekeeping_service.dart';
import 'package:hostelapp/services/floor_config_service.dart';
import 'package:intl/intl.dart';

class HousekeepingAdminScreen extends StatefulWidget {
  const HousekeepingAdminScreen({super.key});

  @override
  State<HousekeepingAdminScreen> createState() =>
      _HousekeepingAdminScreenState();
}

class _HousekeepingAdminScreenState extends State<HousekeepingAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FloorConfigService _floorService = FloorConfigService();
  final HousekeepingService _housekeepingService = HousekeepingService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Housekeeping Management'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: const Color(0xFF6C63FF),
          tabs: const [
            Tab(icon: Icon(Icons.layers), text: 'Floors'),
            Tab(icon: Icon(Icons.history), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FloorsManagementTab(floorService: _floorService),
          _LogsTab(housekeepingService: _housekeepingService),
        ],
      ),
    );
  }
}

// Floors Management Tab
class _FloorsManagementTab extends StatelessWidget {
  final FloorConfigService floorService;

  const _FloorsManagementTab({required this.floorService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
      stream: floorService.getFloorsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final floors = snapshot.data ?? [1, 2, 3, 4, 5];

        return Column(
          children: [
            // Header Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.layers,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Floor Configuration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${floors.length} floors configured',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddFloorDialog(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFF6C63FF),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floors List
            Expanded(
              child: floors.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: floors.length,
                      itemBuilder: (context, index) {
                        return _buildFloorCard(
                          context,
                          floors[index],
                          floors.length,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No floors configured',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add floors for housekeepers to clean',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(BuildContext context, int floor, int totalFloors) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00B894),
      const Color(0xFFE17055),
      const Color(0xFF0984E3),
      const Color(0xFFFDAA22),
    ];
    final color = colors[floor % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$floor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Floor $floor',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Available for cleaning',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (totalFloors > 1)
            IconButton(
              onPressed: () => _showRemoveFloorDialog(context, floor),
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            ),
        ],
      ),
    );
  }

  void _showAddFloorDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 12),
            const Text('Add Floor'),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Floor Number',
            hintText: 'Enter floor number (0-50)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.layers_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final floorNum = int.tryParse(controller.text);
              if (floorNum == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                await floorService.addFloor(floorNum);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Floor $floorNum added successfully'),
                      backgroundColor: const Color(0xFF00B894),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRemoveFloorDialog(BuildContext context, int floor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Floor?'),
        content: Text(
          'Are you sure you want to remove Floor $floor? Housekeepers will no longer be able to select this floor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await floorService.removeFloor(floor);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Floor $floor removed'),
                      backgroundColor: const Color(0xFF00B894),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// Logs Tab
class _LogsTab extends StatefulWidget {
  final HousekeepingService housekeepingService;

  const _LogsTab({required this.housekeepingService});

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  String _filterStaff = 'all';
  int? _filterFloor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Logs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Staff', _filterStaff == 'all', () {
                      setState(() => _filterStaff = 'all');
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Floor ${_filterFloor ?? 'All'}',
                      _filterFloor != null,
                      () {
                        _showFloorFilterDialog();
                      },
                    ),
                    if (_filterFloor != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _filterFloor = null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Logs List
        Expanded(
          child: StreamBuilder<List<HousekeepingLog>>(
            stream: widget.housekeepingService.getAllLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              var logs = snapshot.data!;

              // Apply floor filter
              if (_filterFloor != null) {
                logs = logs.where((log) => log.floor == _filterFloor).toList();
              }

              if (logs.isEmpty) {
                return _buildEmptyState();
              }

              // Group by date
              final groupedLogs = <String, List<HousekeepingLog>>{};
              for (final log in logs) {
                final dateKey = DateFormat(
                  'yyyy-MM-dd',
                ).format(log.checkInTime);
                groupedLogs.putIfAbsent(dateKey, () => []).add(log);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groupedLogs.length,
                itemBuilder: (context, index) {
                  final dateKey = groupedLogs.keys.elementAt(index);
                  final dateLogs = groupedLogs[dateKey]!;
                  final date = DateTime.parse(dateKey);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _formatDateHeader(date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ...dateLogs.map((log) => _buildLogCard(log)),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  void _showFloorFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Filter by Floor'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<int>>(
            stream: FloorConfigService().getFloorsStream(),
            builder: (context, snapshot) {
              final floors = snapshot.data ?? [1, 2, 3, 4, 5];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: floors.map((floor) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => _filterFloor = floor);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _filterFloor == floor
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$floor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _filterFloor == floor
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No cleaning logs yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Cleaning activities will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(HousekeepingLog log) {
    final isComplete = log.checkOutTime != null;
    final duration = log.duration;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFF00B894).withOpacity(0.1)
                      : const Color(0xFFFDAA22).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${log.floor}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isComplete
                          ? const Color(0xFF00B894)
                          : const Color(0xFFFDAA22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Floor ${log.floor}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.staffName,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFF00B894).withOpacity(0.1)
                      : const Color(0xFFFDAA22).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isComplete ? 'Completed' : 'In Progress',
                  style: TextStyle(
                    color: isComplete
                        ? const Color(0xFF00B894)
                        : const Color(0xFFFDAA22),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Started',
                    TimeOfDay.fromDateTime(log.checkInTime).format(context),
                    Icons.play_circle_outline,
                    const Color(0xFF6C63FF),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildTimeInfo(
                    'Ended',
                    isComplete
                        ? TimeOfDay.fromDateTime(
                            log.checkOutTime!,
                          ).format(context)
                        : '--:--',
                    Icons.stop_circle_outlined,
                    isComplete ? const Color(0xFF00B894) : Colors.grey[400]!,
                  ),
                ),
                if (isComplete && duration != null) ...[
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildTimeInfo(
                      'Duration',
                      '${duration.inMinutes} min',
                      Icons.timer_outlined,
                      const Color(0xFF0984E3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }
}
