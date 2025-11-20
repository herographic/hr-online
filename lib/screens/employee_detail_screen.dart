// lib/screens/employee_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/screens/add_employee_screen.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;
  final bool isUserAdmin;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    required this.isUserAdmin,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  String? _selectedStatus;
  final _statusNoteController = TextEditingController();
  bool _isStatusEditMode = false;

  @override
  void dispose() {
    _statusNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              appBar: AppBar(title: const Text('ผิดพลาด')),
              body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
              appBar: AppBar(title: const Text('ผิดพลาด')),
              body: const Center(child: Text('ไม่พบข้อมูลพนักงาน')));
        }

        final employee = Employee.fromFirestore(snapshot.data!);

        if (!_isStatusEditMode) {
          _selectedStatus = employee.employmentStatus;
          _statusNoteController.text = employee.employmentStatusNote ?? '';
        }

        return FutureBuilder<Map<String, dynamic>>(
            future: _fetchRelatedData(employee),
            builder: (context, relatedDataSnapshot) {
              if (relatedDataSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return _buildUI(context, employee, 'กำลังโหลด...', []);
              }

              final String departmentName =
                  relatedDataSnapshot.data?['departmentName'] ?? 'N/A';
              final List<WorkShift> allWorkShifts =
                  relatedDataSnapshot.data?['allWorkShifts'] ?? [];

              return _buildUI(
                  context, employee, departmentName, allWorkShifts);
            });
      },
    );
  }

  Future<Map<String, dynamic>> _fetchRelatedData(Employee employee) async {
    final departmentsFuture =
        FirebaseFirestore.instance.collection('departments').get();
    final workShiftsFuture =
        FirebaseFirestore.instance.collection('work_shifts').get();

    final results = await Future.wait([departmentsFuture, workShiftsFuture]);

    final departments = (results[0] as QuerySnapshot)
        .docs
        .map((doc) => Department.fromFirestore(doc))
        .toList();
    final workShifts = (results[1] as QuerySnapshot)
        .docs
        .map((doc) => WorkShift.fromFirestore(doc))
        .toList();

    final department =
        departments.firstWhereOrNull((d) => d.id == employee.departmentCode);

    return {
      'departmentName': department?.name ?? 'ยังไม่ได้กำหนด',
      'allWorkShifts': workShifts,
    };
  }

  Widget _buildUI(BuildContext context, Employee employee,
      String departmentName, List<WorkShift> allWorkShifts) {
    final thaiDateFormat = DateFormat('d MMMM yyyy', 'th_TH');
    final currencyFormat = NumberFormat("#,##0.00", "en_US");
    final positionNames = employee.positions.isNotEmpty
        ? employee.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ยังไม่ได้กำหนด';

    return Scaffold(
      appBar: AppBar(
        title: Text('ข้อมูล: ${employee.nickname}'),
        actions: [
          if (widget.isUserAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'แก้ไขข้อมูล',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddEmployeeScreen(
                      employeeToEdit: employee, isAdmin: widget.isUserAdmin))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isUserAdmin) ...[
              _buildStatusManagementCard(context, employee),
              const SizedBox(height: 16),
            ],
            _buildHeader(context, employee),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              title: 'ข้อมูลส่วนตัว',
              icon: Icons.person_outline,
              children: [
                _buildInfoRow('ชื่อ-สกุล:', '${employee.title} ${employee.fullName}'),
                _buildInfoRow('ชื่อเล่น:', employee.nickname),
                _buildInfoRow('เพศ:', employee.gender),
                _buildInfoRow('วันเกิด:',
                    employee.birthDate != null
                        ? thaiDateFormat.format(employee.birthDate!.toDate())
                        : '-'),
                _buildInfoRow('สถานภาพ:', employee.maritalStatus),
                _buildInfoRow('เลขบัตรประชาชน:', employee.nationalId),
                _buildPhoneInfoRow('เบอร์โทร:', employee.phoneNumber),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              title: 'ข้อมูลการทำงาน',
              icon: Icons.work_outline,
              children: [
                _buildInfoRow('รหัสพนักงาน:', employee.employeeId),
                // --- [START] MODIFIED CODE: Replaced totalScore with Leveling System ---
                _buildInfoRowWithIcon(
                    'ยศ:', 'Lv. ${employee.level} ${employee.levelTitle}', Icons.military_tech, Colors.amber),
                // --- [END] MODIFIED CODE ---
                _buildInfoRow('แผนก:', departmentName),
                _buildInfoRow('ตำแหน่ง:', positionNames),
                _buildInfoRow(
                    'วันเริ่มงาน:', thaiDateFormat.format(employee.startDate.toDate())),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("ตารางทำงานประจำสัปดาห์",
                      style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                ),
                _buildWeeklyScheduleTable(employee, allWorkShifts),
              ],
            ),
            if (widget.isUserAdmin) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                title: 'ข้อมูลการเงิน',
                icon: Icons.account_balance_wallet_outlined,
                children: [
                  _buildInfoRow('เงินเดือน:', currencyFormat.format(employee.salary)),
                  _buildInfoRow(
                      'ธนาคาร:', employee.bankAccount['bankName'] ?? '-'),
                  _buildInfoRow('เลขที่บัญชี:',
                      employee.bankAccount['accountNumber'] ?? '-'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              title: 'ข้อมูลเพิ่มเติม',
              icon: Icons.note_alt_outlined,
              children: [
                _buildPhoneInfoRow('ผู้ติดต่อฉุกเฉิน:',
                    employee.emergencyContact['phone'] ?? '',
                    name: employee.emergencyContact['name']),
                _buildPhoneInfoRow('พนักงานที่สนิท:',
                    employee.additionalContacts['close_colleague_phone'] ?? '',
                    name: employee.additionalContacts['close_colleague_name']),
                _buildPhoneInfoRow('คนสนิท ลำดับ 1:',
                    employee.additionalContacts['close_friend1_phone'] ?? '',
                    name: employee.additionalContacts['close_friend1_name']),
                _buildPhoneInfoRow('คนสนิท ลำดับ 2:',
                    employee.additionalContacts['close_friend2_phone'] ?? '',
                    name: employee.additionalContacts['close_friend2_name']),
                _buildPhoneInfoRow('หัวหน้างาน:',
                    employee.additionalContacts['supervisor_phone'] ?? '',
                    name: employee.additionalContacts['supervisor_name']),
                const Divider(height: 20),
                _buildInfoRow('หมายเหตุ:', employee.details),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusManagementCard(BuildContext context, Employee employee) {
    final statusList = [
      'ปกติ',
      'ลาออก',
      'ไล่ออก',
      'โดนพักงาน 3 วัน',
      'โดนพักงาน 7 วัน',
      'โดนพักงาน 15 วัน',
      'โดนพักงาน 1 เดือน',
      'โดนพักงานไม่มีกำหนด'
    ];

    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isStatusEditMode
            ? _buildStatusEditView(statusList, employee)
            : _buildStatusDisplayView(employee),
      ),
    );
  }

  Widget _buildStatusDisplayView(Employee employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("สถานะพนักงาน",
                style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => setState(() => _isStatusEditMode = true),
              tooltip: 'แก้ไขสถานะ',
              splashRadius: 20,
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(employee.employmentStatus ?? 'ปกติ',
            style: GoogleFonts.anuphan(
                fontSize: 16,
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold)),
        if (employee.employmentStatusNote != null &&
            employee.employmentStatusNote!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text("หมายเหตุ: ${employee.employmentStatusNote}",
                style: GoogleFonts.anuphan(color: Colors.grey.shade800)),
          ),
      ],
    );
  }

  Widget _buildStatusEditView(List<String> statusList, Employee employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("แก้ไขสถานะพนักงาน",
            style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          hint: const Text('เลือกสถานะ'),
          items: statusList
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (value) => setState(() => _selectedStatus = value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _statusNoteController,
          decoration: const InputDecoration(labelText: 'หมายเหตุ (ถ้ามี)'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isStatusEditMode = false;
                  _selectedStatus = employee.employmentStatus;
                  _statusNoteController.text = employee.employmentStatusNote ?? '';
                });
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: _saveStatus,
              child: const Text('บันทึก'),
            )
          ],
        )
      ],
    );
  }

  Future<void> _saveStatus() async {
    try {
      String? statusToSave = _selectedStatus;
      if (statusToSave == 'ปกติ') {
        statusToSave = null;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .update({
        'employmentStatus': statusToSave,
        'employmentStatusNote': _statusNoteController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('อัปเดตสถานะสำเร็จ'), backgroundColor: Colors.green));
        setState(() {
          _isStatusEditMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _formatShiftTime(String time) {
    if (time.endsWith(':00')) {
      return time.substring(0, time.length - 3);
    }
    return time;
  }

  Widget _buildWeeklyScheduleTable(
      Employee employee, List<WorkShift> allShifts) {
    final Map<String, String> weekdays = {
      'Monday': 'จ',
      'Tuesday': 'อ',
      'Wednesday': 'พ',
      'Thursday': 'พฤ',
      'Friday': 'ศ',
      'Saturday': 'ส',
      'Sunday': 'อา'
    };

    return Table(
      children: [
        TableRow(
          children: weekdays.values
              .map((dayName) => Center(
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(dayName,
                        style: GoogleFonts.anuphan(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  )))
              .toList(),
        ),
        TableRow(
          children: weekdays.keys.map((dayKey) {
            final shiftId = employee.dailyWorkShifts[dayKey];
            String shiftDisplay = "หยุด";
            Color textColor = Colors.red.shade700;
            if (shiftId != null && shiftId.isNotEmpty) {
              final shift = allShifts.firstWhereOrNull((s) => s.id == shiftId);
              shiftDisplay = shift != null
                  ? '${_formatShiftTime(shift.startTime)}-${_formatShiftTime(shift.endTime)}'
                  : 'N/A';
              textColor = Colors.black87;
            }
            return Center(
                child: Text(shiftDisplay,
                    style: GoogleFonts.anuphan(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: FontWeight.w600)));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Employee employee) {
    return Center(
      child: Column(
        children: [
          EmployeeAvatar(
              imageUrl: employee.profileImageUrl,
              gender: employee.gender,
              radius: 60),
          const SizedBox(height: 12),
          Text(employee.fullName,
              style:
                  GoogleFonts.anuphan(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('ID: ${employee.employeeId}',
              style: GoogleFonts.anuphan(
                  fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(title,
                  style:
                      GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: GoogleFonts.anuphan(
                      color: Colors.grey.shade700, fontSize: 16))),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: GoogleFonts.anuphan(
                      fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithIcon(
      String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: GoogleFonts.anuphan(
                      color: Colors.grey.shade700, fontSize: 16))),
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: GoogleFonts.anuphan(
                      fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPhoneInfoRow(String label, String phone, {String? name}) {
    final hasPhone = phone.isNotEmpty;
    final displayText =
        (name != null && name.isNotEmpty) ? '$name ($phone)' : phone;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: GoogleFonts.anuphan(
                      color: Colors.grey.shade700, fontSize: 16))),
          Expanded(
            child: InkWell(
              onTap: hasPhone
                  ? () async {
                      final Uri launchUri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(launchUri)) {
                        await launchUrl(launchUri);
                      }
                    }
                  : null,
              child: Text(
                displayText.isEmpty ? '-' : displayText,
                style: GoogleFonts.anuphan(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: hasPhone ? Colors.blue : null,
                  decoration: hasPhone ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
