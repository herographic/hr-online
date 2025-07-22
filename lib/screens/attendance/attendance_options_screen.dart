// lib/screens/attendance/attendance_options_screen.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/screens/attendance/face_liveness_screen.dart';
import 'package:hr_online/screens/attendance/gps_checkin_screen.dart';
import 'package:hr_online/screens/attendance/time_update_request_screen.dart';
import 'package:hr_online/screens/qr_scanner_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:intl/intl.dart';

class AttendanceOptionsScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const AttendanceOptionsScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<AttendanceOptionsScreen> createState() =>
      _AttendanceOptionsScreenState();
}

class _AttendanceOptionsScreenState extends State<AttendanceOptionsScreen> {
  
  Future<void> _startVerification() async {
    if (widget.loggedInEmployee == null) return;

    final doc = await firestore.FirebaseFirestore.instance
        .collection('users')
        .doc(widget.loggedInEmployee!.employeeId)
        .get();
    final faceUrls = List<String>.from(doc.data()?['faceDataUrls'] ?? []);

    if (faceUrls.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาลงทะเบียนใบหน้าก่อนใช้งาน (ที่หน้าข้อมูลส่วนตัว)'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final bool? isVerified = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceLivenessScreen(
          mode: FaceScanMode.verify,
          employeeId: widget.loggedInEmployee!.employeeId,
        ),
      ),
    );

    if (isVerified == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยืนยันตัวตนสำเร็จ! (จำลองการลงเวลา)'), backgroundColor: Colors.green),
        );
      }
    } else {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('การยืนยันตัวตนไม่สำเร็จ'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'เลือกวิธีลงเวลา',
      showBackButton: true,
      bodySlivers: [
        SliverToBoxAdapter(
          child: _AttendanceInfoCard(employee: widget.loggedInEmployee),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildOptionButton(
                context,
                icon: Icons.qr_code_scanner,
                label: 'สแกน QR Code',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => QRScannerScreen(
                      isUserAdmin: widget.isUserAdmin,
                      loggedInEmployee: widget.loggedInEmployee,
                    ),
                  ));
                },
              ),
              _buildOptionButton(
                context,
                icon: Icons.face_retouching_natural,
                label: 'สแกนใบหน้า',
                onTap: _startVerification,
              ),
              _buildOptionButton(
                context,
                icon: Icons.location_on,
                label: 'เช็คอินด้วย GPS',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => GpsCheckinScreen(
                      isUserAdmin: widget.isUserAdmin,
                      loggedInEmployee: widget.loggedInEmployee,
                    ),
                  ));
                },
              ),
              _buildOptionButton(
                context,
                icon: Icons.groups,
                label: 'สแกนลูกทีม',
                onTap: null, 
              ),
              _buildOptionButton(
                context,
                icon: Icons.update,
                label: 'ขออัพเดทเวลา',
                onTap: () {
                  if (widget.loggedInEmployee != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TimeUpdateRequestScreen(
                        loggedInEmployee: widget.loggedInEmployee!,
                      ),
                    ));
                  }
                },
              ),
              _buildOptionButton(
                context,
                icon: Icons.help_outline,
                label: 'ช่วยเหลือ',
                onTap: null,
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
      floatingActionButton: const SizedBox.shrink(),
    );
  }

  Widget _buildOptionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback? onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        disabledBackgroundColor: Colors.grey.shade200,
        disabledForegroundColor: Colors.grey.shade500,
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceInfoCard extends StatelessWidget {
  final Employee? employee;
  const _AttendanceInfoCard({this.employee});

  Future<Map<String, dynamic>> _fetchAttendanceData() async {
    if (employee == null) return {};

    final now = DateTime.now();
    final docId =
        '${employee!.employeeId}_${DateFormat('yyyy-MM-dd').format(now)}';

    final results = await Future.wait([
      firestore.FirebaseFirestore.instance
          .collection('attendance_log')
          .doc(docId)
          .get(),
      firestore.FirebaseFirestore.instance.collection('work_shifts').get(),
    ]);

    final attendanceDoc = results[0] as firestore.DocumentSnapshot;
    final workShiftsSnapshot = results[1] as firestore.QuerySnapshot;

    AttendanceLog? attendanceLog;
    if (attendanceDoc.exists) {
      attendanceLog = AttendanceLog.fromFirestore(attendanceDoc);
    }

    final allShifts =
        workShiftsSnapshot.docs.map((doc) => WorkShift.fromFirestore(doc)).toList();

    return {
      'attendanceLog': attendanceLog,
      'allShifts': allShifts,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (employee == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAttendanceData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: Colors.white),
          ));
        }

        final data = snapshot.data ?? {};
        final AttendanceLog? log = data['attendanceLog'];
        final List<WorkShift> allShifts = data['allShifts'] ?? [];

        final todayKey = DateFormat('EEEE').format(DateTime.now());
        final shiftId = employee!.dailyWorkShifts[todayKey];
        final workShift = allShifts.firstWhereOrNull((s) => s.id == shiftId);

        final String shiftText = workShift != null
            ? 'กะการทำงาน : ${workShift.startTime} - ${workShift.endTime} น.'
            : 'กะการทำงาน : วันหยุด';

        final timeFormat = DateFormat('HH:mm');
        final String checkInTime =
            log?.checkIn != null ? timeFormat.format(log!.checkIn!.toDate()) : '- : -';
        final String breakOutTime =
            log?.breakOut != null ? timeFormat.format(log!.breakOut!.toDate()) : '- : -';
        final String breakInTime =
            log?.breakIn != null ? timeFormat.format(log!.breakIn!.toDate()) : '- : -';
        final String checkOutTime = log?.checkOut != null
            ? timeFormat.format(log!.checkOut!.toDate())
            : '- : -';
        
        // --- [START] NEW COLOR LOGIC ---
        Color checkInColor = Colors.white;
        Color checkOutColor = Colors.white;

        if (workShift != null && log != null) {
          try {
            final startParts = workShift.startTime.split(':');
            final endParts = workShift.endTime.split(':');
            final logDate = log.date.toDate();

            final scheduledCheckIn = DateTime(logDate.year, logDate.month, logDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
            var scheduledCheckOut = DateTime(logDate.year, logDate.month, logDate.day, int.parse(endParts[0]), int.parse(endParts[1]));
            if (scheduledCheckOut.isBefore(scheduledCheckIn)) {
              scheduledCheckOut = scheduledCheckOut.add(const Duration(days: 1));
            }

            // Check-in color logic
            if (log.checkIn != null) {
              final actualCheckIn = log.checkIn!.toDate();
              if (actualCheckIn.isAfter(scheduledCheckIn.add(const Duration(minutes: 1)))) {
                checkInColor = Colors.red.shade300;
              } else {
                checkInColor = Colors.lightGreenAccent;
              }
            }

            // Check-out color logic
            if (log.checkOut != null) {
              final actualCheckOut = log.checkOut!.toDate();
              if (actualCheckOut.isBefore(scheduledCheckOut)) {
                checkOutColor = Colors.red.shade300;
              } else {
                checkOutColor = Colors.lightGreenAccent;
              }
            }
          } catch (e) {
            // ignore parsing errors
          }
        }
        // --- [END] NEW COLOR LOGIC ---

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE ที่ d MMMM พ.ศ. yyyy', 'th_TH')
                        .format(DateTime.now()),
                    style: GoogleFonts.anuphan(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shiftText,
                    style: GoogleFonts.anuphan(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const Divider(color: Colors.white30, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeDisplay('เข้างาน', checkInTime, color: checkInColor),
                      _buildTimeDisplay('ออกพัก', breakOutTime),
                      _buildTimeDisplay('เข้าพัก', breakInTime),
                      _buildTimeDisplay('ออกงาน', checkOutTime, color: checkOutColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- [START] MODIFIED WIDGET ---
  Widget _buildTimeDisplay(String label, String time, {Color color = Colors.white}) {
  // --- [END] MODIFIED WIDGET ---
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.anuphan(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            // --- [START] MODIFIED CODE ---
            color: color, // Use the passed color
            // --- [END] MODIFIED CODE ---
          ),
        ),
      ],
    );
  }
}
