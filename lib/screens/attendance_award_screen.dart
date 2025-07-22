// lib/screens/attendance_award_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/models/work_submission_model.dart'; // Import WorkSubmissionModel
import 'package:hr_online/widgets/app_layout.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For groupBy
import 'dart:async'; // Import for Timer

// Enum สำหรับระบุคอลัมน์ที่ใช้เรียงลำดับ
enum _SortColumn { finalScore, workSubmissionsCount, totalWorkDuration, absentDays, lateDaysCount }

// Helper class to store calculated stats for each employee
class EmployeeAttendanceStat {
  final Employee employee;
  final Duration totalWorkDuration;
  final int absentDays; // Days without check-in (including approved leaves)
  final int lateDaysCount; // Count of days employee was late
  final int workSubmissionsCount; // Number of days with work submissions
  final int finalScore; // Total calculated score

  EmployeeAttendanceStat({
    required this.employee,
    required this.totalWorkDuration,
    required this.absentDays,
    required this.lateDaysCount,
    required this.workSubmissionsCount,
    required this.finalScore,
  });
}

class AttendanceAwardScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const AttendanceAwardScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<AttendanceAwardScreen> createState() => _AttendanceAwardScreenState();
}

class _AttendanceAwardScreenState extends State<AttendanceAwardScreen> {
  Future<List<EmployeeAttendanceStat>>? _rankingDataFuture;
  
  // State สำหรับการค้นหาและเรียงลำดับ
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  _SortColumn _sortColumn = _SortColumn.finalScore; // Default sort column
  bool _sortAscending = false; // Default sort order (descending for score)

