// lib/screens/employee_note_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/personal_note_model.dart';
import 'package:intl/intl.dart';

class EmployeeNoteDetailScreen extends StatefulWidget {
  final Employee employee;
  final Employee? loggedInEmployee;

  const EmployeeNoteDetailScreen({
    super.key,
    required this.employee,
    this.loggedInEmployee,
  });

  @override
  State<EmployeeNoteDetailScreen> createState() => _EmployeeNoteDetailScreenState();
}

class _EmployeeNoteDetailScreenState extends State<EmployeeNoteDetailScreen> {
  final _noteController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSaving = false;

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      final newNote = PersonalNote(
        id: '', // Firestore will generate this
        text: _noteController.text.trim(),
        authorId: widget.loggedInEmployee?.employeeId ?? 'admin',
        authorName: widget.loggedInEmployee?.nickname ?? 'ผู้ดูแลระบบ',
        timestamp: Timestamp.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employee.employeeId)
          .collection('notes')
          .add(newNote.toFirestore());

      _noteController.clear();
      FocusScope.of(context).unfocus();
      // Scroll to bottom after adding a note
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positionNames = widget.employee.positions.isNotEmpty
        ? widget.employee.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ยังไม่ได้กำหนด';

    return Scaffold(
      appBar: AppBar(
        title: Text('บันทึกถึง: ${widget.employee.nickname}'),
      ),
      body: Column(
        children: [
          _buildEmployeeHeader(positionNames),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.employee.employeeId)
                  .collection('notes')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('ยังไม่มีบันทึกสำหรับพนักงานคนนี้', style: GoogleFonts.anuphan(color: Colors.grey)),
                  );
                }
                final notes = snapshot.data!.docs.map((doc) => PersonalNote.fromFirestore(doc)).toList();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    return _NoteCard(note: notes[index]);
                  },
                );
              },
            ),
          ),
          _buildNoteInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeader(String positionNames) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.fullName,
            style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'ตำแหน่ง: $positionNames',
            style: GoogleFonts.anuphan(fontSize: 16, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ข้อความบันทึก...',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
            ),
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                    onPressed: _saveNote,
                  ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final PersonalNote note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final thaiDateFormat = DateFormat('d MMM yy, HH:mm', 'th_TH');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.text,
              style: GoogleFonts.anuphan(fontSize: 14, height: 1.5),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'โดย: ${note.authorName}',
                  style: GoogleFonts.anuphan(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  thaiDateFormat.format(note.timestamp.toDate()),
                  style: GoogleFonts.anuphan(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
