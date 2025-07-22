// lib/screens/admin/outsource_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/outsource_model.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:intl/intl.dart';

class OutsourceManagementScreen extends StatefulWidget {
  final Employee loggedInEmployee;
  const OutsourceManagementScreen({super.key, required this.loggedInEmployee});

  @override
  State<OutsourceManagementScreen> createState() =>
      _OutsourceManagementScreenState();
}

class _OutsourceManagementScreenState extends State<OutsourceManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการ OutSource'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'บุคคลภายนอก'),
            Tab(icon: Icon(Icons.assignment_outlined), text: 'หัวข้องาน'),
            Tab(icon: Icon(Icons.edit_calendar_outlined), text: 'บันทึกผลงาน'),
            Tab(icon: Icon(Icons.payment_outlined), text: 'สรุปและจ่ายเงิน'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OutsourcePersonnelTab(),
          _OutsourceTasksTab(),
          _WorkLoggingTab(admin: widget.loggedInEmployee),
          _PaymentSummaryTab(),
        ],
      ),
    );
  }
}

// Tab 1: Manage Outsource Personnel
class _OutsourcePersonnelTab extends StatelessWidget {
  Future<void> _showAddOutsourceDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nicknameController = TextEditingController();
    final fullNameController = TextEditingController();
    final phoneController = TextEditingController();

    final lastIdDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('isOutsource', isEqualTo: true)
        .orderBy('employee_code', descending: true)
        .limit(1)
        .get();

