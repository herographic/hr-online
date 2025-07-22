// lib/screens/master_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/job_description_model.dart';
import 'package:hr_online/models/position_model.dart';
import 'package:hr_online/models/qr_location_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/models/work_shift_type_model.dart';
import 'package:hr_online/screens/admin/job_description_management_screen.dart';
import 'package:hr_online/screens/manage_employee_roles_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class MasterSettingsScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const MasterSettingsScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<MasterSettingsScreen> createState() => _MasterSettingsScreenState();
}

class _MasterSettingsScreenState extends State<MasterSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _positionsSelectedDeptId;
  String? _shiftsSelectedTypeId;

  final List<String> _tabs = [
    'กำหนดสิทธิ์',
    'รายละเอียดงาน',
    'แผนก',
    'ตำแหน่ง',
    'กะทำงาน',
    'สร้าง QR Code',
    'ธนาคาร',
    'คำนำหน้า',
    'ประเภท พนง.',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget? _buildCurrentFab(BuildContext context) {
    switch (_tabController.index) {
      case 1: // Job Descriptions
        return _buildFloatingActionButton(context,
            onPressed: () => _showJobDescriptionDialog(context),
            tooltip: 'เพิ่มรายละเอียดงาน');
      case 2: // Departments
        return _buildFloatingActionButton(context,
            onPressed: () => _showDeptDialog(context), tooltip: 'เพิ่มแผนก');
      case 3: // Positions
        if (_positionsSelectedDeptId != null) {
          return _buildFloatingActionButton(context,
              onPressed: () =>
                  _showPosDialog(context, _positionsSelectedDeptId!),
              tooltip: 'เพิ่มตำแหน่ง');
        }
        return null;
      case 4: // Work Shifts
        if (_shiftsSelectedTypeId != null) {
          return _buildFloatingActionButton(context,
              onPressed: () =>
                  _showShiftDialog(context, _shiftsSelectedTypeId!),
              tooltip: 'เพิ่มเวลาทำงาน');
        }
        return null;
      case 5: // QR Generator
        return _buildFloatingActionButton(context,
            onPressed: () => _showLocationDialog(context),
            tooltip: 'เพิ่มพื้นที่');
      case 6: // Banks
        return _buildFloatingActionButton(context,
            onPressed: () => _showSimpleMasterDialog(context,
                collectionPath: 'banks', title: 'ธนาคาร'),
            tooltip: 'เพิ่มธนาคาร');
      case 7: // Titles
        return _buildFloatingActionButton(context,
            onPressed: () => _showSimpleMasterDialog(context,
                collectionPath: 'titles', title: 'คำนำหน้า'),
            tooltip: 'เพิ่มคำนำหน้า');
      case 8: // Employee Types
        return _buildFloatingActionButton(context,
            onPressed: () => _showSimpleMasterDialog(context,
                collectionPath: 'employee_types', title: 'ประเภทพนักงาน'),
            tooltip: 'เพิ่มประเภท');
      default:
        return null;
    }
  }

  void _showJobDescriptionDialog(BuildContext context,
          {JobDescription? jobDescription}) =>
      showDialog(
          context: context,
          builder: (_) =>
              _JobDescriptionDialog(jobDescription: jobDescription));
  void _showDeptDialog(BuildContext context, {Department? dept}) =>
      showDialog(
          context: context,
          builder: (_) => _DepartmentDialog(department: dept));
  void _showPosDialog(BuildContext context, String departmentId,
          {Position? pos}) =>
      showDialog(
          context: context,
          builder: (_) =>
              _PositionDialog(departmentId: departmentId, position: pos));
  void _showShiftDialog(BuildContext context, String typeId,
          {WorkShift? shift}) =>
      showDialog(
          context: context,
          builder: (_) => _WorkShiftDialog(typeId: typeId, shift: shift));
  void _showLocationDialog(BuildContext context, {QrLocation? location}) =>
      showDialog(
          context: context,
          builder: (_) => _QrLocationDialog(location: location));
  void _showSimpleMasterDialog(BuildContext context,
          {required String collectionPath,
          required String title,
          DocumentSnapshot? doc}) =>
      showDialog(
          context: context,
          builder: (_) => _SimpleMasterDialog(
              collectionPath: collectionPath, title: title, doc: doc));

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'จัดการข้อมูลหลัก',
      floatingActionButton: _buildCurrentFab(context),
      bodySlivers: [
        SliverPersistentHeader(
          delegate: _SliverTabBarDelegate(
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              indicatorColor: Colors.yellowAccent,
              indicatorWeight: 3.0,
              tabs: _tabs.map((title) => Tab(text: title)).toList(),
            ),
          ),
          pinned: true,
        ),
        SliverFillRemaining(
          child: Container(
            color: Colors.grey[100],
            child: TabBarView(
              controller: _tabController,
              children: [
                const AssignRolesTab(),
                const JobDescriptionManagementTab(),
                const DepartmentsTab(),
                PositionsTab(
                  selectedDeptId: _positionsSelectedDeptId,
                  onDeptChanged: (value) =>
                      setState(() => _positionsSelectedDeptId = value),
                ),
                WorkShiftsTab(
                  selectedTypeId: _shiftsSelectedTypeId,
                  onTypeChanged: (value) =>
                      setState(() => _shiftsSelectedTypeId = value),
                ),
                const QrGeneratorTab(),
                const SimpleMasterDataTab(
                    collectionPath: 'banks', title: 'ธนาคาร'),
                const SimpleMasterDataTab(
                    collectionPath: 'titles', title: 'คำนำหน้า'),
                const SimpleMasterDataTab(
                    collectionPath: 'employee_types', title: 'ประเภทพนักงาน'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);
  final TabBar tabBar;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0072ff),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

Widget _buildFloatingActionButton(BuildContext context,
    {required VoidCallback onPressed, required String tooltip}) {
  return FloatingActionButton(
    onPressed: onPressed,
    tooltip: tooltip,
    child: const Icon(Icons.add),
  );
}

class AssignRolesTab extends StatefulWidget {
  const AssignRolesTab({super.key});
  @override
  State<AssignRolesTab> createState() => _AssignRolesTabState();
}

class _AssignRolesTabState extends State<AssignRolesTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยชื่อ หรือรหัสพนักงาน...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('employee_name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('ไม่มีข้อมูลพนักงาน'));
              }
              final employees = snapshot.data!.docs
                  .map((doc) => Employee.fromFirestore(doc))
                  .where((emp) {
                if (_searchQuery.isEmpty) return true;
                return emp.fullName.toLowerCase().contains(_searchQuery) ||
                    emp.employeeId.contains(_searchQuery);
              }).toList();
              if (employees.isEmpty) {
                return const Center(child: Text('ไม่พบข้อมูลที่ค้นหา'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: EmployeeAvatar(
                          imageUrl: employee.profileImageUrl,
                          gender: employee.gender,
                          radius: 20),
                      title: Row(
                        children: [
                          Text(employee.fullName,
                              style: GoogleFonts.anuphan(fontSize: 16)),
                          if (employee.isAdmin) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.shield,
                                color: Theme.of(context).primaryColor,
                                size: 18),
                          ]
                        ],
                      ),
                      subtitle: Text('ID: ${employee.employeeId}'),
                      trailing: const Icon(Icons.edit_note_outlined,
                          color: Colors.grey),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => ManageEmployeeRolesScreen(
                                  employee: employee))),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class DepartmentsTab extends StatelessWidget {
  const DepartmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('departments')
          .orderBy('name')
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('ไม่มีข้อมูลแผนก\nกดปุ่ม + เพื่อเพิ่ม'));
        }
        final departments = snapshot.data!.docs
            .map((doc) => Department.fromFirestore(doc))
            .toList();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: departments.length,
          itemBuilder: (ctx, index) {
            final dept = departments[index];
            return ListTile(
              title: Text(dept.name),
              trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      (context.findAncestorStateOfType<_MasterSettingsScreenState>())
                          ?._showDeptDialog(context, dept: dept)),
            );
          },
        );
      },
    );
  }
}

