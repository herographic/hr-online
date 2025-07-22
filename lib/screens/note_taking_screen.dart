// lib/screens/note_taking_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/screens/employee_note_detail_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/employee_presence_node.dart';
import 'package:provider/provider.dart';

// Enum for sorting modes, shared with AllEmployeesScreen
enum SortMode { byStatus, byId, byNickname, byPosition }

class NoteTakingScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const NoteTakingScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<NoteTakingScreen> createState() => _NoteTakingScreenState();
}

class _NoteTakingScreenState extends State<NoteTakingScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _debounce;
  SortMode _sortMode = SortMode.byStatus; // Default sort mode

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _searchController.text.toLowerCase() != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }
  
  String _getSortModeLabel(SortMode mode) {
    switch (mode) {
      case SortMode.byStatus:
        return 'เรียงตามสถานะ';
      case SortMode.byId:
        return 'เรียงตามรหัส';
      case SortMode.byNickname:
        return 'เรียงตามชื่อเล่น';
      case SortMode.byPosition:
        return 'เรียงตามตำแหน่ง';
    }
  }

  @override
  Widget build(BuildContext context) {
    const newGradient = LinearGradient(
      colors: [Color(0xFF0575E6), Color(0xFF021B79)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'จดบันทึก',
      showBackButton: false,
      bodyGradient: newGradient,
      bodySlivers: [
        _buildControlHeader(),
        _buildEmployeeList(),
      ],
    );
  }

  Widget _buildControlHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อเล่น, รหัส, ตำแหน่ง...',
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
             const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<SortMode>(
                      initialValue: _sortMode,
                      onSelected: (SortMode item) {
                        setState(() {
                          _sortMode = item;
                        });
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<SortMode>>[
                        const PopupMenuItem<SortMode>(
                          value: SortMode.byStatus,
                          child: Text('เรียงตามสถานะ'),
                        ),
                        const PopupMenuItem<SortMode>(
                          value: SortMode.byId,
                          child: Text('เรียงตามรหัส'),
                        ),
                        const PopupMenuItem<SortMode>(
                          value: SortMode.byNickname,
                          child: Text('เรียงตามชื่อเล่น'),
                        ),
                        const PopupMenuItem<SortMode>(
                          value: SortMode.byPosition,
                          child: Text('เรียงตามตำแหน่ง'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sort, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _getSortModeLabel(_sortMode),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    final attendanceProvider = Provider.of<AttendanceStatusProvider>(context, listen: false);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverFillRemaining(
              child: Center(child: Text('ไม่มีข้อมูลพนักงาน', style: TextStyle(color: Colors.white))));
        }

        var allEmployees = snapshot.data!.docs
            .map((doc) => Employee.fromFirestore(doc))
            .toList();

        // Filtering
        final filteredEmployees = allEmployees.where((employee) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          final nickname = employee.nickname.toLowerCase();
          final employeeId = employee.employeeId.toLowerCase();
          final positionText = employee.positions.map((p) => p['name'] ?? '').join(' ').toLowerCase();
          return nickname.contains(query) ||
              employeeId.contains(query) ||
              positionText.contains(query);
        }).toList();

        // Sorting
        filteredEmployees.sort((a, b) {
          switch (_sortMode) {
            case SortMode.byStatus:
              final statusA = attendanceProvider.statuses[a.employeeId] ?? EmployeeAttendanceStatus.unknown;
              final statusB = attendanceProvider.statuses[b.employeeId] ?? EmployeeAttendanceStatus.unknown;
              int scoreA = _getStatusScore(statusA);
              int scoreB = _getStatusScore(statusB);
              if (scoreA != scoreB) return scoreB.compareTo(scoreA);
              return a.employeeId.compareTo(b.employeeId);
            case SortMode.byId:
              return a.employeeId.compareTo(b.employeeId);
            case SortMode.byNickname:
              return a.nickname.compareTo(b.nickname);
            case SortMode.byPosition:
              final posA = a.positions.isNotEmpty ? a.positions.first['name'] ?? '' : '';
              final posB = b.positions.isNotEmpty ? b.positions.first['name'] ?? '' : '';
              if (posA != posB) return posA.compareTo(posB);
              return a.employeeId.compareTo(b.employeeId);
          }
        });

        if (filteredEmployees.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'ไม่พบข้อมูลที่ค้นหา',
                style: GoogleFonts.anuphan(color: Colors.white, fontSize: 16),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130.0,
              mainAxisSpacing: 20.0,
              crossAxisSpacing: 20.0,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final employee = filteredEmployees[index];
                return EmployeePresenceNode(
                  employeeId: employee.employeeId,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => EmployeeNoteDetailScreen(
                        employee: employee,
                        loggedInEmployee: widget.loggedInEmployee,
                      ),
                    ));
                  },
                );
              },
              childCount: filteredEmployees.length,
            ),
          ),
        );
      },
    );
  }

  int _getStatusScore(EmployeeAttendanceStatus status) {
    switch (status) {
      case EmployeeAttendanceStatus.checkedIn: return 4;
      case EmployeeAttendanceStatus.dayOff: return 3;
      case EmployeeAttendanceStatus.checkedOut: return 2;
      case EmployeeAttendanceStatus.absent: return 1;
      case EmployeeAttendanceStatus.unknown:
      default: return 0;
    }
  }
}