    int nextId = 1;
    if (lastIdDoc.docs.isNotEmpty) {
      final lastId = lastIdDoc.docs.first.id;
      nextId = int.parse(lastId.substring(2)) + 1;
    }
    final newId = '99${nextId.toString().padLeft(4, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เพิ่มบุคคลภายนอก (ID: $newId)'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'ชื่อ-สกุล*'),
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null),
              TextFormField(
                  controller: nicknameController,
                  decoration: const InputDecoration(labelText: 'ชื่อเล่น*'),
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อเล่น' : null),
              TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                  keyboardType: TextInputType.phone),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final data = {
                  'employee_code': newId,
                  'firstName': fullNameController.text.split(' ').first,
                  'lastName': fullNameController.text.split(' ').length > 1 ? fullNameController.text.split(' ').last : '',
                  'employee_nickname': nicknameController.text,
                  'mobilephone': phoneController.text,
                  'isOutsource': true,
                  'createdAt': FieldValue.serverTimestamp(),
                  // Add default empty values for other required fields if any
                  'title': '', 'gender': '', 'nationalId': '', 'maritalStatus': '', 'address': '',
                  'emergencyContact': {}, 'additionalContacts': {}, 'details': '', 'departmentCode': '',
                  'positions': [], 'startDate': Timestamp.now(), 'dailyWorkShifts': {}, 'salary': 0, 'bankAccount': {},
                };
                await FirebaseFirestore.instance.collection('users').doc(newId).set(data);
                Navigator.pop(ctx);
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
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('isOutsource', isEqualTo: true)
            .orderBy('employee_code')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลบุคคลภายนอก'));
          }
          final outsourceList = snapshot.data!.docs
              .map((doc) => Employee.fromFirestore(doc))
              .toList();
          return ListView.builder(
            itemCount: outsourceList.length,
            itemBuilder: (ctx, index) {
              final person = outsourceList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: EmployeeAvatar(imageUrl: person.profileImageUrl, gender: person.gender, radius: 20),
                  title: Text('${person.fullName} (${person.nickname})'),
                  subtitle: Text('ID: ${person.employeeId} | โทร: ${person.phoneNumber}'),
                  trailing: const Icon(Icons.edit_note),
                  onTap: () {
                    // TODO: Implement edit functionality if needed
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOutsourceDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}


// Tab 2: Manage Outsource Tasks
class _OutsourceTasksTab extends StatelessWidget {
  void _showTaskDialog(BuildContext context, {OutsourceTask? task}) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: task?.title);
    final descController = TextEditingController(text: task?.description);
    final rateController = TextEditingController(text: task?.paymentRate.toString());
    final unitController = TextEditingController(text: task?.unit);

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(task == null ? 'เพิ่มหัวข้องานใหม่' : 'แก้ไขหัวข้องาน'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'หัวข้องาน*'),
                          validator: (v) => v!.isEmpty ? 'กรุณากรอก' : null),
                      TextFormField(
                          controller: descController,
                          decoration: const InputDecoration(labelText: 'รายละเอียด')),
                      TextFormField(
                          controller: rateController,
                          decoration: const InputDecoration(labelText: 'ค่าตอบแทน*', hintText: 'เช่น 150'),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v!.isEmpty || num.tryParse(v) == null) ? 'ใส่ตัวเลข' : null),
                      TextFormField(
                          controller: unitController,
                          decoration: const InputDecoration(labelText: 'หน่วย*', hintText: 'เช่น ชิ้น, เที่ยว, วัน'),
                          validator: (v) => v!.isEmpty ? 'กรุณากรอก' : null),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final data = {
                        'title': titleController.text,
                        'description': descController.text,
                        'paymentRate': num.parse(rateController.text),
                        'unit': unitController.text,
                        'createdAt': task?.createdAt ?? FieldValue.serverTimestamp(),
                        'isActive': task?.isActive ?? true,
                      };
                      final collection = FirebaseFirestore.instance.collection('outsource_tasks');
                      if (task == null) {
                        await collection.add(data);
                      } else {
                        await collection.doc(task.id).update(data);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('outsource_tasks').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีหัวข้องาน'));
          }
          final tasks = snapshot.data!.docs.map((doc) => OutsourceTask.fromFirestore(doc)).toList();
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (ctx, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text('ค่าตอบแทน: ${task.paymentRate} บาท / ${task.unit}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showTaskDialog(context, task: task),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Tab 3: Log Work
class _WorkLoggingTab extends StatefulWidget {
  final Employee admin;
  const _WorkLoggingTab({required this.admin});

  @override
  State<_WorkLoggingTab> createState() => _WorkLoggingTabState();
}

class _WorkLoggingTabState extends State<_WorkLoggingTab> {
  final formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  Employee? _selectedPerson;
  OutsourceTask? _selectedTask;
  final quantityController = TextEditingController();
  final notesController = TextEditingController();
  bool isSaving = false;

  void _saveWorkLog() async {
    if (formKey.currentState!.validate()) {
      setState(() => isSaving = true);
      try {
        final quantity = num.parse(quantityController.text);
        final payment = quantity * _selectedTask!.paymentRate;

        final log = OutsourceWorkLog(
          id: '',
          outsourceId: _selectedPerson!.employeeId,
          outsourceName: _selectedPerson!.nickname,
          taskId: _selectedTask!.id,
          taskTitle: _selectedTask!.title,
          date: Timestamp.fromDate(_selectedDate),
          quantity: quantity,
          paymentCalculated: payment,
          notes: notesController.text,
          createdAt: Timestamp.now(),
          createdBy: widget.admin.nickname,
        );

        await FirebaseFirestore.instance.collection('outsource_work_logs').add(log.toFirestore());
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ'), backgroundColor: Colors.green));
        
        // Reset form
        setState(() {
          quantityController.clear();
          notesController.clear();
        });

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      } finally {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text('วันที่: ${DateFormat('d MMMM yyyy', 'th_TH').format(_selectedDate)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2022), lastDate: DateTime.now());
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 8),
          _buildPersonDropdown(),
          const SizedBox(height: 16),
          _buildTaskDropdown(),
          const SizedBox(height: 16),
          TextFormField(
            controller: quantityController,
            decoration: InputDecoration(labelText: 'จำนวน*', hintText: 'หน่วย: ${_selectedTask?.unit ?? '...'}'),
            keyboardType: TextInputType.number,
            validator: (v) => (v!.isEmpty || num.tryParse(v) == null) ? 'ใส่ตัวเลข' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'หมายเหตุ'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          isSaving 
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                onPressed: (_selectedPerson == null || _selectedTask == null) ? null : _saveWorkLog,
                icon: const Icon(Icons.save),
                label: const Text('บันทึกผลงาน'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
        ],
      ),
    );
  }

  Widget _buildPersonDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('isOutsource', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading persons...');
        final people = snapshot.data!.docs.map((d) => Employee.fromFirestore(d)).toList();
        return DropdownButtonFormField<Employee>(
          value: _selectedPerson,
          hint: const Text('เลือกบุคคลภายนอก*'),
          onChanged: (val) => setState(() => _selectedPerson = val),
          items: people.map((p) => DropdownMenuItem(value: p, child: Text(p.nickname))).toList(),
          validator: (v) => v == null ? 'กรุณาเลือก' : null,
        );
      },
    );
  }

  Widget _buildTaskDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('outsource_tasks').where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading tasks...');
        final tasks = snapshot.data!.docs.map((d) => OutsourceTask.fromFirestore(d)).toList();
        return DropdownButtonFormField<OutsourceTask>(
          value: _selectedTask,
          hint: const Text('เลือกหัวข้องาน*'),
          onChanged: (val) => setState(() => _selectedTask = val),
          items: tasks.map((t) => DropdownMenuItem(value: t, child: Text(t.title))).toList(),
          validator: (v) => v == null ? 'กรุณาเลือก' : null,
        );
      },
    );
  }
}


