import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/models/notice_model.dart';
import 'package:hostelapp/models/machine_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/notice_service.dart';
import 'package:hostelapp/services/machine_service.dart';
import 'package:hostelapp/services/banner_service.dart';
import 'package:hostelapp/widgets/banner_carousel.dart';
import 'package:intl/intl.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> _onRefresh() async {
    // Trigger a rebuild by calling setState
    setState(() {});
    // Small delay to show the refresh indicator
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUserModel;
    final noticeService = Provider.of<NoticeService>(context);
    final bannerService = Provider.of<BannerService>(context);
    final machineService = Provider.of<MachineService>(context);

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Live Status
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live status
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'COMFORT PG LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Dashboard title
                  const Text(
                    'Dashboard',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Notice Board Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 18,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'NOTICE BOARD',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Notices List - Use getNotices() which doesn't require composite index
            StreamBuilder<List<Notice>>(
              stream: noticeService.getNotices(),
              builder: (context, snapshot) {
                // Handle loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Handle error state
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Error loading notices',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    ),
                  );
                }

                // Filter notices by residence if user has one
                var notices = snapshot.data ?? [];
                if (user?.residenceName != null) {
                  notices = notices
                      .where((n) => n.residenceName == user!.residenceName)
                      .toList();
                }
                notices = notices.take(3).toList();

                if (notices.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No notices yet',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  );
                }

                return Column(
                  children: notices
                      .map((notice) => _buildNoticeCard(notice))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Banner Carousel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<BannerImage>>(
                stream: bannerService.streamBanners(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Banner stream error: ${snapshot.error}');
                  }
                  final banners = snapshot.data ?? [];
                  return BannerCarousel(banners: banners, height: 180);
                },
              ),
            ),

            const SizedBox(height: 20),

            // Stats Row - Real-time machine status
            if (user?.residenceName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<Map<String, int>>(
                  stream: machineService.getMachineStats(user!.residenceName!),
                  builder: (context, snapshot) {
                    final stats =
                        snapshot.data ??
                        {'total': 0, 'busy': 0, 'available': 0};
                    final totalMachines = stats['total'] ?? 0;
                    final busyMachines = stats['busy'] ?? 0;
                    final availableMachines = stats['available'] ?? 0;
                    final freePercent = totalMachines > 0
                        ? ((availableMachines / totalMachines) * 100).round()
                        : 0;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'UNITS',
                            '$totalMachines',
                            Icons.local_laundry_service_outlined,
                            Colors.grey[100]!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'BUSY',
                            '$busyMachines',
                            Icons.pending_outlined,
                            busyMachines > 0
                                ? Colors.orange[50]!
                                : Colors.grey[100]!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'FREE',
                            '$freePercent%',
                            Icons.check_circle_outline,
                            availableMachines == totalMachines
                                ? Colors.green[50]!
                                : Colors.grey[100]!,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Machine List from Firestore
            if (user?.residenceName != null)
              StreamBuilder<List<Machine>>(
                stream: machineService.getMachinesByResidence(
                  user!.residenceName!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Error loading machines',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    );
                  }

                  final machines = snapshot.data ?? [];

                  if (machines.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Center(
                          child: Text(
                            'No machines available',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: machines
                          .map(
                            (machine) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMachineCard(machine),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showMachineBookingSheet(BuildContext context, Machine machine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MachineBookingSheet(machine: machine),
    );
  }

  Widget _buildNoticeCard(Notice notice) {
    Color priorityColor;
    Color priorityTextColor;
    String priorityText;

    switch (notice.priority) {
      case NoticePriority.high:
        priorityColor = Colors.red[600]!;
        priorityTextColor = Colors.white;
        priorityText = 'HIGH PRIORITY';
        break;
      case NoticePriority.medium:
        priorityColor = Colors.orange[600]!;
        priorityTextColor = Colors.white;
        priorityText = 'MEDIUM PRIORITY';
        break;
      case NoticePriority.low:
        priorityColor = Colors.blue[600]!;
        priorityTextColor = Colors.white;
        priorityText = 'LOW PRIORITY';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priorityText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: priorityTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd').format(notice.createdAt).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 10, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notice.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMachineCard(Machine machine) {
    final bool isAvailable = machine.status == MachineStatus.available;
    final bool isBusy = machine.status == MachineStatus.busy;
    final bool isMaintenance = machine.status == MachineStatus.maintenance;

    Color statusColor;
    String statusText;
    if (isAvailable) {
      statusColor = Colors.green;
      statusText = 'AVAILABLE';
    } else if (isBusy) {
      statusColor = Colors.orange;
      statusText = 'IN USE';
    } else {
      statusColor = Colors.red;
      statusText = 'MAINTENANCE';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Machine Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.blue[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_laundry_service,
                  color: isAvailable ? Colors.blue[700] : Colors.grey[500],
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              isBusy
                  ? 'In use by ${machine.currentUserName ?? 'someone'} (Room ${machine.currentRoomNo ?? 'N/A'})'
                  : isMaintenance
                  ? 'Under maintenance'
                  : 'Ready for use',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAvailable
                  ? () => _showMachineBookingSheet(context, machine)
                  : isBusy &&
                        machine.currentUserId ==
                            Provider.of<AuthService>(
                              context,
                              listen: false,
                            ).currentUser?.uid
                  ? () => _endSession(machine)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable
                    ? const Color(0xFF1a1a2e)
                    : isBusy &&
                          machine.currentUserId ==
                              Provider.of<AuthService>(
                                context,
                                listen: false,
                              ).currentUser?.uid
                    ? Colors.red[600]
                    : Colors.grey[300],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                isAvailable
                    ? 'BOOK SESSION'
                    : isBusy &&
                          machine.currentUserId ==
                              Provider.of<AuthService>(
                                context,
                                listen: false,
                              ).currentUser?.uid
                    ? 'END SESSION'
                    : 'NOT AVAILABLE',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _endSession(Machine machine) async {
    try {
      final machineService = Provider.of<MachineService>(
        context,
        listen: false,
      );
      await machineService.endSession(machine.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}

// Machine Booking Bottom Sheet
class MachineBookingSheet extends StatefulWidget {
  final Machine machine;

  const MachineBookingSheet({super.key, required this.machine});

  @override
  State<MachineBookingSheet> createState() => _MachineBookingSheetState();
}

class _MachineBookingSheetState extends State<MachineBookingSheet> {
  int _loadSize = 12;
  String _selectedProtocol = 'NORMAL';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _protocols = [
    {'name': 'QUICK', 'duration': '20m', 'temp': '30°C', 'icon': Icons.speed},
    {'name': 'NORMAL', 'duration': '45m', 'temp': '40°C', 'icon': Icons.waves},
    {
      'name': 'HEAVY',
      'duration': '60m',
      'temp': '60°C',
      'icon': Icons.water_drop,
    },
    {'name': 'DELICATES', 'duration': '35m', 'temp': '20°C', 'icon': Icons.air},
    {'name': 'BEDDING', 'duration': '75m', 'temp': '50°C', 'icon': Icons.bed},
  ];

  Future<void> _startSession() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final machineService = Provider.of<MachineService>(context, listen: false);
    final user = authService.currentUserModel;

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await machineService.startSession(
        machineId: widget.machine.id,
        userId: user.uid,
        userName: user.fullName,
        roomNo: user.roomNo ?? '',
        clothesCount: _loadSize,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session started: $_selectedProtocol cycle with $_loadSize items',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROTOCOL SETUP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.machine.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Load Size Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ESTIMATED LOAD SIZE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$_loadSize Items',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Load Size Slider
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_loadSize > 1) {
                        setState(() => _loadSize--);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.remove,
                        color: Colors.grey[700],
                        size: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue[700],
                        inactiveTrackColor: Colors.grey[200],
                        thumbColor: Colors.blue[700],
                        overlayColor: Colors.blue.withOpacity(0.1),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: _loadSize.toDouble(),
                        min: 1,
                        max: 30,
                        onChanged: (value) {
                          setState(() => _loadSize = value.round());
                        },
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_loadSize < 30) {
                        setState(() => _loadSize++);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: Colors.grey[700], size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Cycle Protocol Section
              Text(
                'CYCLE PROTOCOL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Protocol Grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _protocols.map((protocol) {
                  final isSelected = _selectedProtocol == protocol['name'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedProtocol = protocol['name']);
                    },
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 72) / 2,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue[700] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue[700]!
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            protocol['icon'],
                            size: 20,
                            color: isSelected ? Colors.white : Colors.grey[500],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                protocol['name'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${protocol['duration']} • ${protocol['temp']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Included Facility Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: Colors.blue[700],
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INCLUDED FACILITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Done Servicing ✅',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Start Session Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a1a2e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'START SESSION',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
