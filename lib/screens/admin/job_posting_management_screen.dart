// lib/screens/admin/job_posting_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/job_posting_model.dart';
import 'package:hr_online/screens/admin/job_posting_editor_screen.dart';
import 'package:intl/intl.dart';

class JobPostingManagementScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const JobPostingManagementScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<JobPostingManagementScreen> createState() =>
      _JobPostingManagementScreenState();
}

class _JobPostingManagementScreenState
    extends State<JobPostingManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการประกาศรับสมัครงาน'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_postings')
            .orderBy('postedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีประกาศรับสมัครงาน'),
            );
          }

          final postings = snapshot.data!.docs
              .map((doc) => JobPosting.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: postings.length,
            itemBuilder: (context, index) {
              final post = postings[index];
              final isActive = post.applicationEndDate.toDate().isAfter(DateTime.now());
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                    backgroundImage: post.positionImageUrl != null
                        ? NetworkImage(post.positionImageUrl!)
                        : null,
                    child: post.positionImageUrl == null
                        ? Icon(Icons.work_outline, color: isActive ? Colors.green : Colors.grey)
                        : null,
                  ),
                  title: Text(post.positionName, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'แผนก: ${post.departmentName}\nรับสมัครถึง: ${DateFormat('d MMM yyyy', 'th_TH').format(post.applicationEndDate.toDate())}',
                    style: GoogleFonts.anuphan(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => JobPostingEditorScreen(
                        loggedInEmployee: widget.loggedInEmployee!,
                        jobPostingToEdit: post,
                      ),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.loggedInEmployee != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => JobPostingEditorScreen(
                loggedInEmployee: widget.loggedInEmployee!,
              ),
            ));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้เพื่อสร้างประกาศ')));
          }
        },
        label: const Text('สร้างประกาศใหม่'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
