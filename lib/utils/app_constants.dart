class AppConstants {
  // App Info
  static const String appName = 'Comfort PG';
  static const String appSubtitle = 'RESIDENT OPERATING SYSTEM';

  // Washing Machines
  static const int totalMachines = 2;
  static const List<String> machineIds = ['Machine-1', 'Machine-2'];

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String paymentsCollection = 'payments';
  static const String washingMachinesCollection = 'washing_machines';
  static const String complaintsCollection = 'complaints';
  static const String housekeepingCollection = 'housekeeping_logs';
  static const String notificationsCollection = 'notifications';
  static const String pgAttendanceCollection = 'pg_attendance';
  static const String pgLocationsCollection = 'pg_locations';
  static const String noticesCollection = 'notices';

  // Storage Paths
  static const String paymentScreenshotsPath = 'payment_screenshots';
  static const String complaintPhotosPath = 'complaint_photos';

  // Notification Topics
  static const String adminTopic = 'admin_notifications';
  static const String allUsersTopic = 'all_users';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxRoomNoLength = 10;
  static const int maxFloorNumber = 20;

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String monthYearFormat = 'MMM yyyy';
}
