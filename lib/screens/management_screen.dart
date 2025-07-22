import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/position_model.dart';
import 'package:hr_online/models/work_shift_model.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('จัดการข้อมูลหลัก'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'แผนก', icon: Icon(Icons.business_center)),
              Tab(text: 'ตำแหน่งงาน', icon: Icon(Icons.assignment_ind)),
              Tab(text: 'กะทำงาน', icon: Icon(Icons.access_time_filled)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DepartmentTab(),
            PositionTab(),
            WorkShiftTab(),
          ],
        ),
      ),
    );
  }
}

// ... (DepartmentTab และ PositionTab โค้ดเหมือนเดิม) ...
class DepartmentTab extends StatelessWidget {
  const DepartmentTab({super.key});

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มแผนกใหม่'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'ชื่อแผนก'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('departments').add({
                  'name': nameController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('departments').orderBy('createdAt').snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ไม่มีข้อมูลแผนก'));
          }
          final departments = snapshot.data!.docs;
          return ListView.builder(
            itemCount: departments.length,
            itemBuilder: (ctx, index) {
              final dept = Department.fromFirestore(departments[index]);
              return ListTile(
                title: Text(dept.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('departments').doc(dept.id).delete();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
class PositionTab extends StatelessWidget {
  const PositionTab({super.key});

  void _showAddDialog(BuildContext context, List<Department> departments) {
    final nameController = TextEditingController();
    String? selectedDeptId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('เพิ่มตำแหน่งใหม่'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDeptId,
                  hint: const Text('เลือกแผนก'),
                  items: departments.map((dept) {
                    return DropdownMenuItem(value: dept.id, child: Text(dept.name));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDeptId = value;
                    });
                  },
                  validator: (value) => value == null ? 'กรุณาเลือกแผนก' : null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'ชื่อตำแหน่ง'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && selectedDeptId != null) {
                    await FirebaseFirestore.instance.collection('positions').add({
                      'name': nameController.text,
                      'departmentId': selectedDeptId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                     if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('departments').orderBy('name').snapshots(),
        builder: (ctx, deptSnapshot) {
          if (!deptSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final departments = deptSnapshot.data!.docs.map((doc) => Department.fromFirestore(doc)).toList();
          
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('positions').orderBy('createdAt').snapshots(),
            builder: (ctx, posSnapshot) {
              if (posSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!posSnapshot.hasData || posSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('ไม่มีข้อมูลตำแหน่งงาน'));
              }
              final positions = posSnapshot.data!.docs;

              return ListView.builder(
                itemCount: positions.length,
                itemBuilder: (ctx, index) {
                  final pos = Position.fromFirestore(positions[index]);
                  final deptName = departments.firstWhere((d) => d.id == pos.departmentId, orElse: () => Department(id: '', name: 'ไม่พบแผนก', createdAt: Timestamp.now())).name;

                  return ListTile(
                    title: Text(pos.name),
                    subtitle: Text(deptName),
                     trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                         FirebaseFirestore.instance.collection('positions').doc(pos.id).delete();
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           final departmentsStream = FirebaseFirestore.instance.collection('departments').orderBy('name').snapshots();
           departmentsStream.first.then((snapshot) {
             final departments = snapshot.docs.map((doc) => Department.fromFirestore(doc)).toList();
             if (departments.isNotEmpty) {
               _showAddDialog(context, departments);
             } else {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('กรุณาเพิ่มแผนกก่อนสร้างตำแหน่งงาน'))
               );
             }
           });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class WorkShiftTab extends StatelessWidget {
  const WorkShiftTab({super.key});

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มกะทำงานใหม่'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'ชื่อกะ (เช่น กะเช้า)'),
                validator: (value) => value!.isEmpty ? 'กรุณากรอกชื่อกะ' : null,
              ),
              TextFormField(
                controller: startTimeController,
                decoration: const InputDecoration(labelText: 'เวลาเริ่มงาน', hintText: 'HH:mm'),
                readOnly: true, // ทำให้พิมพ์ไม่ได้ ต้องเลือกจากปฏิทินเท่านั้น
                validator: (value) => value!.isEmpty ? 'กรุณากรอกเวลาเริ่ม' : null,
                 onTap: () async {
                  TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (picked != null) {
                    // จัดรูปแบบเป็น HH:mm
                    startTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  }
                },
              ),
              TextFormField(
                controller: endTimeController,
                decoration: const InputDecoration(labelText: 'เวลาเลิกงาน', hintText: 'HH:mm'),
                readOnly: true,
                validator: (value) => value!.isEmpty ? 'กรุณากรอกเวลาเลิก' : null,
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (picked != null) {
                    endTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await FirebaseFirestore.instance.collection('work_shifts').add({
                  'name': nameController.text,
                  'startTime': startTimeController.text,
                  'endTime': endTimeController.text,
                });
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('work_shifts').orderBy('startTime').snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ไม่มีข้อมูลกะทำงาน'));
          }
          final shifts = snapshot.data!.docs;
          return ListView.builder(
            itemCount: shifts.length,
            itemBuilder: (ctx, index) {
              final shift = WorkShift.fromFirestore(shifts[index]);
              return ListTile(
                title: Text(shift.name),
                // =================== [START] CODE EDITED ===================
                // ใช้ Getter ใหม่ในการแสดงผล
                subtitle: Text(shift.displayTimeThai),
                // =================== [END] CODE EDITED ===================
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('work_shifts').doc(shift.id).delete();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
