import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/job_description_model.dart';
import 'package:uuid/uuid.dart';

class JobDescriptionManagementTab extends StatelessWidget {
  const JobDescriptionManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_descriptions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('ยังไม่มีรายละเอียดงาน\nกดปุ่ม + เพื่อเพิ่ม',
                    textAlign: TextAlign.center));
          }
          final jobDescriptions = snapshot.data!.docs
              .map((doc) => JobDescription.fromFirestore(doc))
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: jobDescriptions.length,
            itemBuilder: (context, index) {
              final jobDesc = jobDescriptions[index];
              final totalPoints = jobDesc.subItems
                  .fold<int>(0, (sum, item) => sum + item.points);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(jobDesc.title,
                      style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${jobDesc.subItems.length} ข้อย่อย | รวม $totalPoints คะแนน'),
                  trailing: const Icon(Icons.edit_note),
                  onTap: () => _showJobDescriptionDialog(context,
                      jobDescription: jobDesc),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJobDescriptionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showJobDescriptionDialog(BuildContext context,
      {JobDescription? jobDescription}) {
    showDialog(
      context: context,
      builder: (context) =>
          _JobDescriptionDialog(jobDescription: jobDescription),
    );
  }
}

class _JobDescriptionDialog extends StatefulWidget {
  final JobDescription? jobDescription;
  const _JobDescriptionDialog({this.jobDescription});

  @override
  State<_JobDescriptionDialog> createState() => _JobDescriptionDialogState();
}

class _JobDescriptionDialogState extends State<_JobDescriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late List<JobSubItem> _subItems;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.jobDescription?.title ?? '');
    _subItems = widget.jobDescription?.subItems
            .map((item) => JobSubItem(
                id: item.id,
                description: item.description,
                points: item.points))
            .toList() ??
        [];
  }

  void _addSubItem() {
    if (_subItems.length < 10) {
      setState(() {
        _subItems
            .add(JobSubItem(id: const Uuid().v4(), description: '', points: 0));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเพิ่มข้อย่อยได้เกิน 10 ข้อ')),
      );
    }
  }

  void _removeSubItem(int index) {
    setState(() {
      _subItems.removeAt(index);
    });
  }

  Future<void> _saveJobDescription() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // --- [START] VALIDATION LOGIC ---
    // ตรวจสอบว่าคะแนนรวมของข้อย่อยไม่เกิน 10
    final totalPoints =
        _subItems.fold<int>(0, (sum, item) => sum + item.points);
    if (totalPoints > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('คะแนนรวมของข้อย่อยต้องไม่เกิน 10 คะแนน'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    // --- [END] VALIDATION LOGIC ---

    setState(() => _isSaving = true);

    try {
      final collection =
          FirebaseFirestore.instance.collection('job_descriptions');
      final newJobDesc = JobDescription(
        id: widget.jobDescription?.id ?? '',
        title: _titleController.text.trim(),
        subItems: _subItems,
        createdAt: widget.jobDescription?.createdAt ?? Timestamp.now(),
      );

      if (widget.jobDescription == null) {
        await collection.add(newJobDesc.toFirestore());
      } else {
        await collection
            .doc(widget.jobDescription!.id)
            .update(newJobDesc.toFirestore());
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.jobDescription == null
          ? 'สร้างรายละเอียดงาน'
          : 'แก้ไขรายละเอียดงาน'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'หัวข้อหลัก'),
                  validator: (value) =>
                      value!.trim().isEmpty ? 'กรุณากรอกหัวข้อ' : null,
                ),
                const SizedBox(height: 16),
                Text('ข้อย่อย (คะแนนรวมต้องไม่เกิน 10)',
                    style: Theme.of(context).textTheme.titleSmall),
                const Divider(),
                ..._subItems.asMap().entries.map((entry) {
                  int index = entry.key;
                  JobSubItem item = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: item.description,
                          decoration: InputDecoration(
                              labelText: 'รายละเอียดข้อที่ ${index + 1}'),
                          onSaved: (value) => _subItems[index] = JobSubItem(
                              id: item.id,
                              description: value ?? '',
                              points: item.points),
                          validator: (v) => v!.trim().isEmpty ? 'ห้ามว่าง' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: item.points.toString(),
                          decoration: const InputDecoration(labelText: 'คะแนน'),
                          keyboardType: TextInputType.number,
                          onSaved: (value) => _subItems[index] = JobSubItem(
                              id: item.id,
                              description: _subItems[index].description,
                              points: int.tryParse(value ?? '0') ?? 0),
                          validator: (v) =>
                              (int.tryParse(v ?? '') == null) ? 'ใส่ตัวเลข' : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        onPressed: () => _removeSubItem(index),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                if (_subItems.length < 10)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มข้อย่อย'),
                    onPressed: _addSubItem,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveJobDescription,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('บันทึก'),
        ),
      ],
    );
  }
}