class PositionsTab extends StatelessWidget {
  final String? selectedDeptId;
  final ValueChanged<String?> onDeptChanged;

  const PositionsTab(
      {super.key, required this.selectedDeptId, required this.onDeptChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('departments')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final departments = snapshot.data!.docs
                  .map((doc) => Department.fromFirestore(doc))
                  .toList();
              return DropdownButtonFormField<String>(
                value: selectedDeptId,
                hint: const Text('เลือกแผนกเพื่อจัดการตำแหน่ง'),
                isExpanded: true,
                items: departments
                    .map((dept) =>
                        DropdownMenuItem(value: dept.id, child: Text(dept.name)))
                    .toList(),
                onChanged: onDeptChanged,
              );
            },
          ),
        ),
        Expanded(
          child: selectedDeptId == null
              ? const Center(child: Text('กรุณาเลือกแผนก'))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('positions')
                      .where('departmentId', isEqualTo: selectedDeptId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child:
                              Text('ไม่มีตำแหน่งในแผนกนี้\nกดปุ่ม + เพื่อเพิ่ม'));
                    }
                    final positions = snapshot.data!.docs
                        .map((doc) => Position.fromFirestore(doc))
                        .toList();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                      itemCount: positions.length,
                      itemBuilder: (ctx, index) {
                        final pos = positions[index];
                        return ListTile(
                          title: Text(pos.name),
                          trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => (context
                                      .findAncestorStateOfType<
                                          _MasterSettingsScreenState>())
                                  ?._showPosDialog(context, selectedDeptId!,
                                      pos: pos)),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class WorkShiftsTab extends StatelessWidget {
  final String? selectedTypeId;
  final ValueChanged<String?> onTypeChanged;

  const WorkShiftsTab(
      {super.key, this.selectedTypeId, required this.onTypeChanged});

  void _showTypeDialog(BuildContext context, {WorkShiftType? type}) {
    final nameController = TextEditingController(text: type?.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == null ? 'เพิ่มประเภทกะ' : 'แก้ไขประเภทกะ'),
        content: TextField(
            controller: nameController,
            decoration:
                const InputDecoration(labelText: 'ชื่อประเภท (เช่น Full-time)'),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final collection =
                    FirebaseFirestore.instance.collection('work_shift_types');
                if (type == null) {
                  await collection.add({'name': nameController.text});
                } else {
                  await collection
                      .doc(type.id)
                      .update({'name': nameController.text});
                }
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
    return Column(
      children: [
        ListTile(
          title: const Text("จัดการประเภทกะทำงาน",
              style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: () => _showTypeDialog(context)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('work_shift_types')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final types = snapshot.data!.docs
                  .map((doc) => WorkShiftType.fromFirestore(doc))
                  .toList();
              return DropdownButtonFormField<String>(
                value: selectedTypeId,
                hint: const Text('เลือกประเภทกะเพื่อจัดการเวลาทำงาน'),
                onChanged: onTypeChanged,
                items: types
                    .map((type) => DropdownMenuItem(
                        value: type.id, child: Text(type.name)))
                    .toList(),
              );
            },
          ),
        ),
        Expanded(
          child: selectedTypeId == null
              ? const Center(child: Text('กรุณาเลือกประเภทกะ'))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('work_shifts')
                      .where('typeId', isEqualTo: selectedTypeId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text(
                              'ไม่มีเวลาทำงานในประเภทนี้\nกดปุ่ม + เพื่อเพิ่ม'));
                    }

                    final shifts = snapshot.data!.docs
                        .map((doc) => WorkShift.fromFirestore(doc))
                        .toList();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                      itemCount: shifts.length,
                      itemBuilder: (ctx, index) {
                        final shift = shifts[index];
                        return ListTile(
                          title: Text(shift.name),
                          subtitle: Text(shift.displayTime),
                          trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => (context
                                      .findAncestorStateOfType<
                                          _MasterSettingsScreenState>())
                                  ?._showShiftDialog(context, selectedTypeId!,
                                      shift: shift)),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class QrGeneratorTab extends StatelessWidget {
  const QrGeneratorTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('qr_locations')
          .orderBy('name')
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('ยังไม่มีพื้นที่\nกดปุ่ม + เพื่อเพิ่ม'));
        }
        final locations = snapshot.data!.docs
            .map((doc) => QrLocation.fromFirestore(doc))
            .toList();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: locations.length,
          itemBuilder: (ctx, index) {
            final loc = locations[index];
            final hasGps = loc.latitude != null && loc.longitude != null;
            return ListTile(
              leading: Icon(
                  hasGps ? Icons.location_on : Icons.qr_code_2_sharp,
                  color: hasGps ? Colors.blue : null),
              title: Text(loc.name, style: GoogleFonts.anuphan()),
              subtitle: hasGps
                  ? Text('รัศมี: ${loc.radius ?? 'N/A'} เมตร',
                      style: GoogleFonts.anuphan(fontSize: 12))
                  : null,
              onTap: () {
                final qrData = 'HRLOC::${loc.id}';
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('QR Code สำหรับ: ${loc.name}'),
                          content: SizedBox(
                              width: 250,
                              height: 250,
                              child: QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 250.0)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('ปิด'))
                          ],
                        ));
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () =>
                        (context.findAncestorStateOfType<_MasterSettingsScreenState>())
                            ?._showLocationDialog(context, location: loc),
                    tooltip: 'แก้ไข',
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance
                        .collection('qr_locations')
                        .doc(loc.id)
                        .delete(),
                    tooltip: 'ลบ',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class SimpleMasterDataTab extends StatelessWidget {
  final String collectionPath;
  final String title;
  const SimpleMasterDataTab(
      {super.key, required this.collectionPath, required this.title});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy('name')
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('ไม่มีข้อมูล$title\nกดปุ่ม + เพื่อเพิ่ม'));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: docs.length,
          itemBuilder: (ctx, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name'] ?? ''),
              trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => (context
                          .findAncestorStateOfType<_MasterSettingsScreenState>())
                      ?._showSimpleMasterDialog(context,
                          collectionPath: collectionPath,
                          title: title,
                          doc: doc)),
            );
          },
        );
      },
    );
  }
}

