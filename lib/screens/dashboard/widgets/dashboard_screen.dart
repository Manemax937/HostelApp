import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/models/notice_model.dart';
import 'package:hostelapp/models/machine_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/notice_service.dart';
import 'package:hostelapp/services/machine_service.dart';
import 'package:hostelapp/services/banner_service.dart';
import 'package:hostelapp/widgets/banner_carousel.dart';
import 'package:hostelapp/screens/dashboard/widgets/banner_management_screen.dart';
import 'package:hostelapp/utils/app_theme.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> _onRefresh() async {
    setState(() {});
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
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.home,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Comfort PG',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),

            // Dashboard Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),

            // Notice Board
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                  if (user?.role == UserRole.admin ||
                      user?.role == UserRole.owner)
                    TextButton.icon(
                      onPressed: () => _showAddNoticeDialog(context),
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      label: Text(
                        'NEW POST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Notices List - Use getNotices() to avoid composite index requirement
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
                notices = notices.take(5).toList();

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
                      .map((notice) => _buildNoticeCard(notice, user))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Stats Row - Real-time machine status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<Map<String, int>>(
                stream: machineService.getMachineStats(
                  user?.residenceName ?? 'Comfort PG',
                ),
                builder: (context, snapshot) {
                  final stats =
                      snapshot.data ?? {'total': 0, 'busy': 0, 'available': 0};
                  final totalMachines = stats['total'] ?? 0;
                  final busyMachines = stats['busy'] ?? 0;
                  final availableMachines = stats['available'] ?? 0;
                  final activePercent = totalMachines > 0
                      ? ((availableMachines / totalMachines) * 100).round()
                      : 0;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'UNITS',
                          '$totalMachines',
                          Icons.apartment_outlined,
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
                          'ACTIVE',
                          '$activePercent%',
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

            // Banner Carousel Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BANNERS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BannerManagementScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Manage'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<BannerImage>>(
                    stream: bannerService.streamBanners(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint('Banner stream error: ${snapshot.error}');
                      }
                      final banners = snapshot.data ?? [];
                      return BannerCarousel(banners: banners, height: 180);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Machines Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_laundry_service_outlined,
                        size: 18,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MACHINES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMachineDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'ADD MACHINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a1a2e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Machines List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<Machine>>(
                stream: machineService.getMachinesByResidence(
                  user?.residenceName ?? 'Comfort PG',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final machines = snapshot.data ?? [];

                  if (machines.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_laundry_service_outlined,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No machines added yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "ADD MACHINE" to add your first machine',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: machines.asMap().entries.map((entry) {
                      final index = entry.key;
                      final machine = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < machines.length - 1 ? 12 : 0,
                        ),
                        child: _buildOwnerMachineCard(machine),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddMachineDialog(BuildContext context) {
    final nameController = TextEditingController();
    final user = Provider.of<AuthService>(
      context,
      listen: false,
    ).currentUserModel;
    final machineService = Provider.of<MachineService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Machine',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.grey[600], size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Machine Name
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Machine Name',
                hintText: 'e.g., Machine 3',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter a machine name'),
                        backgroundColor: Colors.orange[700],
                      ),
                    );
                    return;
                  }

                  // Use default residence name if not set
                  final residenceName = user?.residenceName ?? 'Comfort PG';

                  try {
                    await machineService.addMachine(
                      name: nameController.text.trim(),
                      residenceName: residenceName,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${nameController.text.trim()} added successfully',
                        ),
                        backgroundColor: Colors.green[700],
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding machine: $e'),
                        backgroundColor: Colors.red[700],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a1a2e),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'ADD MACHINE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMachineDialog(BuildContext context, Machine machine) {
    final nameController = TextEditingController(text: machine.name);
    MachineStatus status = machine.status;
    final machineService = Provider.of<MachineService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Machine',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 24),
              // Machine Name
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Machine Name',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Status Dropdown
              Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    [
                      {'label': 'AVAILABLE', 'status': MachineStatus.available},
                      {'label': 'IN USE', 'status': MachineStatus.busy},
                      {
                        'label': 'MAINTENANCE',
                        'status': MachineStatus.maintenance,
                      },
                    ].map((s) {
                      final isSelected = status == s['status'];
                      final label = s['label'] as String;
                      return GestureDetector(
                        onTap: () => setModalState(
                          () => status = s['status'] as MachineStatus,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (s['status'] == MachineStatus.available
                                      ? Colors.green[700]
                                      : s['status'] == MachineStatus.busy
                                      ? Colors.orange[700]
                                      : Colors.red[700])
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      try {
                        await machineService.updateMachine(
                          machineId: machine.id,
                          name: nameController.text,
                          status: status,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Machine updated successfully'),
                            backgroundColor: Colors.green[700],
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating machine: $e'),
                            backgroundColor: Colors.red[700],
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a1a2e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'SAVE CHANGES',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteMachine(Machine machine) {
    final machineService = Provider.of<MachineService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Machine'),
        content: Text('Are you sure you want to delete ${machine.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await machineService.deleteMachine(machine.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Machine deleted'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting machine: $e'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerMachineCard(Machine machine) {
    String statusText;
    Color statusColor;
    Color statusBgColor;

    switch (machine.status) {
      case MachineStatus.available:
        statusText = 'AVAILABLE';
        statusColor = Colors.green[700]!;
        statusBgColor = Colors.green[50]!;
        break;
      case MachineStatus.busy:
        statusText = 'IN USE';
        statusColor = Colors.orange[700]!;
        statusBgColor = Colors.orange[50]!;
        break;
      case MachineStatus.maintenance:
        statusText = 'MAINTENANCE';
        statusColor = Colors.red[700]!;
        statusBgColor = Colors.red[50]!;
        break;
    }

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_laundry_service,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machine.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${machine.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
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
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditMachineDialog(context, machine);
                      } else if (value == 'delete') {
                        _deleteMachine(machine);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (machine.isBusy && machine.currentUserName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${machine.currentUserName} (Room ${machine.currentRoomNo ?? "N/A"}) - ${machine.clothesCount ?? 0} clothes',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeCard(Notice notice, UserModel? currentUser) {
    Color priorityColor;
    String priorityText;

    switch (notice.priority) {
      case NoticePriority.high:
        priorityColor = Colors.red[50]!;
        priorityText = 'HIGH PRIORITY';
        break;
      case NoticePriority.medium:
        priorityColor = Colors.orange[50]!;
        priorityText = 'MEDIUM PRIORITY';
        break;
      case NoticePriority.low:
        priorityColor = Colors.blue[50]!;
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
                    color: notice.priority == NoticePriority.high
                        ? Colors.red[700]
                        : notice.priority == NoticePriority.medium
                        ? Colors.orange[700]
                        : Colors.blue[700],
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
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 10, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          notice.createdByName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Delete button for owner/admin
              if (currentUser?.role == UserRole.owner ||
                  currentUser?.role == UserRole.admin)
                IconButton(
                  onPressed: () => _showDeleteNoticeDialog(context, notice),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red[400],
                  ),
                  padding: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(),
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showDeleteNoticeDialog(BuildContext context, Notice notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text('Are you sure you want to delete "${notice.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final noticeService = Provider.of<NoticeService>(
                context,
                listen: false,
              );
              await noticeService.deleteNotice(notice.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddNoticeDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    NoticePriority priority = NoticePriority.medium;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Notice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NoticePriority>(
                  value: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: NoticePriority.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.toString().split('.').last.toUpperCase(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => priority = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    descController.text.isNotEmpty) {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  final noticeService = Provider.of<NoticeService>(
                    context,
                    listen: false,
                  );

                  await noticeService.createNotice(
                    title: titleController.text,
                    description: descController.text,
                    priority: priority,
                    createdBy: authService.currentUser!.uid,
                    createdByName: authService.currentUserModel!.fullName,
                    residenceName: authService.currentUserModel!.residenceName,
                  );

                  Navigator.pop(context);
                }
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
