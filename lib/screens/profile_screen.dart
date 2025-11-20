// lib/screens/profile_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:hr_online/screens/profile/face_registration_screen.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:hr_online/widgets/experience_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final Employee employee;

  const ProfileScreen({super.key, required this.employee});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;
  bool _isLoading = false;

  // Controllers for editable fields
  late TextEditingController _nicknameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactPhoneController;
  late TextEditingController _closeColleagueNameController;
  late TextEditingController _closeColleaguePhoneController;
  late TextEditingController _closeFriend1NameController;
  late TextEditingController _closeFriend1PhoneController;
  late TextEditingController _closeFriend2NameController;
  late TextEditingController _closeFriend2PhoneController;
  late TextEditingController _supervisorNameController;
  late TextEditingController _supervisorPhoneController;
  late TextEditingController _detailsController;

  String? _selectedMaritalStatus;
  Uint8List? _imageBytes;
  String? _networkImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers(widget.employee);
  }

  void _initializeControllers(Employee emp) {
    _networkImageUrl = emp.profileImageUrl;
    _selectedMaritalStatus = emp.maritalStatus;
    
    final addContacts = emp.additionalContacts;
    _nicknameController = TextEditingController(text: emp.nickname);
    _phoneController = TextEditingController(text: emp.phoneNumber);
    _addressController = TextEditingController(text: emp.address);
    _emergencyContactNameController = TextEditingController(text: emp.emergencyContact['name']);
    _emergencyContactPhoneController = TextEditingController(text: emp.emergencyContact['phone']);
    _detailsController = TextEditingController(text: emp.details);
    _closeColleagueNameController = TextEditingController(text: addContacts['close_colleague_name']);
    _closeColleaguePhoneController = TextEditingController(text: addContacts['close_colleague_phone']);
    _closeFriend1NameController = TextEditingController(text: addContacts['close_friend1_name']);
    _closeFriend1PhoneController = TextEditingController(text: addContacts['close_friend1_phone']);
    _closeFriend2NameController = TextEditingController(text: addContacts['close_friend2_name']);
    _closeFriend2PhoneController = TextEditingController(text: addContacts['close_friend2_phone']);
    _supervisorNameController = TextEditingController(text: addContacts['supervisor_name']);
    _supervisorPhoneController = TextEditingController(text: addContacts['supervisor_phone']);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _closeColleagueNameController.dispose();
    _closeColleaguePhoneController.dispose();
    _closeFriend1NameController.dispose();
    _closeFriend1PhoneController.dispose();
    _closeFriend2NameController.dispose();
    _closeFriend2PhoneController.dispose();
    _supervisorNameController.dispose();
    _supervisorPhoneController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _initializeControllers(widget.employee);
        _imageBytes = null;
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (pickedFile != null && mounted) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _networkImageUrl;
      if (_imageBytes != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${widget.employee.employeeId}.jpg');
        await storageRef.putData(_imageBytes!);
        imageUrl = await storageRef.getDownloadURL();
      }

      final Map<String, dynamic> updatedData = {
        'employee_nickname': _nicknameController.text.trim(),
        'profile_image_url': imageUrl,
        'marital_status': _selectedMaritalStatus ?? '',
        'address': _addressController.text.trim(),
        'mobilephone': _phoneController.text.trim(),
        'emergency_contact': {
          'name': _emergencyContactNameController.text.trim(),
          'phone': _emergencyContactPhoneController.text.trim(),
        },
        'additionalContacts': {
          'close_colleague_name': _closeColleagueNameController.text.trim(),
          'close_colleague_phone': _closeColleaguePhoneController.text.trim(),
          'close_friend1_name': _closeFriend1NameController.text.trim(),
          'close_friend1_phone': _closeFriend1PhoneController.text.trim(),
          'close_friend2_name': _closeFriend2NameController.text.trim(),
          'close_friend2_phone': _closeFriend2PhoneController.text.trim(),
          'supervisor_name': _supervisorNameController.text.trim(),
          'supervisor_phone': _supervisorPhoneController.text.trim(),
        },
        'details': _detailsController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.employee.employeeId).update(updatedData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ'), backgroundColor: Colors.green));
      setState(() {
        _isEditMode = false;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'แก้ไขข้อมูลส่วนตัว' : 'ข้อมูลส่วนตัว'),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))
          else if (_isEditMode)
            IconButton(icon: const Icon(Icons.save_alt_outlined), tooltip: 'บันทึก', onPressed: _saveProfile)
          else
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'แก้ไข', onPressed: _toggleEditMode),
          if (_isEditMode)
            IconButton(icon: const Icon(Icons.close), tooltip: 'ยกเลิก', onPressed: _toggleEditMode),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.employee.employeeId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลพนักงาน'));
          }
          
          final employee = Employee.fromFirestore(snapshot.data!);
          if (!_isEditMode) {
             _initializeControllers(employee);
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildHeader(context, employee),
                const SizedBox(height: 16),
                // --- [START] ADDED CODE: Experience Bar with background ---
                Card(
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
                    child: ExperienceBar(employee: employee),
                  ),
                ),
                // --- [END] ADDED CODE ---
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'ความปลอดภัย',
                  icon: Icons.face_retouching_natural,
                  children: [
                    ListTile(
                      title: const Text('จัดการข้อมูลใบหน้า'),
                      subtitle: const Text('ใช้สำหรับลงทะเบียนใบหน้าเพื่อยืนยันตัวตน'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => FaceRegistrationScreen(employee: employee),
                        ));
                      },
                    )
                  ]
                ),
                const SizedBox(height: 16),
                _buildPersonalInfoCard(employee),
                const SizedBox(height: 16),
                _buildWorkInfoCard(employee),
                const SizedBox(height: 16),
                _buildAdditionalInfoCard(employee),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Employee employee) {
    ImageProvider? imageProvider;
    if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (_networkImageUrl != null) {
      imageProvider = NetworkImage(_networkImageUrl!);
    }

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: imageProvider,
                child: (imageProvider == null) ? Icon(Icons.person, size: 60, color: Colors.grey.shade400) : null,
              ),
              if (_isEditMode)
                Positioned(
                  bottom: 0, right: 0,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(employee.fullName, style: GoogleFonts.anuphan(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('ID: ${employee.employeeId}', style: GoogleFonts.anuphan(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(Employee employee) {
    final thaiDateFormat = DateFormat('d MMMM yyyy', 'th_TH');
    return _buildInfoCard(
      context,
      title: 'ข้อมูลส่วนตัว',
      icon: Icons.person_outline,
      children: [
        _buildReadOnlyField('ชื่อ-สกุล:', '${employee.title} ${employee.fullName}'),
        _isEditMode
            ? _buildEditableField(_nicknameController, 'ชื่อเล่น:')
            : _buildReadOnlyField('ชื่อเล่น:', employee.nickname),
        _buildReadOnlyField('เพศ:', employee.gender),
        _buildReadOnlyField('วันเกิด:', employee.birthDate != null ? thaiDateFormat.format(employee.birthDate!.toDate()) : '-'),
        _isEditMode
            ? _buildDropdownField('สถานภาพ:', _selectedMaritalStatus, ['โสด', 'สมรส', 'หย่าร้าง', 'หม้าย'], (val) => setState(() => _selectedMaritalStatus = val))
            : _buildReadOnlyField('สถานภาพ:', employee.maritalStatus),
        _buildReadOnlyField('เลขบัตรประชาชน:', employee.nationalId),
        _isEditMode
            ? _buildEditableField(_phoneController, 'เบอร์โทร:', keyboardType: TextInputType.phone)
            : _buildPhoneInfoRow('เบอร์โทร:', employee.phoneNumber),
        _isEditMode
            ? _buildEditableField(_addressController, 'ที่อยู่:', maxLines: 3)
            : _buildReadOnlyField('ที่อยู่:', employee.address),
      ],
    );
  }
  
  Widget _buildWorkInfoCard(Employee employee) {
    final thaiDateFormat = DateFormat('d MMMM yyyy', 'th_TH');
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchRelatedData(employee),
      builder: (context, snapshot) {
        final departmentName = snapshot.data?['departmentName'] ?? (snapshot.connectionState == ConnectionState.waiting ? '...' : 'N/A');
        final positionNames = employee.positions.isNotEmpty ? employee.positions.map((p) => p['name'] ?? '').join(', ') : 'ยังไม่ได้กำหนด';

        return _buildInfoCard(
          context,
          title: 'ข้อมูลการทำงาน',
          icon: Icons.work_outline,
          children: [
            _buildReadOnlyField('แผนก:', departmentName),
            _buildReadOnlyField('ตำแหน่ง:', positionNames),
            _buildReadOnlyField('วันเริ่มงาน:', thaiDateFormat.format(employee.startDate.toDate())),
          ],
        );
      }
    );
  }

  Widget _buildAdditionalInfoCard(Employee employee) {
    return _buildInfoCard(
      context,
      title: 'ข้อมูลเพิ่มเติม',
      icon: Icons.note_alt_outlined,
      children: [
        _isEditMode
            ? _buildContactPair(_emergencyContactNameController, _emergencyContactPhoneController, 'ผู้ติดต่อฉุกเฉิน')
            : _buildPhoneInfoRow('ผู้ติดต่อฉุกเฉิน:', employee.emergencyContact['phone'] ?? '', name: employee.emergencyContact['name']),
        _isEditMode
            ? _buildContactPair(_closeColleagueNameController, _closeColleaguePhoneController, 'พนักงานที่สนิท')
            : _buildPhoneInfoRow('พนักงานที่สนิท:', employee.additionalContacts['close_colleague_phone'] ?? '', name: employee.additionalContacts['close_colleague_name']),
        _isEditMode
            ? _buildContactPair(_closeFriend1NameController, _closeFriend1PhoneController, 'คนสนิท 1')
            : _buildPhoneInfoRow('คนสนิท 1:', employee.additionalContacts['close_friend1_phone'] ?? '', name: employee.additionalContacts['close_friend1_name']),
        _isEditMode
            ? _buildContactPair(_closeFriend2NameController, _closeFriend2PhoneController, 'คนสนิท 2')
            : _buildPhoneInfoRow('คนสนิท 2:', employee.additionalContacts['close_friend2_phone'] ?? '', name: employee.additionalContacts['close_friend2_name']),
        _isEditMode
            ? _buildContactPair(_supervisorNameController, _supervisorPhoneController, 'หัวหน้างาน')
            : _buildPhoneInfoRow('หัวหน้างาน:', employee.additionalContacts['supervisor_phone'] ?? '', name: employee.additionalContacts['supervisor_name']),
        const Divider(height: 20),
        _isEditMode
            ? _buildEditableField(_detailsController, 'หมายเหตุ:', maxLines: 4)
            : _buildReadOnlyField('หมายเหตุ:', employee.details),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchRelatedData(Employee employee) async {
    if (employee.departmentCode.isEmpty) {
      return {'departmentName': 'ยังไม่ได้กำหนด'};
    }
    try {
      final departmentDoc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(employee.departmentCode)
          .get();
      if (departmentDoc.exists) {
        final data = departmentDoc.data() as Map<String, dynamic>;
        return {'departmentName': data['name'] ?? 'ไม่ระบุชื่อ'};
      } else {
        return {'departmentName': 'ไม่พบแผนก'};
      }
    } catch (e) {
      debugPrint('Error fetching department: $e');
      return {'departmentName': 'เกิดข้อผิดพลาด'};
    }
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
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
              Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.anuphan(color: Colors.grey.shade700, fontSize: 16))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: GoogleFonts.anuphan(fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const UnderlineInputBorder()),
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }
  
  Widget _buildDropdownField(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    String? validValue = (value != null && items.contains(value)) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: validValue,
        decoration: InputDecoration(labelText: label, border: const UnderlineInputBorder()),
        items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildContactPair(TextEditingController nameController, TextEditingController phoneController, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: TextFormField(controller: nameController, decoration: InputDecoration(labelText: '$label (ชื่อ)', border: const UnderlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(controller: phoneController, decoration: InputDecoration(labelText: '$label (เบอร์โทร)', border: const UnderlineInputBorder()), keyboardType: TextInputType.phone)),
        ],
      ),
    );
  }

  Widget _buildPhoneInfoRow(String label, String phone, {String? name}) {
    final hasPhone = phone.isNotEmpty;
    final displayText = (name != null && name.isNotEmpty) ? '$name ($phone)' : phone;
    return _buildReadOnlyField(label, displayText);
  }
}
