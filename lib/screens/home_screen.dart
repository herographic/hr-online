// lib/screens/home_screen.dart

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/leave_request_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/models/work_submission_model.dart';
import 'package:hr_online/screens/all_employees_screen.dart';
import 'package:hr_online/screens/employee/quiz_list_screen.dart';
import 'package:hr_online/screens/leave/leave_approval_list_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/experience_bar.dart';
import 'package:hr_online/widgets/submit_work_dialog.dart';
import 'package:hr_online/widgets/work_submission_card.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const HomeScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _searchQuery = '';
  String? _selectedDepartmentId;
  final _searchController = TextEditingController();
  Timer? _debounce;

  Offset _fabPosition = const Offset(280, 500);

  List<Department> _allDepartments = [];
  Map<String, Employee> _employeesMap = {};

  Timer? _presenceTimer;
  int _pendingQuizzesCount = 0;
  bool _isLoadingQuizzes = true;

  bool _isFeedExpanded = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _updatePresence();
      _startPresenceTimer();
    } else if (state == AppLifecycleState.paused) {
      _presenceTimer?.cancel();
    }
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updatePresence();
    });
  }

  Future<void> _updatePresence() async {
    if (widget.loggedInEmployee != null && !widget.isUserAdmin) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.loggedInEmployee!.employeeId)
            .update({'lastSeen': FieldValue.serverTimestamp()});
      } catch (e) {
        // Silently fail
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (mounted) {
      _updatePresence();
      _startPresenceTimer();
    }

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted && _searchController.text.toLowerCase() != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
          });
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenSize = MediaQuery.of(context).size;
        setState(() {
          _fabPosition =
              Offset(screenSize.width - 80, screenSize.height - 200);
        });
      }
    });
    _fetchFilterData();

    if (widget.loggedInEmployee != null && !widget.isUserAdmin) {
      _fetchPendingQuizzes();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPendingQuizzes() async {
    if (widget.loggedInEmployee == null) return;
    if (mounted) setState(() => _isLoadingQuizzes = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('quiz_assignments')
          .where('employeeId', isEqualTo: widget.loggedInEmployee!.employeeId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (mounted) {
        setState(() {
          _pendingQuizzesCount = snapshot.docs.length;
          _isLoadingQuizzes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingQuizzes = false);
    }
  }

  Future<void> _fetchFilterData() async {
    try {
      final deptsSnapshot = await FirebaseFirestore.instance
          .collection('departments')
          .orderBy('name')
          .get();
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      if (mounted) {
        setState(() {
          _allDepartments =
              deptsSnapshot.docs.map((d) => Department.fromFirestore(d)).toList();
          _employeesMap = {
            for (var doc in usersSnapshot.docs)
              doc.id: Employee.fromFirestore(doc)
          };
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _showSubmitWorkDialog() {
    final employeeToSubmit = widget.isUserAdmin
        ? Employee(
            employeeId: 'admin',
            title: 'Admin',
            firstName: 'ผู้ดูแลระบบ',
            lastName: '',
            nickname: 'Admin',
            gender: '',
            nationalId: '',
            maritalStatus: '',
            address: '',
            phoneNumber: '',
            emergencyContact: {},
            additionalContacts: {},
            details: '',
            departmentCode: '',
            positions: [],
            startDate: Timestamp.now(),
            dailyWorkShifts: {},
            salary: 0,
            bankAccount: {},
          )
        : widget.loggedInEmployee;

    if (employeeToSubmit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้เพื่อส่งงาน')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => SubmitWorkDialog(
        loggedInEmployee: employeeToSubmit,
        allEmployees: _employeesMap.values.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppLayout(
          isUserAdmin: widget.isUserAdmin,
          loggedInEmployee: widget.loggedInEmployee,
          bodySlivers: [
            // --- [START] ADDED CODE: Experience Bar ---
            if (widget.loggedInEmployee != null)
              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.loggedInEmployee!.employeeId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: ExperienceBar(employee: widget.loggedInEmployee!),
                          ),
                        ),
                      );
                    }
                    final updatedEmployee = Employee.fromFirestore(snapshot.data!);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00c6ff), Color(0xFF0072ff)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ExperienceBar(employee: updatedEmployee),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // --- [END] ADDED CODE ---
            const SliverToBoxAdapter(
              child: _GlobalAnnouncementCard(),
            ),
            if (widget.isUserAdmin)
              SliverToBoxAdapter(
                child: _AdminDashboardCard(
                  allEmployeesCount: _employeesMap.length,
                  isUserAdmin: widget.isUserAdmin,
                  loggedInEmployee: widget.loggedInEmployee,
                ),
              ),
            if (widget.loggedInEmployee != null)
              SliverToBoxAdapter(
                child: _AttendanceInfoCard(employee: widget.loggedInEmployee!),
              ),
            SliverToBoxAdapter(
              child: _buildQuizNotificationCard(),
            ),
            SliverToBoxAdapter(child: _buildSearchAndFilter()),
            SliverToBoxAdapter(
              child: _buildFeedHeader(),
            ),
            if (_isFeedExpanded) _buildWorkFeed(),
          ],
        ),
        Positioned(
          left: _fabPosition.dx,
          top: _fabPosition.dy,
          child: Draggable(
            feedback:
                FloatingActionButton(onPressed: () {}, child: const Icon(Icons.edit)),
            onDragEnd: (details) {
              final screenSize = MediaQuery.of(context).size;
              const appBarHeight = 120.0;
              const bottomNavHeight = 80.0;
              setState(() {
                double newX = details.offset.dx.clamp(0, screenSize.width - 56);
                double newY = details.offset.dy
                    .clamp(appBarHeight, screenSize.height - bottomNavHeight - 56);
                _fabPosition = Offset(newX, newY);
              });
            },
            childWhenDragging: Container(),
            child: FloatingActionButton(
              heroTag: 'fab_submit_work',
              onPressed: _showSubmitWorkDialog,
              child: const Icon(Icons.edit),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          title: Text(
            'รายงานการทำงานล่าสุด',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.bold),
          ),
          trailing: IconButton(
            icon: Icon(
                _isFeedExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () {
              setState(() {
                _isFeedExpanded = !_isFeedExpanded;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuizNotificationCard() {
    if (widget.isUserAdmin || _isLoadingQuizzes || _pendingQuizzesCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.amber.shade50,
        child: InkWell(
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(
                  builder: (context) =>
                      QuizListScreen(loggedInEmployee: widget.loggedInEmployee!),
                ))
                .then((_) => _fetchPendingQuizzes());
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.quiz, color: Colors.orange.shade800, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'คุณมีแบบทดสอบที่ต้องทำอยู่ $_pendingQuizzesCount รายการ',
                    style: GoogleFonts.anuphan(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ค้นหา ชื่อ, แผนก, ตำแหน่ง, รหัส...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon:
                  Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDepartmentId,
            hint: Text('ทุกแผนก',
                style: TextStyle(color: Colors.white.withOpacity(0.9))),
            isExpanded: true,
            iconEnabledColor: Colors.white,
            dropdownColor: const Color(0xFF021B79),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('ทุกแผนก')),
              ..._allDepartments
                  .map((dept) =>
                      DropdownMenuItem(value: dept.id, child: Text(dept.name)))
                  .toList()
            ],
            onChanged: (value) => setState(() => _selectedDepartmentId = value),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkFeed() {
    Query query = FirebaseFirestore.instance
        .collection('work_submissions')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          )));
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
              child: Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}')));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverFillRemaining(
              child: Center(child: Text('ยังไม่มีการส่งงาน')));
        }

        var submissions = snapshot.data!.docs
            .map((doc) => WorkSubmission.fromFirestore(doc))
            .toList();

        final filteredSubmissions = submissions.where((submission) {
          final author = _employeesMap[submission.authorId];

          if (_selectedDepartmentId != null &&
              author?.departmentCode != _selectedDepartmentId) {
            return false;
          }

          if (_searchQuery.isNotEmpty) {
            final departmentName = _allDepartments
                    .firstWhereOrNull((d) => d.id == author?.departmentCode)
                    ?.name
                    .toLowerCase() ??
                '';
            final authorPosition =
                author?.positions.map((p) => p['name'] ?? '').join(' ').toLowerCase() ??
                    '';

            return submission.title.toLowerCase().contains(_searchQuery) ||
                submission.details.toLowerCase().contains(_searchQuery) ||
                submission.authorNickname.toLowerCase().contains(_searchQuery) ||
                submission.authorId.contains(_searchQuery) ||
                (author?.fullName.toLowerCase().contains(_searchQuery) ??
                    false) ||
                authorPosition.contains(_searchQuery) ||
                departmentName.contains(_searchQuery);
          }

          return true;
        }).toList();

        if (filteredSubmissions.isEmpty) {
          return const SliverFillRemaining(
              child: Center(child: Text('ไม่พบข้อมูลที่ตรงกับเงื่อนไข')));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => WorkSubmissionCard(
              submission: filteredSubmissions[index],
              isUserAdmin: widget.isUserAdmin,
              loggedInEmployee: widget.loggedInEmployee,
            ),
            childCount: filteredSubmissions.length,
          ),
        );
      },
    );
  }
}

class _GlobalAnnouncementCard extends StatefulWidget {
  const _GlobalAnnouncementCard();

  @override
  State<_GlobalAnnouncementCard> createState() =>
      _GlobalAnnouncementCardState();
}

class _GlobalAnnouncementCardState extends State<_GlobalAnnouncementCard> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() {
    _timer?.cancel();
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
        double newOffset = _scrollController.offset + 1.0;
        if (newOffset >= _scrollController.position.maxScrollExtent) {
          _timer?.cancel();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _scrollController.jumpTo(0);
              _startScrolling();
            }
          });
        } else {
          _scrollController.animateTo(newOffset,
              duration: const Duration(milliseconds: 35), curve: Curves.linear);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('global_announcement')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.data() == null) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final text = data['text'] as String? ?? '';

        if (text.isEmpty) {
          _timer?.cancel();
          return const SizedBox.shrink();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            elevation: 4,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    'ประกาศ:',
                    style: GoogleFonts.anuphan(
                        fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        '$text      ',
                        style: GoogleFonts.anuphan(
                            fontSize: 14, color: Colors.black87),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AttendanceInfoCard extends StatelessWidget {
  final Employee employee;

  const _AttendanceInfoCard({required this.employee});

  Future<Map<String, dynamic>> _fetchAttendanceData() async {
    final now = DateTime.now();
    final docId =
        '${employee.employeeId}_${DateFormat('yyyy-MM-dd').format(now)}';

    final results = await Future.wait([
      FirebaseFirestore.instance.collection('attendance_log').doc(docId).get(),
      FirebaseFirestore.instance.collection('work_shifts').get(),
    ]);

    final attendanceDoc = results[0] as DocumentSnapshot;
    final workShiftsSnapshot = results[1] as QuerySnapshot;

    AttendanceLog? attendanceLog;
    if (attendanceDoc.exists) {
      attendanceLog = AttendanceLog.fromFirestore(attendanceDoc);
    }

    final allShifts =
        workShiftsSnapshot.docs.map((doc) => WorkShift.fromFirestore(doc)).toList();

    return {
      'attendanceLog': attendanceLog,
      'allShifts': allShifts,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAttendanceData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: Colors.white),
          ));
        }

        final data = snapshot.data ?? {};
        final AttendanceLog? log = data['attendanceLog'];
        final List<WorkShift> allShifts = data['allShifts'] ?? [];

        final todayKey = DateFormat('EEEE').format(DateTime.now());
        final shiftId = employee.dailyWorkShifts[todayKey];
        final workShift = allShifts.firstWhereOrNull((s) => s.id == shiftId);

        final String shiftText = workShift != null
            ? 'กะการทำงาน : ${workShift.startTime} - ${workShift.endTime} น.'
            : 'กะการทำงาน : วันหยุด';

        final timeFormat = DateFormat('HH:mm');
        final String checkInTime =
            log?.checkIn != null ? timeFormat.format(log!.checkIn!.toDate()) : '- : -';
        final String breakOutTime =
            log?.breakOut != null ? timeFormat.format(log!.breakOut!.toDate()) : '- : -';
        final String breakInTime =
            log?.breakIn != null ? timeFormat.format(log!.breakIn!.toDate()) : '- : -';
        final String checkOutTime = log?.checkOut != null
            ? timeFormat.format(log!.checkOut!.toDate())
            : '- : -';

        Color checkInColor = Colors.white;
        Color checkOutColor = Colors.white;

        if (workShift != null && log != null) {
          try {
            final startParts = workShift.startTime.split(':');
            final endParts = workShift.endTime.split(':');
            final logDate = log.date.toDate();

            final scheduledCheckIn = DateTime(logDate.year, logDate.month, logDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
            var scheduledCheckOut = DateTime(logDate.year, logDate.month, logDate.day, int.parse(endParts[0]), int.parse(endParts[1]));
            if (scheduledCheckOut.isBefore(scheduledCheckIn)) {
              scheduledCheckOut = scheduledCheckOut.add(const Duration(days: 1));
            }

            if (log.checkIn != null) {
              final actualCheckIn = log.checkIn!.toDate();
              if (actualCheckIn.isAfter(scheduledCheckIn.add(const Duration(minutes: 1)))) {
                checkInColor = Colors.red.shade300;
              } else {
                checkInColor = Colors.lightGreenAccent;
              }
            }

            if (log.checkOut != null) {
              final actualCheckOut = log.checkOut!.toDate();
              if (actualCheckOut.isBefore(scheduledCheckOut)) {
                checkOutColor = Colors.red.shade300;
              } else {
                checkOutColor = Colors.lightGreenAccent;
              }
            }
          } catch (e) {
            // ignore parsing errors
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE ที่ d MMMM พ.ศ. yyyy', 'th_TH')
                        .format(DateTime.now()),
                    style: GoogleFonts.anuphan(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shiftText,
                    style: GoogleFonts.anuphan(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const Divider(color: Colors.white30, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeDisplay('เข้างาน', checkInTime, color: checkInColor),
                      _buildTimeDisplay('ออกพัก', breakOutTime),
                      _buildTimeDisplay('เข้าพัก', breakInTime),
                      _buildTimeDisplay('ออกงาน', checkOutTime, color: checkOutColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay(String label, String time, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.anuphan(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: GoogleFonts.orbitron(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AdminDashboardCard extends StatelessWidget {
  final int allEmployeesCount;
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const _AdminDashboardCard({
    required this.allEmployeesCount,
    required this.isUserAdmin,
    required this.loggedInEmployee,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Admin Dashboard',
                style: GoogleFonts.anuphan(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.white30, height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance_log')
                    .where('date', isEqualTo: startOfDay)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('leave_requests')
                        .where('status', isEqualTo: 'approved')
                        .snapshots(),
                    builder: (context, leaveSnapshot) {
                      if (attendanceSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          leaveSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: Colors.white));
                      }

                      final checkedInCount =
                          attendanceSnapshot.data?.docs.length ?? 0;

                      final onLeaveTodayDocs =
                          leaveSnapshot.data?.docs.where((doc) {
                                final leave = LeaveRequest.fromFirestore(doc);
                                final leaveStart = leave.startDate.toDate();
                                final leaveEnd = leave.endDate.toDate();
                                return leaveStart.isBefore(endOfDay) &&
                                    leaveEnd.isAfter(startOfDay);
                              }).toList() ??
                              [];

                      final onLeaveCount = onLeaveTodayDocs.length;

                      final absentCount =
                          allEmployeesCount - checkedInCount - onLeaveCount;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatDisplay('พนักงานทั้งหมด',
                              allEmployeesCount.toString(), context, null),
                          _buildStatDisplay(
                              'เข้างาน', checkedInCount.toString(), context, () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AllEmployeesScreen(
                                        isUserAdmin: isUserAdmin,
                                        loggedInEmployee: loggedInEmployee)));
                          }),
                          _buildStatDisplay('ขาด/ลางาน',
                              (absentCount + onLeaveCount).toString(), context,
                              () {
                            if (loggedInEmployee != null) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LeaveApprovalListScreen(
                                          loggedInEmployee: loggedInEmployee!,
                                          isUserAdmin: isUserAdmin)));
                            }
                          }),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatDisplay(
      String label, String value, BuildContext context, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.anuphan(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: onTap != null
                    ? [
                        const Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 2))
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
