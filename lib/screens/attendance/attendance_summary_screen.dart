// lib/screens/attendance/attendance_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/home_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSummaryScreen extends StatelessWidget {
  final AttendanceLog log;
  final Employee employee;
  final String attendanceType;

  const AttendanceSummaryScreen({
    super.key,
    required this.log,
    required this.employee,
    required this.attendanceType,
  });

  /// Helper to get the correct data based on attendance type
  Map<String, dynamic> _getAttendanceDetails() {
    Timestamp? timestamp;
    String locationName = '-';

    switch (attendanceType) {
      case 'checkIn':
        timestamp = log.checkIn;
        locationName = log.checkInLocationName ?? '-';
        break;
      case 'checkOut':
        timestamp = log.checkOut;
        locationName = log.checkOutLocationName ?? '-';
        break;
      case 'breakOut':
        timestamp = log.breakOut;
        locationName = log.checkInLocationName ?? 'ที่ทำงาน';
        break;
      case 'breakIn':
        timestamp = log.breakIn;
        locationName = log.checkInLocationName ?? 'ที่ทำงาน';
        break;
    }
    return {
      'timestamp': timestamp,
      'locationName': locationName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final details = _getAttendanceDetails();
    final Timestamp? timestamp = details['timestamp'];
    final String locationName = details['locationName'];

    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss', 'th_TH');
    final displayTime = timestamp != null ? timeFormat.format(timestamp.toDate()) : 'N/A';
    
    final typeTextMap = {
      'checkIn': 'ลงเวลาเข้างาน',
      'checkOut': 'ลงเวลาออกงาน',
      'breakOut': 'ลงเวลาออกพัก',
      'breakIn': 'ลงเวลาเข้าพัก',
    };
    
    final String title = typeTextMap[attendanceType] ?? 'ลงเวลา';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontFamily: GoogleFonts.anuphan().fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSuccessHeader(),
          const SizedBox(height: 24),
          _buildInfoCard([
            _buildInfoRow(Icons.check_circle_outline, 'ลงเวลา', displayTime),
            _buildInfoRow(Icons.check_circle_outline, 'รูปแบบการลงเวลา', 'QR/GPS'),
            _buildInfoRow(Icons.check_circle_outline, 'ชื่อพนักงาน', '${employee.employeeId} - ${employee.fullName} (${employee.nickname})'),
            _buildInfoRow(Icons.check_circle_outline, 'รหัสอ้างอิง', log.id),
            _buildInfoRow(Icons.check_circle_outline, 'เวลา', displayTime.split(' ').last),
            _buildInfoRow(Icons.check_circle_outline, 'สถานที่', locationName),
            _buildInfoRow(Icons.check_circle_outline, 'ห่างจาก', 'คำนวณไม่ได้'),
          ]),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage('https://i.stack.imgur.com/g2VlB.png'), // Placeholder map image
                fit: BoxFit.cover,
              ),
            ),
             child: const Center(child: Icon(Icons.location_on, color: Colors.red, size: 40)),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen(isUserAdmin: employee.isAdmin, loggedInEmployee: employee)),
              (Route<dynamic> route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('หน้าหลัก', style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.green, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text(
            'ระบบได้รับเวลาทำงานท่านแล้ว',
            style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'เวลาของท่านกำลังถูกบันทึกตามลำดับ',
            style: GoogleFonts.anuphan(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text('$label: ', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: GoogleFonts.anuphan()),
          ),
        ],
      ),
    );
  }
}
