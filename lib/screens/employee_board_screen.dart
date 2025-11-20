// lib/screens/employee_board_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/public_employee_detail_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'dart:async';

class EmployeeBoardScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const EmployeeBoardScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<EmployeeBoardScreen> createState() => _EmployeeBoardScreenState();
}

class _EmployeeBoardScreenState extends State<EmployeeBoardScreen> {
  List<Employee> _allEmployees = [];
  List<Department> _allDepartments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').orderBy('employee_code').get();
      final deptsSnapshot = await FirebaseFirestore.instance.collection('departments').get();

      if (mounted) {
        setState(() {
          _allEmployees = usersSnapshot.docs.map((doc) => Employee.fromFirestore(doc)).toList();
          _allDepartments = deptsSnapshot.docs.map((doc) => Department.fromFirestore(doc)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text.toLowerCase() != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final departmentMap = {for (var dept in _allDepartments) dept.id: dept.name};
    
    final filteredEmployees = _allEmployees.where((emp) {
      if (_searchQuery.isEmpty) return true;
      final deptName = departmentMap[emp.departmentCode]?.toLowerCase() ?? '';
      final positionNames = emp.positions.map((p) => p['name']?.toString().toLowerCase() ?? '').join(' ');
      
      return emp.nickname.toLowerCase().contains(_searchQuery) ||
             emp.employeeId.contains(_searchQuery) ||
             deptName.contains(_searchQuery) ||
             positionNames.contains(_searchQuery);
    }).toList();

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'บอร์ดพนักงาน',
      showBackButton: true,
      bodySlivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหา รหัส, ชื่อเล่น, แผนก, ตำแหน่ง...',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        _isLoading
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.white)))
            : SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.65, // Adjusted for more vertical space
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final employee = filteredEmployees[index];
                      return EmployeeBoardNode(
                        employee: employee,
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => PublicEmployeeDetailScreen(
                              employee: employee,
                            ),
                          ));
                        },
                      );
                    },
                    childCount: filteredEmployees.length,
                  ),
                ),
              ),
      ],
    );
  }
}

class EmployeeBoardNode extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const EmployeeBoardNode({
    super.key,
    required this.employee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final positionName = employee.positions.isNotEmpty ? employee.positions.first['name'] ?? '' : 'N/A';
    final double expProgress = employee.nextLevelExp > 0 ? employee.exp / employee.nextLevelExp : 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            EmployeeAvatar(
              imageUrl: employee.profileImageUrl,
              gender: employee.gender,
              radius: 28,
            ),
            Column(
              children: [
                Text(
                  employee.nickname,
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '(${employee.employeeId})',
                  style: GoogleFonts.anuphan(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  positionName,
                  style: GoogleFonts.anuphan(fontSize: 11, color: Theme.of(context).primaryColor),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Lv. ${employee.level} ${employee.levelTitle}',
                  style: GoogleFonts.anuphan(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: '${employee.exp} / ${employee.nextLevelExp} EXP',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: expProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                 Text(
                  '${employee.exp}/${employee.nextLevelExp}',
                  style: GoogleFonts.anuphan(fontSize: 9, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
