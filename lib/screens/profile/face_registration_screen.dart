// lib/screens/profile/face_registration_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/attendance/face_liveness_screen.dart';
import 'package:image_picker/image_picker.dart';

class FaceRegistrationScreen extends StatefulWidget {
  final Employee employee;
  const FaceRegistrationScreen({super.key, required this.employee});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  bool _isUploading = false;

  Future<void> _startRegistration() async {
    // Navigate to the liveness screen in registration mode
    final List<XFile>? capturedImages = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceLivenessScreen(
          mode: FaceScanMode.register,
          employeeId: widget.employee.employeeId,
        ),
      ),
    );

    if (capturedImages == null || capturedImages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกการลงทะเบียนใบหน้า')),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Delete old images first
      await _deleteExistingFaceData();

      // Upload new images
      List<String> newImageUrls = [];
      for (int i = 0; i < capturedImages.length; i++) {
        final file = File(capturedImages[i].path);
        final ref = FirebaseStorage.instance
            .ref()
            .child('face_data/${widget.employee.employeeId}/face_$i.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        newImageUrls.add(url);
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employee.employeeId)
          .update({'faceDataUrls': newImageUrls});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ลงทะเบียนใบหน้าสำเร็จ'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteExistingFaceData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.employee.employeeId).get();
    final existingUrls = List<String>.from(doc.data()?['faceDataUrls'] ?? []);
    
    for (String url in existingUrls) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (e) {
        // Ignore errors if file doesn't exist
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการข้อมูลใบหน้า'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.employee.employeeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final employeeData = snapshot.data!.data() as Map<String, dynamic>?;
          final faceUrls = List<String>.from(employeeData?['faceDataUrls'] ?? []);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'ใบหน้าที่ลงทะเบียนไว้',
                  style: GoogleFonts.anuphan(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ระบบต้องการใบหน้า 4 รูป (มองตรง, หันซ้าย, หันขวา, มองขึ้น) เพื่อใช้ในการยืนยันตัวตน',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                faceUrls.isEmpty
                    ? const Text('ยังไม่มีข้อมูลใบหน้า')
                    : GridView.builder(
                        shrinkWrap: true,
                        itemCount: faceUrls.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          return CircleAvatar(
                            backgroundImage: NetworkImage(faceUrls[index]),
                          );
                        },
                      ),
                const Spacer(),
                if (_isUploading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton.icon(
                    onPressed: _startRegistration,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(faceUrls.isEmpty
                        ? 'เริ่มลงทะเบียนใบหน้า'
                        : 'ลงทะเบียนใบหน้าใหม่'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}
