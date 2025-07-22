// lib/widgets/submit_work_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_submission_model.dart';
import 'package:image_picker/image_picker.dart';

class SubmitWorkDialog extends StatefulWidget {
  final Employee loggedInEmployee;
  final List<Employee> allEmployees;

  const SubmitWorkDialog({
    super.key,
    required this.loggedInEmployee,
    required this.allEmployees,
  });

  @override
  State<SubmitWorkDialog> createState() => _SubmitWorkDialogState();
}

class _SubmitWorkDialogState extends State<SubmitWorkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  final _resultController = TextEditingController();

  final List<File> _imageFiles = [];
  final List<Employee> _taggedEmployees = [];
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _pickImages(StateSetter setDialogState) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1200);
      if (pickedFiles.isNotEmpty) {
        setDialogState(() {
          _imageFiles.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการเลือกรูป: $e')));
    }
  }

  Future<void> _takePhoto(StateSetter setDialogState) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1200);
      if (pickedFile != null) {
        setDialogState(() {
          _imageFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการถ่ายรูป: $e')));
    }
  }

  void _showTagEmployeeDialog(StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setTagDialogState) {
            return AlertDialog(
              title: const Text('แท็กพนักงาน'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.allEmployees.length,
                  itemBuilder: (context, index) {
                    final emp = widget.allEmployees[index];
                    final isTagged = _taggedEmployees.any((e) => e.employeeId == emp.employeeId);
                    return CheckboxListTile(
                      title: Text(emp.fullName),
                      value: isTagged,
                      onChanged: (selected) {
                        setDialogState(() {
                          if (selected == true) {
                            if(!isTagged) _taggedEmployees.add(emp);
                          } else {
                            _taggedEmployees.removeWhere((e) => e.employeeId == emp.employeeId);
                          }
                        });
                        setTagDialogState((){});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ตกลง'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitWork(StateSetter setDialogState) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) return;

    setDialogState(() => _isUploading = true);

    try {
      List<String> imageUrls = [];
      List<String> imageFileNames = [];
      for (var file in _imageFiles) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final ref = FirebaseStorage.instance.ref().child('work_submissions').child(fileName);
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
        imageFileNames.add(fileName);
      }
      
      String departmentName = '';
       if (widget.loggedInEmployee.departmentCode.isNotEmpty) {
        final deptDoc = await FirebaseFirestore.instance.collection('departments').doc(widget.loggedInEmployee.departmentCode).get();
        if(deptDoc.exists) {
            departmentName = deptDoc.data()?['name'] ?? '';
        }
      }

      final submission = WorkSubmission(
        id: '',
        authorId: widget.loggedInEmployee.employeeId,
        authorFullName: widget.loggedInEmployee.fullName,
        authorNickname: widget.loggedInEmployee.nickname,
        authorImageUrl: widget.loggedInEmployee.profileImageUrl,
        authorPosition: widget.loggedInEmployee.positions.map((p) => p['name'] ?? '').join(', '),
        authorDepartment: departmentName,
        authorDepartmentId: widget.loggedInEmployee.departmentCode,
        title: _titleController.text.trim(),
        details: _detailsController.text.trim(),
        expectedResult: _resultController.text.trim(),
        imageUrls: imageUrls,
        imageFileNames: imageFileNames,
        taggedEmployees: _taggedEmployees.map((e) => {'id': e.employeeId, 'name': e.nickname}).toList(),
        timestamp: Timestamp.now(),
        ratings: {},
        totalScore: 0,
      );

      await FirebaseFirestore.instance.collection('work_submissions').add(submission.toFirestore());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งงานสำเร็จ!'), backgroundColor: Colors.green),
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
        setDialogState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ส่งรายงานการทำงาน', style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'ชื่อเรื่อง*'),
                      validator: (value) => value!.isEmpty ? 'กรุณากรอกชื่อเรื่อง' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _detailsController,
                      decoration: const InputDecoration(labelText: 'รายละเอียด*'),
                      minLines: 4,
                      maxLines: 8,
                      validator: (value) => value!.isEmpty ? 'กรุณากรอกรายละเอียด' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _resultController,
                      decoration: const InputDecoration(labelText: 'ผลลัพธ์ที่จะได้'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImages(setDialogState),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('แนบรูป'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black),
                        ),
                         ElevatedButton.icon(
                          onPressed: () => _takePhoto(setDialogState),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('ถ่ายรูป'),
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black),
                        ),
                      ],
                    ),
                    if (_imageFiles.isNotEmpty) _buildImagePreviews(setDialogState),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTagEmployeeDialog(setDialogState),
                        icon: const Icon(Icons.alternate_email),
                        label: const Text('แท็กพนักงาน'),
                      ),
                    ),
                     if (_taggedEmployees.isNotEmpty) _buildTaggedPreviews(setDialogState),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
                        const SizedBox(width: 8),
                        _isUploading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(onPressed: () => _submitWork(setDialogState), child: const Text('ส่งงาน')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePreviews(StateSetter setDialogState) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _imageFiles.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          return Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_imageFiles[index].path),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              InkWell(
                onTap: () => setDialogState(() => _imageFiles.removeAt(index)),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

   Widget _buildTaggedPreviews(StateSetter setDialogState) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: _taggedEmployees.map((emp) => Chip(
          avatar: CircleAvatar(
            backgroundImage: emp.profileImageUrl != null ? NetworkImage(emp.profileImageUrl!) : null,
            child: emp.profileImageUrl == null ? Text(emp.nickname.isNotEmpty ? emp.nickname[0] : '?') : null,
          ),
          label: Text(emp.nickname),
          onDeleted: () => setDialogState(() => _taggedEmployees.removeWhere((e) => e.employeeId == emp.employeeId)),
        )).toList(),
      ),
    );
  }
}
