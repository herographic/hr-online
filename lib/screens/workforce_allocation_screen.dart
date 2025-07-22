// lib/screens/workforce_allocation_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/employee_detail_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/employee_grid_node.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class WorkforceAllocationScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const WorkforceAllocationScreen(
      {super.key, required this.isUserAdmin, this.loggedInEmployee});

  @override
  State<WorkforceAllocationScreen> createState() =>
      _WorkforceAllocationScreenState();
}

class _WorkforceAllocationScreenState extends State<WorkforceAllocationScreen> {
  List<Employee> _allEmployees = [];
  List<Department> _allDepartments = [];
  bool _isLoading = true;

  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _searchController.text.toLowerCase() != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final usersSnapshotFuture = FirebaseFirestore.instance
          .collection('users')
          .orderBy('employee_name')
          .get();
      final deptsSnapshotFuture = FirebaseFirestore.instance
          .collection('departments')
          .orderBy('name')
          .get();

      final results =
          await Future.wait([usersSnapshotFuture, deptsSnapshotFuture]);

      final usersSnapshot = results[0] as QuerySnapshot;
      final deptsSnapshot = results[1] as QuerySnapshot;

      if (mounted) {
        setState(() {
          _allEmployees =
              usersSnapshot.docs.map((doc) => Employee.fromFirestore(doc)).toList();
          _allDepartments = deptsSnapshot.docs
              .map((doc) => Department.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')));
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _allEmployees.where((emp) {
      if (_searchQuery.isEmpty) return true;
      return emp.fullName.toLowerCase().contains(_searchQuery) ||
          emp.nickname.toLowerCase().contains(_searchQuery) ||
          emp.employeeId.contains(_searchQuery);
    }).toList();

    final groupedByDept = groupBy(filteredEmployees,
        (Employee emp) => emp.departmentCode.isEmpty ? 'no-dept' : emp.departmentCode);

    final sortedDepts = List<Department>.from(_allDepartments)
      ..sort((a, b) => a.name.compareTo(b.name));

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'จัดสรรกำลังคน',
      showBackButton: true,
      bodySlivers: [
        _buildControlHeader(),
        _isLoading
            ? const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white)))
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    Department? department;
                    String deptCode;
                    String departmentName;

                    if (index < sortedDepts.length) {
                      department = sortedDepts[index];
                      deptCode = department.id;
                      departmentName = department.name;
                    } else {
                      deptCode = 'no-dept';
                      departmentName = 'ไม่ระบุแผนก';
                    }

                    final employeesInDept = groupedByDept[deptCode] ?? [];
                    if (employeesInDept.isEmpty) return const SizedBox.shrink();

                    return _buildDepartmentCard(
                        departmentName, employeesInDept);
                  },
                  childCount: sortedDepts.length + 1,
                ),
              ),
      ],
    );
  }

  Widget _buildControlHeader() {
    final DateFormat headerFormat = DateFormat('EEEE d MMMM yyyy', 'th_TH');
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('วันที่: ${headerFormat.format(_selectedDate)}',
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อ, รหัสพนักงาน...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(
      String departmentName, List<Employee> employees) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: Colors.white.withOpacity(0.95),
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          title: Text(departmentName,
              style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF0072ff))),
          initiallyExpanded: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: employees.map((emp) {
                  final String selectedDayKey =
                      DateFormat('EEEE').format(_selectedDate);
                  final String? shiftIdForDay =
                      emp.dailyWorkShifts[selectedDayKey];
                  final bool isDayOff =
                      shiftIdForDay == null || shiftIdForDay.isEmpty;

                  return EmployeeGridNode(
                    employee: emp,
                    isDayOff: isDayOff,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => EmployeeDetailScreen(
                          employeeId: emp.employeeId,
                          isUserAdmin: widget.isUserAdmin,
                        ),
                      ));
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
