// lib/screens/admin/compensation_history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:intl/intl.dart';

class CompensationHistoryScreen extends StatelessWidget {
  const CompensationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติทำงานชดเชย'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance_log')
            .where('isCompensationDay', isEqualTo: true)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ไม่พบประวัติการทำงานชดเชย'));
          }

          final logs = snapshot.data!.docs
              .map((doc) => AttendanceLog.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final dateFormat = DateFormat('d MMMM yyyy', 'th_TH');
              final timeFormat = DateFormat('HH:mm');
              
              final checkIn = log.checkIn != null ? timeFormat.format(log.checkIn!.toDate()) : '-';
              final checkOut = log.checkOut != null ? timeFormat.format(log.checkOut!.toDate()) : '-';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.more_time),
                  ),
                  title: Text(
                    log.employeeName ?? 'ไม่พบชื่อ',
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'วันที่: ${dateFormat.format(log.date.toDate())}\nเวลา: $checkIn - $checkOut',
                    style: GoogleFonts.anuphan(),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