  @override
  void initState() {
    super.initState();
    _rankingDataFuture = _fetchAndProcessRankingData();
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
        });
      }
    });
  }

  // Fetches and processes all necessary data to calculate rankings
  Future<List<EmployeeAttendanceStat>> _fetchAndProcessRankingData() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Fetch all necessary data in parallel
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').get(),
      FirebaseFirestore.instance.collection('work_shifts').get(),
      FirebaseFirestore.instance
          .collection('attendance_log')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
          .get(),
      FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'approved')
          .get(),
      FirebaseFirestore.instance
          .collection('work_submissions')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfMonth))
          .get(),
    ]);

    final employees = (results[0] as QuerySnapshot).docs.map((doc) => Employee.fromFirestore(doc)).toList();
    final allShifts = (results[1] as QuerySnapshot).docs.map((doc) => WorkShift.fromFirestore(doc)).toList();
    final allLogsForMonth = (results[2] as QuerySnapshot).docs.map((doc) => AttendanceLog.fromFirestore(doc)).toList();
    final allApprovedLeaves = (results[3] as QuerySnapshot).docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList();
    final allWorkSubmissions = (results[4] as QuerySnapshot).docs.map((doc) => WorkSubmission.fromFirestore(doc)).toList();

    // Filter approved leaves to only include those relevant to the current month.
    final allLeaveRequests = allApprovedLeaves.where((req) {
        final reqStartDate = req.startDate.toDate();
        final reqEndDate = req.endDate.toDate();
        return reqStartDate.isBefore(lastDayOfMonth) && reqEndDate.isAfter(firstDayOfMonth);
    }).toList();

    // Group data for easier lookup
    final logsByEmployeeAndDate = { for (var log in allLogsForMonth) '${log.employeeId}_${DateFormat('yyyy-MM-dd').format(log.date.toDate())}': log };
    final leavesByEmployee = groupBy(allLeaveRequests, (LeaveRequest req) => req.employeeId);
    final workSubmissionsByEmployeeAndDate = groupBy(allWorkSubmissions, (WorkSubmission sub) => '${sub.authorId}_${DateFormat('yyyy-MM-dd').format(sub.timestamp.toDate())}');

    List<EmployeeAttendanceStat> allStats = [];

    // Iterate through each employee to calculate their stats for the month
    for (final employee in employees) {
      Duration totalWorkDuration = Duration.zero;
      int absentDays = 0; // Days without check-in (including approved leaves)
      int lateDaysCount = 0; // Number of days employee was late
      int workSubmissionsCount = 0; // Number of days with work submissions
      int employeeFinalScore = 0; // Total calculated score for the employee

      final employeeLeaves = leavesByEmployee[employee.employeeId] ?? [];

      // Iterate through each day of the month
      for (int day = 1; day <= lastDayOfMonth.day; day++) {
        final currentDate = DateTime(now.year, now.month, day);
        final dayKey = DateFormat('EEEE').format(currentDate);
        final shiftId = employee.dailyWorkShifts[dayKey];

        // Only process workdays (days with a defined work shift)
        if (shiftId != null && shiftId.isNotEmpty) {
          final logKey = '${employee.employeeId}_${DateFormat('yyyy-MM-dd').format(currentDate)}';
          final log = logsByEmployeeAndDate[logKey];

          // Check if the employee was on approved leave for this day
          final isOnApprovedLeave = employeeLeaves.any((leave) =>
              (currentDate.isAfter(leave.startDate.toDate()) || currentDate.isAtSameMomentAs(leave.startDate.toDate())) &&
              (currentDate.isBefore(leave.endDate.toDate()) || currentDate.isAtSameMomentAs(leave.endDate.toDate()))
          );

          // Logic for Absent Days and Late Days
          if (log == null) { // No attendance log for this workday
            absentDays++; // Count as absent
            employeeFinalScore -= 2; // -2 points for each absent day
          } else { // Has an attendance log for this workday
            final calc = _calculateDurations(log, employee, allShifts);
            totalWorkDuration += calc['workDuration']! + calc['otDuration']!;
            
            // If employee was late for this day
            if (calc['lateDuration']!.inMinutes > 0) {
              lateDaysCount++; // Count as a late day
              employeeFinalScore -= 1; // -1 point for each late day
            }
          }
        }

        // Calculate Work Submissions score
        final submissionKey = '${employee.employeeId}_${DateFormat('yyyy-MM-dd').format(currentDate)}';
        final submissionsForDay = workSubmissionsByEmployeeAndDate[submissionKey] ?? [];
        if (submissionsForDay.isNotEmpty) {
          workSubmissionsCount++; // Count as 1 day of submission
          employeeFinalScore += 3; // +3 points for each day with a work submission
        }
      }

      // Add the calculated stats for the employee
      allStats.add(EmployeeAttendanceStat(
        employee: employee,
        totalWorkDuration: totalWorkDuration,
        absentDays: absentDays,
        lateDaysCount: lateDaysCount,
        workSubmissionsCount: workSubmissionsCount,
        finalScore: employeeFinalScore,
      ));
    }

    // Sort all employees by their final score in descending order
    allStats.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    return allStats;
  }

  // Helper function to calculate work, OT, and late durations from an attendance log
  Map<String, Duration> _calculateDurations(AttendanceLog log, Employee employee, List<WorkShift> allShifts) {
    final logDate = log.date.toDate();
    final dayOfWeek = DateFormat('EEEE').format(logDate);
    final shiftId = employee.dailyWorkShifts[dayOfWeek];
    final workShift = allShifts.firstWhereOrNull((s) => s.id == shiftId);

    Duration workDuration = Duration.zero;
    Duration otDuration = Duration.zero;
    Duration lateDuration = Duration.zero;

    if (workShift != null) {
      try {
        final startParts = workShift.startTime.split(':');
        final endParts = workShift.endTime.split(':');
        final scheduledCheckIn = DateTime(logDate.year, logDate.month, logDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
        var scheduledCheckOut = DateTime(logDate.year, logDate.month, logDate.day, int.parse(endParts[0]), int.parse(endParts[1]));
        // Adjust scheduledCheckOut if it spans to the next day
        if (scheduledCheckOut.isBefore(scheduledCheckIn)) {
            scheduledCheckOut = scheduledCheckOut.add(const Duration(days: 1));
        }

        final actualCheckIn = log.checkIn?.toDate();
        final actualCheckOut = log.checkOut?.toDate();

        if (actualCheckIn != null) {
          // Calculate Late Duration (if check-in is after scheduled start by more than 1 minute)
          if (actualCheckIn.isAfter(scheduledCheckIn.add(const Duration(minutes: 1)))) {
            lateDuration = actualCheckIn.difference(scheduledCheckIn);
          }

          if (actualCheckOut != null) {
            Duration total = actualCheckOut.difference(actualCheckIn);
            if (total.isNegative) total = Duration.zero;

            final overlapStart = actualCheckIn.isAfter(scheduledCheckIn) ? actualCheckIn : scheduledCheckIn;
            final overlapEnd = actualCheckOut.isBefore(scheduledCheckOut) ? actualCheckOut : scheduledCheckOut;
            
            if (overlapEnd.isAfter(overlapStart)) {
                workDuration = overlapEnd.difference(overlapStart);
            }

            otDuration = total - workDuration;
            if (otDuration.isNegative) otDuration = Duration.zero;
          }
        }
      } catch (e) { /* Ignore parsing errors */ }
    }
    return {'workDuration': workDuration, 'otDuration': otDuration, 'lateDuration': lateDuration};
  }
  
  // Helper to format duration into "Xชม.Yน."
  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '-';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return "${hours}ชม.${minutes}น.";
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM('th_TH').format(DateTime.now());

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'ตารางอันดับพนักงาน',
      showBackButton: false,
      bodySlivers: [
         SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'ประจำเดือน $monthName',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(fontSize: 18, color: Colors.white70),
            ),
          ),
        ),
        FutureBuilder<List<EmployeeAttendanceStat>>(
          future: _rankingDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white)));
            }
            if (snapshot.hasError) {
              return SliverFillRemaining(child: Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: const TextStyle(color: Colors.white))));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SliverFillRemaining(child: Center(child: Text('ไม่มีข้อมูลสำหรับจัดอันดับ', style: TextStyle(color: Colors.white))));
            }

            // กรองและเรียงลำดับข้อมูล
            var rankings = snapshot.data!;
            final filteredRankings = rankings.where((stat) {
              final query = _searchQuery.toLowerCase();
              return stat.employee.employeeId.toLowerCase().contains(query) ||
                     stat.employee.nickname.toLowerCase().contains(query);
            }).toList();

            // เรียงลำดับตามที่เลือก
            filteredRankings.sort((a, b) {
              int compareResult = 0;
              switch (_sortColumn) {
                case _SortColumn.finalScore:
                  compareResult = a.finalScore.compareTo(b.finalScore);
                  break;
                case _SortColumn.workSubmissionsCount:
                  compareResult = a.workSubmissionsCount.compareTo(b.workSubmissionsCount);
                  break;
                case _SortColumn.totalWorkDuration:
                  compareResult = a.totalWorkDuration.compareTo(b.totalWorkDuration);
                  break;
                case _SortColumn.absentDays:
                  compareResult = a.absentDays.compareTo(b.absentDays);
                  break;
                case _SortColumn.lateDaysCount:
                  compareResult = a.lateDaysCount.compareTo(b.lateDaysCount);
                  break;
              }
              return _sortAscending ? compareResult : -compareResult; // Invert for descending
            });

            // --- [START] CHAMPIONS SUMMARY DATA ---
            // Ensure lists are not empty before calling reduce
            final EmployeeAttendanceStat? championScore = rankings.isNotEmpty ? rankings.first : null;
            final EmployeeAttendanceStat? championWorkSubmissions = rankings.isNotEmpty ? rankings.reduce((a, b) => a.workSubmissionsCount > b.workSubmissionsCount ? a : b) : null;
            final EmployeeAttendanceStat? championTotalWorkDuration = rankings.isNotEmpty ? rankings.reduce((a, b) => a.totalWorkDuration.inMinutes > b.totalWorkDuration.inMinutes ? a : b) : null;
            
            // *** UPDATED LOGIC: Find champion with MOST absent/late days ***
            final EmployeeAttendanceStat? championAbsent = rankings.isNotEmpty ? rankings.reduce((a, b) => a.absentDays > b.absentDays ? a : b) : null;
            final EmployeeAttendanceStat? championLate = rankings.isNotEmpty ? rankings.reduce((a, b) => a.lateDaysCount > b.lateDaysCount ? a : b) : null;
            // --- [END] CHAMPIONS SUMMARY DATA ---

            return SliverToBoxAdapter(
              child: Column(
                children: [
                  // --- [START] CHAMPIONS TABLE ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('แชมป์ประจำเดือน', style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                            const Divider(),
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                              columnWidths: const {
                                0: FlexColumnWidth(),
                                1: FlexColumnWidth(),
                                2: FlexColumnWidth(),
                                3: FlexColumnWidth(),
                                4: FlexColumnWidth(),
                              },
                              children: [
                                // Header Row
                                TableRow(
                                  children: [
                                    _buildChampionHeaderCell('คะแนน'),
                                    _buildChampionHeaderCell('ส่งงาน'),
                                    _buildChampionHeaderCell('เวลารวม'),
                                    _buildChampionHeaderCell('ขาดงาน'),
                                    _buildChampionHeaderCell('สาย'),
                                  ],
                                ),
                                // Data Row
                                TableRow(
                                  children: [
                                    // *** UPDATED: All trophies are now gold ***
                                    _buildChampionDataCell(championScore?.employee.nickname, Colors.amber.shade600),
                                    _buildChampionDataCell(championWorkSubmissions?.employee.nickname, Colors.amber.shade600),
                                    _buildChampionDataCell(championTotalWorkDuration?.employee.nickname, Colors.amber.shade600),
                                    _buildChampionDataCell(championAbsent?.employee.nickname, Colors.amber.shade600),
                                    _buildChampionDataCell(championLate?.employee.nickname, Colors.amber.shade600),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  // --- [END] CHAMPIONS TABLE ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Column( // ใช้ Column เพื่อวาง Search/Sort เหนือ DataTable
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'ค้นหา รหัส/ชื่อเล่น...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<_SortColumn>(
                                  initialValue: _sortColumn,
                                  onSelected: (_SortColumn newValue) {
                                    setState(() {
                                      if (_sortColumn == newValue) {
                                        _sortAscending = !_sortAscending; // Toggle sort order if same column
                                      } else {
                                        _sortColumn = newValue;
                                        _sortAscending = false; // Default to descending for new column
                                      }
                                    });
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<_SortColumn>>[
                                    const PopupMenuItem<_SortColumn>(
                                      value: _SortColumn.finalScore,
                                      child: Text('คะแนนเยอะที่สุด'),
                                    ),
                                    const PopupMenuItem<_SortColumn>(
                                      value: _SortColumn.workSubmissionsCount,
                                      child: Text('ส่งงานเยอะที่สุด'),
                                    ),
                                    const PopupMenuItem<_SortColumn>(
                                      value: _SortColumn.totalWorkDuration,
                                      child: Text('เวลารวมเยอะที่สุด'),
                                    ),
                                    const PopupMenuItem<_SortColumn>(
                                      value: _SortColumn.absentDays,
                                      child: Text('ขาดงานเยอะที่สุด'),
                                    ),
                                    const PopupMenuItem<_SortColumn>(
                                      value: _SortColumn.lateDaysCount,
                                      child: Text('สายเยอะที่สุด'),
                                    ),
                                  ],
                                  icon: const Icon(Icons.sort),
                                  tooltip: 'จัดเรียงข้อมูล',
                                ),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 10, // Reduce spacing between columns
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              headingRowColor: MaterialStateProperty.all(Theme.of(context).primaryColor.withOpacity(0.1)),
                              border: TableBorder.all(color: Colors.grey.shade300, width: 1.0), // Add borders to all cells
                              columns: [
                                DataColumn(label: SizedBox(width: 50, child: Text('ลำดับ', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Fixed width for rank
                                DataColumn(label: SizedBox(width: 60, child: Text('รหัส', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Renamed and fixed width
                                DataColumn(label: SizedBox(width: 80, child: Text('ชื่อเล่น', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Fixed width
                                DataColumn(label: SizedBox(width: 80, child: Text('รวม', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Renamed
                                DataColumn(label: SizedBox(width: 80, child: Text('ส่งงาน', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Renamed
                                DataColumn(label: SizedBox(width: 80, child: Text('เวลารวม', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Renamed
                                DataColumn(label: SizedBox(width: 80, child: Text('ขาดงาน', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Renamed
                                DataColumn(label: SizedBox(width: 80, child: Text('สายรวม', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)))), // Renamed
                              ],
                              rows: filteredRankings.asMap().entries.map((entry) { // ใช้ filteredRankings
                                final index = entry.key;
                                final stat = entry.value;
                                final rank = index + 1;

                                Color? rowColor;
                                if (rank <= 5) {
                                  // Different background colors for top 5
                                  switch (rank) {
                                    case 1: rowColor = Colors.amber.shade50; break;
                                    case 2: rowColor = Colors.grey.shade200; break;
                                    case 3: rowColor = const Color(0xFFD7B99D); break; // Bronze-like
                                    case 4: rowColor = Colors.blue.shade50; break;
                                    case 5: rowColor = Colors.green.shade50; break;
                                  }
                                }

                                Color? trophyColor;
                                IconData? trophyIcon;
                                if (rank <= 10) {
                                  switch (rank) {
                                    case 1: trophyColor = Colors.amber.shade600; trophyIcon = Icons.emoji_events; break;
                                    case 2: trophyColor = Colors.grey.shade500; trophyIcon = Icons.emoji_events; break;
                                    case 3: trophyColor = const Color(0xFFCD7F32); trophyIcon = Icons.emoji_events; break;
                                    case 4:
                                    case 5:
                                    case 6:
                                    case 7:
                                    case 8:
                                    case 9:
                                    case 10: trophyColor = Colors.grey.shade400; trophyIcon = Icons.military_tech; break; // Generic medal for 4-10
                                  }
                                }

                                return DataRow(
                                  color: MaterialStateProperty.all(rowColor), // Apply row color
                                  cells: [
                                    DataCell(Align( // Align rank to left
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('$rank', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                                          if (trophyIcon != null) ...[
                                            const SizedBox(width: 4),
                                            Icon(trophyIcon, color: trophyColor, size: 20),
                                          ],
                                        ],
                                      ),
                                    )),
                                    DataCell(Text(stat.employee.employeeId, style: GoogleFonts.anuphan())),
                                    DataCell(Text(stat.employee.nickname, style: GoogleFonts.anuphan(fontWeight: FontWeight.w600))),
                                    DataCell(Center(child: Text('${stat.finalScore} แต้ม', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, color: rank <= 5 ? Colors.red : Theme.of(context).primaryColor)))), // Red for top 5
                                    DataCell(Center(child: Text('${stat.workSubmissionsCount} วัน', style: GoogleFonts.anuphan()))),
                                    DataCell(Center(child: Text(_formatDuration(stat.totalWorkDuration), style: GoogleFonts.anuphan()))),
                                    DataCell(Center(child: Text('${stat.absentDays} วัน', style: GoogleFonts.anuphan(color: stat.absentDays > 0 ? Colors.red : null)))),
                                    DataCell(Center(child: Text('${stat.lateDaysCount} ครั้ง', style: GoogleFonts.anuphan(color: stat.lateDaysCount > 0 ? Colors.orange : null)))), // ใช้ lateDaysCount
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: _buildRulesCard()),
      ],
    );
  }

  // Helper for header cells in the champion table
  Widget _buildChampionHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  // Helper for data cells in the champion table
  // *** UPDATED: Removed isBest parameter ***
  Widget _buildChampionDataCell(String? nickname, Color trophyColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (nickname != null) ...[
            Icon(Icons.emoji_events, color: trophyColor, size: 20),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                nickname,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ] else
            Text('-', style: GoogleFonts.anuphan(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Card(
        color: Colors.blueGrey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'หมายเหตุ:\n'
            '1. "ส่งงาน" คำนวณจากจำนวนวันที่ส่งงาน (สูงสุด 3 คะแนน/วัน)\n'
            '2. "เวลารวม" คือผลรวมชั่วโมงทำงานในกะและนอกกะ (OT) ทั้งหมดในเดือนนี้ (ไม่มีผลต่อคะแนนรวม)\n'
            '3. "ขาดงาน" นับรวมวันที่เป็นวันทำงานแต่ไม่มีการสแกนเข้างาน (-2 คะแนน/วัน)\n'
            '4. "สายรวม" นับจำนวนครั้งที่สแกนเข้างานสาย (ช้ากว่าเวลาเริ่มกะเกิน 1 นาที) (-1 คะแนน/ครั้ง)\n'
            '5. "รวม" คือผลรวมคะแนนจากทุกหมวดหมู่',
            style: GoogleFonts.anuphan(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
          ),
        ),
      ),
    );
  }
}