// Tab 4: Payment Summary
class _PaymentSummaryTab extends StatefulWidget {
  @override
  State<_PaymentSummaryTab> createState() => _PaymentSummaryTabState();
}

class _PaymentSummaryTabState extends State<_PaymentSummaryTab> {
  Employee? _selectedPerson;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: _buildPersonDropdown()),
              IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final range = await showDateRangePicker(context: context, firstDate: DateTime(2022), lastDate: DateTime.now(), initialDateRange: DateTimeRange(start: _startDate, end: _endDate));
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end;
                    });
                  }
                },
              )
            ],
          ),
        ),
        if (_selectedPerson != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('outsource_work_logs')
                  .where('outsourceId', isEqualTo: _selectedPerson!.employeeId)
                  .where('date', isGreaterThanOrEqualTo: _startDate)
                  .where('date', isLessThanOrEqualTo: _endDate)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('ไม่พบข้อมูลในช่วงวันที่ที่เลือก'));
                }
                final logs = snapshot.data!.docs.map((d) => OutsourceWorkLog.fromFirestore(d)).toList();
                final totalPayment = logs.fold<num>(0, (sum, log) => sum + log.paymentCalculated);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        color: Colors.blue.shade50,
                        child: ListTile(
                          title: const Text('ยอดรวมที่ต้องชำระ'),
                          trailing: Text('${NumberFormat("#,##0.00").format(totalPayment)} บาท', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (ctx, index) {
                          final log = logs[index];
                          return ListTile(
                            title: Text(log.taskTitle),
                            subtitle: Text(DateFormat('d MMM yyyy', 'th_TH').format(log.date.toDate())),
                            trailing: Text('${log.paymentCalculated} บาท (${log.quantity} หน่วย)'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          )
      ],
    );
  }

  Widget _buildPersonDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('isOutsource', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        final people = snapshot.data!.docs.map((d) => Employee.fromFirestore(d)).toList();
        return DropdownButton<Employee>(
          value: _selectedPerson,
          hint: const Text('เลือกบุคคลภายนอก'),
          isExpanded: true,
          onChanged: (val) => setState(() => _selectedPerson = val),
          items: people.map((p) => DropdownMenuItem(value: p, child: Text(p.nickname))).toList(),
        );
      },
    );
  }
}
