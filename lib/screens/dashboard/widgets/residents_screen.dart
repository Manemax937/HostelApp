import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostelapp/models/user_model.dart';
import 'package:hostelapp/models/payment_model.dart';
import 'package:hostelapp/services/auth_service.dart';
import 'package:hostelapp/services/payment_service.dart';
import 'package:intl/intl.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, paid, unpaid, pending

  String get _currentMonth => DateFormat('MMM yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    final currentUser = authService.currentUserModel;
    final residenceName = currentUser?.residenceName ?? 'Comfort PG';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            const Text(
              'Resident Directory',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'MASTER TENANT RECORDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by name or room...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', Colors.blue),
                  const SizedBox(width: 8),
                  _buildFilterChip('Paid', 'paid', Colors.green),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending', Colors.orange),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unpaid', 'unpaid', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Month indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Rent status for $_currentMonth',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Residents List
            StreamBuilder<List<UserModel>>(
              stream: authService.getUsersByRole(UserRole.student),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!userSnapshot.hasData || userSnapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No residents found',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Filter users by residence
                final allUsers = userSnapshot.data!
                    .where(
                      (u) => u.residenceName == residenceName && u.isActive,
                    )
                    .toList();

                // Apply search filter
                final filteredBySearch = allUsers.where((user) {
                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery.toLowerCase();
                  return user.fullName.toLowerCase().contains(query) ||
                      (user.roomNo?.toLowerCase().contains(query) ?? false) ||
                      (user.email.toLowerCase().contains(query));
                }).toList();

                // Sort by room number
                filteredBySearch.sort((a, b) {
                  final aRoom = a.roomNo ?? 'ZZZ';
                  final bRoom = b.roomNo ?? 'ZZZ';
                  return aRoom.compareTo(bRoom);
                });

                return StreamBuilder<List<PaymentModel>>(
                  stream: paymentService.getAllPayments(),
                  builder: (context, paymentSnapshot) {
                    final payments = paymentSnapshot.data ?? [];

                    // Get payment status for each user for current month
                    Map<String, PaymentModel?> userPayments = {};
                    for (var user in filteredBySearch) {
                      final userMonthPayments = payments
                          .where(
                            (p) =>
                                p.userId == user.uid &&
                                p.month == _currentMonth,
                          )
                          .toList();
                      userPayments[user.uid] = userMonthPayments.isNotEmpty
                          ? userMonthPayments.first
                          : null;
                    }

                    // Apply payment filter
                    final filteredUsers = filteredBySearch.where((user) {
                      if (_filterStatus == 'all') return true;
                      final payment = userPayments[user.uid];
                      if (_filterStatus == 'paid') {
                        return payment != null &&
                            payment.status == PaymentStatus.verified;
                      } else if (_filterStatus == 'pending') {
                        return payment != null &&
                            payment.status == PaymentStatus.pending;
                      } else if (_filterStatus == 'unpaid') {
                        return payment == null ||
                            payment.status == PaymentStatus.rejected;
                      }
                      return true;
                    }).toList();

                    // Count stats
                    final paidCount = filteredBySearch.where((user) {
                      final payment = userPayments[user.uid];
                      return payment != null &&
                          payment.status == PaymentStatus.verified;
                    }).length;
                    final pendingCount = filteredBySearch.where((user) {
                      final payment = userPayments[user.uid];
                      return payment != null &&
                          payment.status == PaymentStatus.pending;
                    }).length;
                    final unpaidCount =
                        filteredBySearch.length - paidCount - pendingCount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Row
                        Row(
                          children: [
                            _buildStatBadge(
                              '${filteredBySearch.length}',
                              'Total',
                              Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _buildStatBadge('$paidCount', 'Paid', Colors.green),
                            const SizedBox(width: 8),
                            _buildStatBadge(
                              '$pendingCount',
                              'Pending',
                              Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _buildStatBadge(
                              '$unpaidCount',
                              'Unpaid',
                              Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section header
                        Text(
                          'VERIFIED RESIDENTS (${filteredUsers.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Resident Cards
                        ...filteredUsers.map((user) {
                          final payment = userPayments[user.uid];
                          return _buildResidentCard(user, payment);
                        }),

                        if (filteredUsers.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.filter_list_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No residents match the filter',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _filterStatus == value;

    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? color : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResidentCard(UserModel user, PaymentModel? payment) {
    final isPaid = payment != null && payment.status == PaymentStatus.verified;
    final isPending =
        payment != null && payment.status == PaymentStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPaid
                        ? [Colors.green[400]!, Colors.green[600]!]
                        : isPending
                        ? [Colors.orange[400]!, Colors.orange[600]!]
                        : [Colors.grey[400]!, Colors.grey[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name and Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Payment Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green[100]
                                : isPending
                                ? Colors.orange[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isPaid
                                ? 'PAID'
                                : isPending
                                ? 'PENDING'
                                : 'UNPAID',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: isPaid
                                  ? Colors.green[700]
                                  : isPending
                                  ? Colors.orange[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Room and Floor Tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (user.roomNo != null)
                          _buildTag(
                            Icons.door_front_door_outlined,
                            'Room ${user.roomNo}',
                          ),
                        if (user.floor != null)
                          _buildTag(
                            Icons.layers_outlined,
                            'Floor ${user.floor}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                onSelected: (value) => _handleAction(value, user, payment),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18),
                        SizedBox(width: 8),
                        Text('View Profile'),
                      ],
                    ),
                  ),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    const PopupMenuItem(
                      value: 'call',
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Call'),
                        ],
                      ),
                    ),
                  if (payment != null &&
                      payment.status == PaymentStatus.pending)
                    const PopupMenuItem(
                      value: 'verify_payment',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text('Verify Payment'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Contact Details
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.email_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user.email,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  Container(
                    height: 14,
                    width: 1,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    user.phone!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // Payment Details (if exists)
          if (payment != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isPaid ? Icons.check_circle : Icons.access_time,
                    size: 16,
                    color: isPaid ? Colors.green[600] : Colors.orange[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPaid
                          ? 'Paid ₹${payment.amount.toStringAsFixed(0)} on ${DateFormat('MMM dd').format(payment.submittedAt)}'
                          : 'Payment of ₹${payment.amount.toStringAsFixed(0)} pending verification',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPaid ? Colors.green[700] : Colors.orange[700],
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

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(String action, UserModel user, PaymentModel? payment) {
    switch (action) {
      case 'view':
        _showUserDetailsDialog(user, payment);
        break;
      case 'call':
        if (user.phone != null && user.phone!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Calling ${user.phone}...')));
        }
        break;
      case 'verify_payment':
        if (payment != null) {
          _verifyPayment(payment);
        }
        break;
    }
  }

  void _showUserDetailsDialog(UserModel user, PaymentModel? payment) {
    final isPaid = payment != null && payment.status == PaymentStatus.verified;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(fontSize: 16)),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'RENT PAID' : 'RENT DUE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(Icons.email_outlined, 'Email', user.email),
              if (user.phone != null && user.phone!.isNotEmpty)
                _buildDetailRow(Icons.phone_outlined, 'Phone', user.phone!),
              if (user.roomNo != null)
                _buildDetailRow(
                  Icons.door_front_door_outlined,
                  'Room',
                  user.roomNo!,
                ),
              if (user.floor != null)
                _buildDetailRow(
                  Icons.layers_outlined,
                  'Floor',
                  '${user.floor}',
                ),
              _buildDetailRow(
                Icons.calendar_today_outlined,
                'Joined',
                DateFormat('MMM dd, yyyy').format(user.createdAt),
              ),
              if (payment != null) ...[
                const Divider(height: 24),
                Text(
                  'PAYMENT DETAILS ($_currentMonth)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.money_outlined,
                  'Amount',
                  '₹${payment.amount.toStringAsFixed(0)}',
                ),
                _buildDetailRow(
                  Icons.receipt_outlined,
                  'Transaction ID',
                  payment.transactionId,
                ),
                _buildDetailRow(
                  Icons.calendar_today_outlined,
                  'Submitted',
                  DateFormat('MMM dd, yyyy').format(payment.submittedAt),
                ),
                _buildDetailRow(
                  Icons.info_outline,
                  'Status',
                  payment.status == PaymentStatus.verified
                      ? 'Verified'
                      : payment.status == PaymentStatus.pending
                      ? 'Pending'
                      : 'Rejected',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (payment != null && payment.status == PaymentStatus.pending)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verifyPayment(payment);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Verify Payment',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _verifyPayment(PaymentModel payment) {
    final paymentService = Provider.of<PaymentService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Payment'),
        content: Text(
          'Verify payment of ₹${payment.amount.toStringAsFixed(0)} from ${payment.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await paymentService.updatePaymentStatus(
                paymentId: payment.id,
                status: PaymentStatus.verified,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Payment verified successfully!'),
                    backgroundColor: Colors.green[700],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
