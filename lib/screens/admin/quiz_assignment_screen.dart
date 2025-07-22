// lib/screens/admin/quiz_assignment_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';

class QuizAssignmentScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizAssignmentScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizAssignmentScreen> createState() => _QuizAssignmentScreenState();
}

class _QuizAssignmentScreenState extends State<QuizAssignmentScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<Employee> _allEmployees = [];
  List<Department> _allDepartments = [];
  Set<String> _assignedEmployeeIds = {};
  Set<String> _selectedEmployeeIds = {};

  String? _filterDepartmentId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .orderBy('employee_name')
            .get(),
        FirebaseFirestore.instance
            .collection('departments')
            .orderBy('name')
            .get(),
        FirebaseFirestore.instance
            .collection('quiz_assignments')
            .where('quizId', isEqualTo: widget.quizId)
            .get(),
      ]);

      final employeeSnapshot = results[0] as QuerySnapshot;
      final departmentSnapshot = results[1] as QuerySnapshot;
      final assignmentSnapshot = results[2] as QuerySnapshot;

      if (mounted) {
        setState(() {
          _allEmployees = employeeSnapshot.docs
              .map((doc) => Employee.fromFirestore(doc))
              .toList();
          _allDepartments = departmentSnapshot.docs
              .map((doc) => Department.fromFirestore(doc))
              .toList();

          final assignedIds =
              assignmentSnapshot.docs.map((doc) => doc['employeeId'] as String).toSet();
          _assignedEmployeeIds = assignedIds;
          _selectedEmployeeIds = Set.from(assignedIds);

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("เกิดข้อผิดพลาดในการโหลดข้อมูล: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAssignments() async {
    setState(() => _isSaving = true);

    final batch = FirebaseFirestore.instance.batch();
    final assignmentsCollection =
        FirebaseFirestore.instance.collection('quiz_assignments');

    final employeesToAssign =
        _selectedEmployeeIds.difference(_assignedEmployeeIds);
    final employeesToUnassign =
        _assignedEmployeeIds.difference(_selectedEmployeeIds);

    for (final employeeId in employeesToAssign) {
      final docRef = assignmentsCollection.doc('${widget.quizId}_$employeeId');
      batch.set(docRef, {
        'quizId': widget.quizId,
        'employeeId': employeeId,
        'status': 'pending',
        'assignedAt': FieldValue.serverTimestamp(),
        'score': null,
        'completedAt': null,
      });
    }

    for (final employeeId in employeesToUnassign) {
      final docRef = assignmentsCollection.doc('${widget.quizId}_$employeeId');
      batch.delete(docRef);
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('บันทึกการมอบหมายสำเร็จ'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleSelectAll(List<Employee> visibleEmployees) {
    final visibleIds = visibleEmployees.map((e) => e.employeeId).toSet();
    final allVisibleSelected = _selectedEmployeeIds.containsAll(visibleIds);

    setState(() {
      if (allVisibleSelected) {
        _selectedEmployeeIds.removeAll(visibleIds);
      } else {
        _selectedEmployeeIds.addAll(visibleIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _allEmployees.where((emp) {
      bool matchesDept =
          _filterDepartmentId == null || emp.departmentCode == _filterDepartmentId;
      if (!matchesDept) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery;
        final positionNames = emp.positions
            .map((p) => p['name']?.toString().toLowerCase() ?? '')
            .join(' ');

        return emp.fullName.toLowerCase().contains(query) ||
            emp.employeeId.toLowerCase().contains(query) ||
            positionNames.contains(query);
      }
      return true;
    }).toList();

    final allVisibleSelected = filteredEmployees.isNotEmpty &&
        _selectedEmployeeIds
            .containsAll(filteredEmployees.map((e) => e.employeeId));

    return Scaffold(
      appBar: AppBar(
        title: Text('มอบหมาย: ${widget.quizTitle}'),
        actions: [
          if (_isSaving)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveAssignments,
                tooltip: 'บันทึก'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(allVisibleSelected
                          ? Icons.deselect
                          : Icons.select_all),
                      label:
                          Text(allVisibleSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด'),
                      onPressed: () => _toggleSelectAll(filteredEmployees),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = filteredEmployees[index];
                      return CheckboxListTile(
                        title: Text(employee.fullName),
                        subtitle: Text('ID: ${employee.employeeId}'),
                        value:
                            _selectedEmployeeIds.contains(employee.employeeId),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedEmployeeIds.add(employee.employeeId);
                            } else {
                              _selectedEmployeeIds.remove(employee.employeeId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยชื่อ, รหัส, หรือตำแหน่ง...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterDepartmentId,
            hint: const Text('แสดงพนักงานทั้งหมด'),
            decoration: const InputDecoration(
              labelText: 'กรองตามแผนก',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                  value: null, child: Text("แสดงพนักงานทั้งหมด")),
              ..._allDepartments.map((dept) =>
                  DropdownMenuItem(value: dept.id, child: Text(dept.name))),
            ],
            onChanged: (value) {
              setState(() {
                _filterDepartmentId = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