// --- DIALOG WIDGETS (NOW STATEFUL) ---

class _DepartmentDialog extends StatefulWidget {
  final Department? department;
  const _DepartmentDialog({this.department});

  @override
  State<_DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends State<_DepartmentDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.department?.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.department == null ? 'เพิ่มแผนกใหม่' : 'แก้ไขแผนก'),
      content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'ชื่อแผนก'),
          autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty) {
              final collection =
                  FirebaseFirestore.instance.collection('departments');
              if (widget.department == null) {
                await collection.add({
                  'name': _nameController.text,
                  'createdAt': FieldValue.serverTimestamp()
                });
              } else {
                await collection
                    .doc(widget.department!.id)
                    .update({'name': _nameController.text});
              }
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _PositionDialog extends StatefulWidget {
  final String departmentId;
  final Position? position;
  const _PositionDialog({required this.departmentId, this.position});

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.position?.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.position == null ? 'เพิ่มตำแหน่งใหม่' : 'แก้ไขตำแหน่ง'),
      content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'ชื่อตำแหน่ง'),
          autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty) {
              final collection =
                  FirebaseFirestore.instance.collection('positions');
              final data = {
                'name': _nameController.text,
                'departmentId': widget.departmentId
              };
              if (widget.position == null) {
                await collection.add(data);
              } else {
                await collection.doc(widget.position!.id).update(data);
              }
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _WorkShiftDialog extends StatefulWidget {
  final String typeId;
  final WorkShift? shift;
  const _WorkShiftDialog({required this.typeId, this.shift});

  @override
  State<_WorkShiftDialog> createState() => _WorkShiftDialogState();
}

class _WorkShiftDialogState extends State<_WorkShiftDialog> {
  late TextEditingController _nameController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shift?.name);
    _startTimeController = TextEditingController(text: widget.shift?.startTime);
    _endTimeController = TextEditingController(text: widget.shift?.endTime);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.shift == null ? 'เพิ่มเวลาทำงาน' : 'แก้ไขเวลาทำงาน'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'ชื่อกะ (เช่น กะเช้า)'),
                validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null),
            TextFormField(
              controller: _startTimeController,
              decoration:
                  const InputDecoration(labelText: 'เวลาเริ่ม', hintText: 'HH:mm'),
              readOnly: true,
              onTap: () async {
                TimeOfDay? picked = await showTimePicker(
                    context: context, initialTime: TimeOfDay.now());
                if (picked != null) {
                  if (mounted) {
                    _startTimeController.text = picked.format(context);
                  }
                }
              },
              validator: (v) => v!.isEmpty ? 'กรุณาเลือกเวลา' : null,
            ),
            TextFormField(
              controller: _endTimeController,
              decoration: const InputDecoration(
                  labelText: 'เวลาสิ้นสุด', hintText: 'HH:mm'),
              readOnly: true,
              onTap: () async {
                TimeOfDay? picked = await showTimePicker(
                    context: context, initialTime: TimeOfDay.now());
                if (picked != null) {
                  if (mounted) {
                    _endTimeController.text = picked.format(context);
                  }
                }
              },
              validator: (v) => v!.isEmpty ? 'กรุณาเลือกเวลา' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final collection =
                  FirebaseFirestore.instance.collection('work_shifts');
              final data = {
                'name': _nameController.text,
                'startTime': _startTimeController.text,
                'endTime': _endTimeController.text,
                'typeId': widget.typeId
              };
              if (widget.shift == null) {
                await collection.add(data);
              } else {
                await collection.doc(widget.shift!.id).update(data);
              }
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _QrLocationDialog extends StatefulWidget {
  final QrLocation? location;
  const _QrLocationDialog({this.location});

  @override
  State<_QrLocationDialog> createState() => _QrLocationDialogState();
}

class _QrLocationDialogState extends State<_QrLocationDialog> {
  late TextEditingController _nameController;
  late TextEditingController _latController;
  late TextEditingController _lonController;
  late TextEditingController _radiusController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?.name ?? '');
    _latController =
        TextEditingController(text: widget.location?.latitude?.toString() ?? '');
    _lonController =
        TextEditingController(text: widget.location?.longitude?.toString() ?? '');
    _radiusController =
        TextEditingController(text: widget.location?.radius?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.location == null ? 'เพิ่มพื้นที่ใหม่' : 'แก้ไขชื่อพื้นที่'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'ชื่อพื้นที่ (เช่น ประตูหน้า)'),
                autofocus: true,
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'กรุณากรอกชื่อพื้นที่'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _latController,
                decoration:
                    const InputDecoration(labelText: 'ละติจูด (Latitude)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _lonController,
                decoration:
                    const InputDecoration(labelText: 'ลองจิจูด (Longitude)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _radiusController,
                decoration:
                    const InputDecoration(labelText: 'รัศมีที่อนุญาต (เมตร)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final data = {
                'name': _nameController.text.trim(),
                'latitude': double.tryParse(_latController.text),
                'longitude': double.tryParse(_lonController.text),
                'radius': double.tryParse(_radiusController.text),
              };

              try {
                final collection =
                    FirebaseFirestore.instance.collection('qr_locations');
                if (widget.location == null) {
                  await collection.add(data);
                } else {
                  await collection.doc(widget.location!.id).update(data);
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                // Handle error
              }
            }
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _SimpleMasterDialog extends StatefulWidget {
  final String collectionPath;
  final String title;
  final DocumentSnapshot? doc;
  const _SimpleMasterDialog(
      {required this.collectionPath, required this.title, this.doc});

  @override
  State<_SimpleMasterDialog> createState() => _SimpleMasterDialogState();
}

class _SimpleMasterDialogState extends State<_SimpleMasterDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.doc != null
            ? (widget.doc!.data() as Map<String, dynamic>)['name']
            : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.doc == null ? 'เพิ่ม${widget.title}' : 'แก้ไข${widget.title}'),
      content: TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'ชื่อ${widget.title}'),
          autofocus: true),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isNotEmpty) {
              final collection =
                  FirebaseFirestore.instance.collection(widget.collectionPath);
              if (widget.doc == null) {
                await collection.add({'name': _nameController.text});
              } else {
                await collection
                    .doc(widget.doc!.id)
                    .update({'name': _nameController.text});
              }
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text('บันทึก'),
        ),
      ],
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

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
