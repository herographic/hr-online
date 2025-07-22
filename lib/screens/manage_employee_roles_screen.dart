// lib/screens/manage_employee_roles_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/position_model.dart';
import 'package:hr_online/models/work_shift_model.dart';

class ManageEmployeeRolesScreen extends StatefulWidget {
  final Employee employee;

  const ManageEmployeeRolesScreen({super.key, required this.employee});

  @override
  State<ManageEmployeeRolesScreen> createState() => _ManageEmployeeRolesScreenState();
}

class _ManageEmployeeRolesScreenState extends State<ManageEmployeeRolesScreen> {
  List<Department> _allDepartments = [];
  List<Position> _allPositions = [];
  List<WorkShift> _allWorkShifts = [];
  bool _isLoading = true;

  String? _selectedDepartmentId;
  List<String> _selectedPositionIds = [];
  Map<String, String?> _selectedDailyShifts = {};
  
  // --- [START] MODIFIED STATE VARIABLES ---
  late bool _isAdmin;
  late bool _isDepartmentHead;
  // --- [END] MODIFIED STATE VARIABLES ---
  
  final Map<String, String> _weekdays = {
    'Monday': 'จันทร์',
    'Tuesday': 'อังคาร',
    'Wednesday': 'พุธ',
    'Thursday': 'พฤหัสบดี',
    'Friday': 'ศุกร์',
    'Saturday': 'เสาร์',
    'Sunday': 'อาทิตย์',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final deptFuture = FirebaseFirestore.instance.collection('departments').orderBy('name').get();
      final posFuture = FirebaseFirestore.instance.collection('positions').orderBy('name').get();
      final shiftFuture = FirebaseFirestore.instance.collection('work_shifts').orderBy('startTime').get();

      final results = await Future.wait([deptFuture, posFuture, shiftFuture]);
      
      final deptSnapshot = results[0];
      final posSnapshot = results[1];
      final shiftSnapshot = results[2];

      if (mounted) {
        setState(() {
          _allDepartments = deptSnapshot.docs.map((doc) => Department.fromFirestore(doc)).toList();
          _allPositions = posSnapshot.docs.map((doc) => Position.fromFirestore(doc)).toList();
          _allWorkShifts = shiftSnapshot.docs.map((doc) => WorkShift.fromFirestore(doc)).toList();
          
          _selectedDepartmentId = widget.employee.departmentCode.isEmpty ? null : widget.employee.departmentCode;
          _selectedPositionIds = widget.employee.positions.map((p) => p['id'].toString()).toList();
          _selectedDailyShifts = Map<String, String?>.from(widget.employee.dailyWorkShifts);
          
          // --- [START] INITIALIZE ROLE STATES ---
          _isAdmin = widget.employee.isAdmin;
          _isDepartmentHead = widget.employee.isDepartmentHead;
          // --- [END] INITIALIZE ROLE STATES ---

          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onSave() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> newPositions = _allPositions
          .where((pos) => _selectedPositionIds.contains(pos.id))
          .map((pos) => {'id': pos.id, 'name': pos.name})
          .toList();

      final Map<String, String> shiftsToSave = {};
      _selectedDailyShifts.forEach((day, shiftId) {
        if (shiftId != null && shiftId.isNotEmpty) {
          shiftsToSave[day] = shiftId;
        }
      });

      // --- [START] ADDED ROLES TO UPDATE DATA ---
      await FirebaseFirestore.instance.collection('users').doc(widget.employee.employeeId).update({
        'department_code': _selectedDepartmentId ?? '',
        'positions': newPositions,
        'dailyWorkShifts': shiftsToSave,
        'isAdmin': _isAdmin,
        'isDepartmentHead': _isDepartmentHead,
      });
      // --- [END] ADDED ROLES TO UPDATE DATA ---

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดในการบันทึก: $e")));
       }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final positionsInSelectedDept = _allPositions
        .where((pos) => pos.departmentId == _selectedDepartmentId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการสิทธิ์: ${widget.employee.nickname}'),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _onSave, tooltip: 'บันทึก')
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionHeader('การกำหนดสิทธิ์'),
                Card(
                  elevation: 1,
                  child: SwitchListTile(
                    title: Text('สิทธิ์ผู้ดูแลระบบ (Admin)', style: GoogleFonts.anuphan()),
                    subtitle: Text('เข้าถึงเมนูสำหรับผู้ดูแลทั้งหมด', style: GoogleFonts.anuphan(fontSize: 12)),
                    value: _isAdmin,
                    onChanged: (bool value) => setState(() => _isAdmin = value),
                    secondary: Icon(Icons.shield, color: _isAdmin ? Theme.of(context).primaryColor : Colors.grey),
                  ),
                ),
                // --- [START] NEW WIDGET FOR DEPARTMENT HEAD ---
                Card(
                  elevation: 1,
                  child: SwitchListTile(
                    title: Text('สิทธิ์หัวหน้าแผนก', style: GoogleFonts.anuphan()),
                    subtitle: Text('อนุมัติการลาของพนักงานในแผนก', style: GoogleFonts.anuphan(fontSize: 12)),
                    value: _isDepartmentHead,
                    onChanged: (bool value) => setState(() => _isDepartmentHead = value),
                    secondary: Icon(Icons.supervisor_account, color: _isDepartmentHead ? Colors.teal : Colors.grey),
                  ),
                ),
                // --- [END] NEW WIDGET FOR DEPARTMENT HEAD ---
                const SizedBox(height: 24),
                
                _buildSectionHeader('แผนกและตำแหน่ง'),
                _buildDepartmentDropdown(),
                const SizedBox(height: 16),
                if (_selectedDepartmentId != null) _buildPositionSelection(positionsInSelectedDept),
                
                const SizedBox(height: 24),
                _buildSectionHeader('กะและเวลาทำงานประจำสัปดาห์'),
                _buildDailyShiftSelection(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDepartmentId,
      hint: const Text('--- เลือกแผนก ---'),
      isExpanded: true,
      items: _allDepartments.map((dept) => DropdownMenuItem(value: dept.id, child: Text(dept.name))).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDepartmentId = newValue;
          _selectedPositionIds.clear();
        });
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  Widget _buildPositionSelection(List<Position> positions) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เลือกตำแหน่งในแผนกนี้:', style: TextStyle(fontWeight: FontWeight.bold)),
          if (positions.isEmpty)
            const Padding(padding: EdgeInsets.all(8.0), child: Text('ไม่มีตำแหน่งในแผนกนี้', style: TextStyle(color: Colors.grey)))
          else
            ...positions.map((pos) => CheckboxListTile(
                  title: Text(pos.name),
                  value: _selectedPositionIds.contains(pos.id),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedPositionIds.add(pos.id);
                      } else {
                        _selectedPositionIds.remove(pos.id);
                      }
                    });
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildDailyShiftSelection() {
    return Column(
      children: _weekdays.entries.map((entry) {
        final dayKey = entry.key;
        final dayName = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text(dayName, style: GoogleFonts.anuphan(fontSize: 16))),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedDailyShifts[dayKey],
                  hint: const Text('เลือกกะ'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('วันหยุด / ไม่มีกะ', style: TextStyle(color: Colors.grey)),
                    ),
                    ..._allWorkShifts.map((shift) => DropdownMenuItem(
                      value: shift.id,
                      child: Text(shift.displayTime),
                    )),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDailyShifts[dayKey] = newValue;
                    });
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
