// lib/screens/admin/edit_global_announcement_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditGlobalAnnouncementScreen extends StatefulWidget {
  const EditGlobalAnnouncementScreen({super.key});

  @override
  State<EditGlobalAnnouncementScreen> createState() =>
      _EditGlobalAnnouncementScreenState();
}

class _EditGlobalAnnouncementScreenState
    extends State<EditGlobalAnnouncementScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  final String _docId = 'global_announcement';

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc(_docId)
          .get();
      if (doc.exists && doc.data() != null) {
        _controller.text = doc.data()!['text'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAnnouncement() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc(_docId)
          .set({
        'text': _controller.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('บันทึกประกาศสำเร็จ'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการประกาศ'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveAnnouncement,
              tooltip: 'บันทึก',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'ข้อความประกาศสำหรับทุกคน',
                      hintText: 'พิมพ์ข้อความที่นี่...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAnnouncement,
                    icon: const Icon(Icons.save),
                    label: const Text('บันทึกประกาศ'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
