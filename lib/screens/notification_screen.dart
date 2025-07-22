// lib/screens/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/announcement_model.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/models/time_update_request_model.dart';
import 'package:hr_online/models/work_submission_model.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For groupBy
import 'dart:async'; // For Timer

// Enum สำหรับระบุคอลัมน์ที่ใช้เรียงลำดับ
enum _SortOption { latest, oldest, read, unread }

// Helper class to represent a single notification item
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Timestamp timestamp;
  bool isRead; // Added for read/unread status
  final VoidCallback? onTap; // Optional action when notification is tapped

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.isRead = false, // Default to unread
    this.onTap,
  });
}

class NotificationScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const NotificationScreen({super.key, required this.loggedInEmployee});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _allNotifications = [];
  List<NotificationItem> _displayedNotifications = [];
  bool _isLoading = true;

  // สำหรับการค้นหาและเรียงลำดับ
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  _SortOption _sortOption = _SortOption.latest; // Default sort option

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Debounce mechanism for search input
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _searchController.text.toLowerCase() != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
          _applyFiltersAndSort(); // Apply filter immediately after search query changes
        });
      }
    });
  }

  // Function to fetch and process all types of notifications
  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    List<NotificationItem> notifications = [];
    final employeeId = widget.loggedInEmployee.employeeId;
    final now = DateTime.now();
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // --- 1. Attendance Logs (Incomplete scans) ---
    final attendanceLogsSnapshot = await FirebaseFirestore.instance
        .collection('attendance_log')
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('date', descending: true)
        .get();

    for (var doc in attendanceLogsSnapshot.docs) {
      final log = AttendanceLog.fromFirestore(doc);
      String incompleteMessage = '';
      // Check for today's incomplete check-out
      if (log.checkIn != null && log.checkOut == null && log.date.toDate().day == now.day && log.date.toDate().month == now.month && log.date.toDate().year == now.year) {
        incompleteMessage = 'คุณยังไม่ได้สแกนออกงานสำหรับวันนี้';
      }
      // Check for today's incomplete break-in
      else if (log.breakOut != null && log.breakIn == null && log.date.toDate().day == now.day && log.date.toDate().month == now.month && log.date.toDate().year == now.year) {
        incompleteMessage = 'คุณยังไม่ได้สแกนเข้าพักสำหรับวันนี้';
      }
      // Check for past days' incomplete check-in (e.g., only check-out exists)
      else if (log.checkIn == null && log.checkOut != null && log.date.toDate().isBefore(DateTime(now.year, now.month, now.day))) {
        incompleteMessage = 'คุณไม่ได้สแกนเข้างานสำหรับวันที่ ${DateFormat('d MMM', 'th_TH').format(log.date.toDate())}';
      }
      // Check for past days' incomplete check-out (e.g., check-in exists but no check-out)
      else if (log.checkIn != null && log.checkOut == null && log.date.toDate().isBefore(DateTime(now.year, now.month, now.day))) {
        incompleteMessage = 'คุณยังไม่ได้สแกนออกงานสำหรับวันที่ ${DateFormat('d MMM', 'th_TH').format(log.date.toDate())}';
      }
      // Check for past days' incomplete break-in (e.g., break-out exists but no break-in)
      else if (log.breakOut != null && log.breakIn == null && log.date.toDate().isBefore(DateTime(now.year, now.month, now.day))) {
        incompleteMessage = 'คุณยังไม่ได้สแกนเข้าพักสำหรับวันที่ ${DateFormat('d MMM', 'th_TH').format(log.date.toDate())}';
      }


      if (incompleteMessage.isNotEmpty) {
        notifications.add(NotificationItem(
          id: 'attendance_incomplete_${log.id}',
          title: 'สแกนเวลาไม่สมบูรณ์',
          message: incompleteMessage,
          icon: Icons.warning_amber,
          color: Colors.orange,
          timestamp: log.date,
          onTap: () { /* Could navigate to attendance history */ },
        ));
      }
    }

    // --- 2. Leave Requests (Approved/Rejected) ---
    final leaveRequestsSnapshot = await FirebaseFirestore.instance
        .collection('leave_requests')
        .where('employeeId', isEqualTo: employeeId)
        .where('actionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('actionAt', descending: true)
        .get();

    for (var doc in leaveRequestsSnapshot.docs) {
      final leave = LeaveRequest.fromFirestore(doc);
      if (leave.status == 'approved' || leave.status == 'rejected') {
        notifications.add(NotificationItem(
          id: 'leave_${leave.id}',
          title: 'คำขอลางานของคุณ ${leave.status == 'approved' ? 'อนุมัติแล้ว' : 'ถูกปฏิเสธ'}',
          message: 'ประเภท: ${leave.leaveType}, วันที่: ${DateFormat('d MMM yyyy', 'th_TH').format(leave.startDate.toDate())}',
          icon: leave.status == 'approved' ? Icons.check_circle : Icons.cancel,
          color: leave.status == 'approved' ? Colors.green : Colors.red,
          timestamp: leave.actionAt ?? leave.requestedAt,
          onTap: () { /* Navigate to leave detail */ },
        ));
      }
    }

    // --- 3. Admin Announcements (Mentions) ---
    final announcementsSnapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .where('mentionedEmployeeId', isEqualTo: employeeId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in announcementsSnapshot.docs) {
      final announcement = Announcement.fromFirestore(doc);
      notifications.add(NotificationItem(
        id: 'announcement_mention_${announcement.id}',
        title: 'คุณถูกกล่าวถึงในประกาศ',
        message: announcement.text,
        icon: Icons.campaign,
        color: Colors.blue,
        timestamp: announcement.timestamp,
        onTap: () { /* Navigate to announcement screen */ },
      ));
    }

    // --- 4. Time Update Requests (Approved/Rejected) ---
    final timeUpdateRequestsSnapshot = await FirebaseFirestore.instance
        .collection('time_update_requests')
        .where('employeeId', isEqualTo: employeeId)
        .where('actionAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('actionAt', descending: true)
        .get();

    for (var doc in timeUpdateRequestsSnapshot.docs) {
      final request = TimeUpdateRequest.fromFirestore(doc);
      if (request.status == 'approved' || request.status == 'rejected') {
        notifications.add(NotificationItem(
          id: 'time_update_status_${request.id}',
          title: 'คำขอแก้ไขเวลาของคุณ ${request.status == 'approved' ? 'อนุมัติแล้ว' : 'ถูกปฏิเสธ'}',
          message: 'วันที่: ${DateFormat('d MMM yyyy', 'th_TH').format(request.requestedDate.toDate())}, เวลา: ${request.requestedTime}',
          icon: request.status == 'approved' ? Icons.check_circle : Icons.cancel,
          color: request.status == 'approved' ? Colors.green : Colors.red,
          timestamp: request.actionAt ?? request.requestedAt,
          onTap: () { /* Navigate to time update detail */ },
        ));
      }
    }

    // --- 5. Quiz Assignments (Pending) ---
    final quizAssignmentsSnapshot = await FirebaseFirestore.instance
        .collection('quiz_assignments')
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'pending') // Only show pending quizzes as notifications
        .where('assignedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('assignedAt', descending: true)
        .get();

    for (var doc in quizAssignmentsSnapshot.docs) {
      final assignment = QuizAssignment.fromFirestore(doc);
      final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(assignment.quizId).get();
      if (quizDoc.exists) {
        final quiz = Quiz.fromFirestore(quizDoc, []); // Pass empty questions list as it's not needed here
        notifications.add(NotificationItem(
          id: 'quiz_assignment_${assignment.id}',
          title: 'คุณมีแบบทดสอบใหม่ที่ต้องทำ',
          message: 'แบบทดสอบ: ${quiz.title}',
          icon: Icons.quiz,
          color: Colors.purple,
          timestamp: assignment.assignedAt ?? Timestamp.now(),
          onTap: () { /* Navigate to quiz taking screen */ },
        ));
      }
    }

    // --- 6. Work Submissions (Tagged) ---
    final workSubmissionsSnapshot = await FirebaseFirestore.instance
        .collection('work_submissions')
        .where('taggedEmployees', arrayContains: {'id': employeeId}) // This requires a composite index
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in workSubmissionsSnapshot.docs) {
      final submission = WorkSubmission.fromFirestore(doc);
      notifications.add(NotificationItem(
        id: 'work_submission_tagged_${submission.id}',
        title: 'คุณถูกแท็กในรายงานการทำงาน',
        message: 'เรื่อง: ${submission.title} โดย ${submission.authorNickname}',
        icon: Icons.alternate_email,
        color: Colors.teal,
        timestamp: submission.timestamp,
        onTap: () { /* Navigate to work submission detail */ },
      ));
    }

    if (mounted) {
      setState(() {
        _allNotifications = notifications;
        _applyFiltersAndSort(); // Apply initial filter and sort
        _isLoading = false;
      });
    }
  }

  // Apply filters (search) and sorting based on current state
  void _applyFiltersAndSort() {
    List<NotificationItem> filtered = _allNotifications.where((notification) {
      final query = _searchQuery.toLowerCase();
      return notification.title.toLowerCase().contains(query) ||
             notification.message.toLowerCase().contains(query);
    }).toList();

    // Sort based on selected option
    filtered.sort((a, b) {
      int compareResult = 0;
      switch (_sortOption) {
        case _SortOption.latest:
          compareResult = b.timestamp.compareTo(a.timestamp); // Newest first
          break;
        case _SortOption.oldest:
          compareResult = a.timestamp.compareTo(b.timestamp); // Oldest first
          break;
        case _SortOption.read:
          // Read notifications come first, then sort by latest timestamp
          if (a.isRead && !b.isRead) return -1;
          if (!a.isRead && b.isRead) return 1;
          compareResult = b.timestamp.compareTo(a.timestamp);
          break;
        case _SortOption.unread:
          // Unread notifications come first, then sort by latest timestamp
          if (!a.isRead && b.isRead) return -1;
          if (a.isRead && !b.isRead) return 1;
          compareResult = b.timestamp.compareTo(a.timestamp);
          break;
      }
      return compareResult;
    });

    setState(() {
      _displayedNotifications = filtered;
    });
  }

  // Toggle read status of a notification
  void _toggleReadStatus(String notificationId) {
    setState(() {
      final index = _allNotifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _allNotifications[index].isRead = !_allNotifications[index].isRead;
        _applyFiltersAndSort(); // Re-apply filters and sort to reflect changes
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      // --- [START] FIXED BUG: Pass actual isAdmin status ---
      isUserAdmin: widget.loggedInEmployee.isAdmin,
      // --- [END] FIXED BUG ---
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'การแจ้งเตือน',
      showBackButton: true,
      bodySlivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาการแจ้งเตือน...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<_SortOption>(
                      initialValue: _sortOption,
                      onSelected: (_SortOption newValue) {
                        setState(() {
                          _sortOption = newValue;
                          _applyFiltersAndSort(); // Re-apply sort
                        });
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<_SortOption>>[
                        const PopupMenuItem<_SortOption>(
                          value: _SortOption.latest,
                          child: Text('ล่าสุด'),
                        ),
                        const PopupMenuItem<_SortOption>(
                          value: _SortOption.oldest,
                          child: Text('เก่าที่สุด'),
                        ),
                        const PopupMenuItem<_SortOption>(
                          value: _SortOption.read,
                          child: Text('อ่านแล้ว'),
                        ),
                        const PopupMenuItem<_SortOption>(
                          value: _SortOption.unread,
                          child: Text('ยังไม่อ่าน'),
                        ),
                      ],
                      icon: const Icon(Icons.sort, color: Colors.white),
                      tooltip: 'จัดเรียงข้อมูล',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _isLoading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              )
            : _displayedNotifications.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('ไม่มีการแจ้งเตือน', style: GoogleFonts.anuphan(color: Colors.white70)),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notification = _displayedNotifications[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: notification.isRead ? Colors.grey.shade100 : Colors.white, // Grey if read
                          child: ListTile(
                            leading: Icon(notification.icon, color: notification.color, size: 30),
                            title: Text(notification.title, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${notification.message}\n${DateFormat('d MMM yy, HH:mm', 'th_TH').format(notification.timestamp.toDate())}',
                              style: GoogleFonts.anuphan(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: Icon(
                                notification.isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                                color: notification.isRead ? Colors.grey : Theme.of(context).primaryColor,
                              ),
                              onPressed: () => _toggleReadStatus(notification.id),
                              tooltip: notification.isRead ? 'ทำเครื่องหมายว่ายังไม่อ่าน' : 'ทำเครื่องหมายว่าอ่านแล้ว',
                            ),
                            onTap: notification.onTap,
                          ),
                        );
                      },
                      childCount: _displayedNotifications.length,
                    ),
                  ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)), // Add space for FAB
      ],
    );
  }
}
