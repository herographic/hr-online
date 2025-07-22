// hr_online/lib/screens/admin/view_applications_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/job_application_model.dart';
import 'package:hr_online/screens/admin/application_detail_screen.dart';

class ViewApplicationsScreen extends StatefulWidget {
  const ViewApplicationsScreen({super.key});

  @override
  State<ViewApplicationsScreen> createState() => _ViewApplicationsScreenState();
}

class _ViewApplicationsScreenState extends State<ViewApplicationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อมูลผู้สมัครงาน'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_applications')
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีผู้สมัครงาน'));
          }

          final applications = snapshot.data!.docs
              .map((doc) => JobApplication.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final app = applications[index];
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  // --- [START] แสดงรูปผู้สมัคร ---
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: (app.photoUrl != null && app.photoUrl!.isNotEmpty)
                        ? NetworkImage(app.photoUrl!)
                        : null,
                    child: (app.photoUrl == null || app.photoUrl!.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  // --- [END] แสดงรูปผู้สมัคร ---
                  title: Text('${app.title} ${app.firstName} ${app.lastName}'),
                  subtitle: Text(
                    'ตำแหน่ง: ${app.position1}\nสถานะ: ${app.status}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ApplicationDetailScreen(applicationId: app.id),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
