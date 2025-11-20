// lib/screens/add_employee_screen.dart

// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/services.dart'; // Import for Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class AddEmployeeScreen extends StatefulWidget {
  final Employee? employeeToEdit;
  final bool? isAdmin;

  const AddEmployeeScreen({super.key, this.employeeToEdit, this.isAdmin});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  Uint8List? _imageBytes;
  String? _networkImageUrl;

  String _departmentName = 'ยังไม่ได้กำหนด';
  String _positionNames = 'ยังไม่ได้กำหนด';
  List<WorkShift> _allWorkShifts = [];

  // Controllers
  late TextEditingController _employeeCodeController;
  late TextEditingController _titleController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _nicknameController;
  late TextEditingController _nationalIdController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactPhoneController;
  late TextEditingController _detailsController;
  late TextEditingController _salaryController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountController;
  late TextEditingController _closeColleagueNameController;
  late TextEditingController _closeColleaguePhoneController;
  late TextEditingController _closeFriend1NameController;
  late TextEditingController _closeFriend1PhoneController;
  late TextEditingController _closeFriend2NameController;
  late TextEditingController _closeFriend2PhoneController;
  late TextEditingController _supervisorNameController;
  late TextEditingController _supervisorPhoneController;

  String? _selectedGender;
  String? _selectedMaritalStatus;
  DateTime? _birthDate;
  DateTime? _startDate;

  // --- [START] ADDED CODE ---
  bool _isOutsource = false;
  // --- [END] ADDED CODE ---

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    if (widget.employeeToEdit != null) {
      _populateFormForEdit();
      _fetchReferencedData(); 
    }
  }

  void _initializeControllers() {
    final emp = widget.employeeToEdit;
    final addContacts = emp?.additionalContacts ?? {};
    _employeeCodeController = TextEditingController(text: emp?.employeeId);
    _titleController = TextEditingController(text: emp?.title);
    _firstNameController = TextEditingController(text: emp?.firstName);
    _lastNameController = TextEditingController(text: emp?.lastName);
    _nicknameController = TextEditingController(text: emp?.nickname);
    _nationalIdController = TextEditingController(text: emp?.nationalId);
    _phoneController = TextEditingController(text: emp?.phoneNumber);
    _addressController = TextEditingController(text: emp?.address);
    _emergencyContactNameController = TextEditingController(text: emp?.emergencyContact['name']);
    _emergencyContactPhoneController = TextEditingController(text: emp?.emergencyContact['phone']);
    _detailsController = TextEditingController(text: emp?.details);
    _salaryController = TextEditingController(text: emp?.salary.toString());
    _bankNameController = TextEditingController(text: emp?.bankAccount['bankName']);
    _bankAccountController = TextEditingController(text: emp?.bankAccount['accountNumber']);
    _closeColleagueNameController = TextEditingController(text: addContacts['close_colleague_name']);
    _closeColleaguePhoneController = TextEditingController(text: addContacts['close_colleague_phone']);
    _closeFriend1NameController = TextEditingController(text: addContacts['close_friend1_name']);
    _closeFriend1PhoneController = TextEditingController(text: addContacts['close_friend1_phone']);
    _closeFriend2NameController = TextEditingController(text: addContacts['close_friend2_name']);
    _closeFriend2PhoneController = TextEditingController(text: addContacts['close_friend2_phone']);
    _supervisorNameController = TextEditingController(text: addContacts['supervisor_name']);
    _supervisorPhoneController = TextEditingController(text: addContacts['supervisor_phone']);
    
    // --- [START] ADDED CODE ---
    _isOutsource = emp?.isOutsource ?? false;
    // --- [END] ADDED CODE ---
  }

  void _populateFormForEdit() {
    final emp = widget.employeeToEdit!;
    _networkImageUrl = emp.profileImageUrl;
    _selectedGender = emp.gender;
    _selectedMaritalStatus = emp.maritalStatus;
    _birthDate = emp.birthDate?.toDate();
    _startDate = emp.startDate.toDate();
    // --- [START] ADDED CODE ---
    _isOutsource = emp.isOutsource;
    // --- [END] ADDED CODE ---
  }

  Future<void> _fetchReferencedData() async {
    if (widget.employeeToEdit == null) return;
    final emp = widget.employeeToEdit!;
    
    try {
      final deptFuture = emp.departmentCode.isNotEmpty 
          ? FirebaseFirestore.instance.collection('departments').doc(emp.departmentCode).get()
          : Future.value(null);
      final shiftsFuture = FirebaseFirestore.instance.collection('work_shifts').get();

      final results = await Future.wait([deptFuture, shiftsFuture]);
      final deptDoc = results[0] as DocumentSnapshot?;
      final shiftsSnapshot = results[1] as QuerySnapshot;

      if(mounted) {
        setState(() {
          if (deptDoc != null && deptDoc.exists) {
            final deptData = deptDoc.data() as Map<String, dynamic>?;
            _departmentName = deptData?['name'] ?? 'ไม่พบข้อมูล';
          } else {
            _departmentName = 'ยังไม่ได้กำหนด';
          }
          _positionNames = emp.positions.map((p) => p['name'] ?? '').join(', ');
          _allWorkShifts = shiftsSnapshot.docs.map((doc) => WorkShift.fromFirestore(doc)).toList();
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _departmentName = 'เกิดข้อผิดพลาด';
          _positionNames = 'เกิดข้อผิดพลาด';
        });
      }
    }
  }

  @override
  void dispose() {
    _employeeCodeController.dispose();
    _titleController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _detailsController.dispose();
    _salaryController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _closeColleagueNameController.dispose();
    _closeColleaguePhoneController.dispose();
    _closeFriend1NameController.dispose();
    _closeFriend1PhoneController.dispose();
    _closeFriend2NameController.dispose();
    _closeFriend2PhoneController.dispose();
    _supervisorNameController.dispose();
    _supervisorPhoneController.dispose();
    super.dispose();
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

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final employeeId = _employeeCodeController.text.trim();
      String? imageUrl = _networkImageUrl;

      if (_imageBytes != null) {
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('$employeeId.jpg');
        await storageRef.putData(_imageBytes!);
        imageUrl = await storageRef.getDownloadURL();
      }

      final Map<String, dynamic> employeeData = {
        'title': _titleController.text.trim(),
        'employee_name': _firstNameController.text.trim(),
        'employee_last_name': _lastNameController.text.trim(),
        'employee_nickname': _nicknameController.text.trim(),
        'profile_image_url': imageUrl,
        'gender': _selectedGender ?? 'ไม่ระบุ',
        'birth_date': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'iden_code': _nationalIdController.text.trim(),
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
        'start_date': _startDate != null ? Timestamp.fromDate(_startDate!) : FieldValue.serverTimestamp(),
        'salary': num.tryParse(_salaryController.text.trim()) ?? 0,
        'bank_account': {
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _bankAccountController.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        // --- [START] ADDED CODE ---
        'isOutsource': _isOutsource,
        // --- [END] ADDED CODE ---
      };
      
      if (widget.employeeToEdit == null) {
          employeeData['employee_code'] = employeeId;
          employeeData['createdAt'] = FieldValue.serverTimestamp();
          employeeData['department_code'] = '';
          employeeData['positions'] = []; 
          employeeData['dailyWorkShifts'] = {};
          employeeData['totalScore'] = 0;
          employeeData['additionalContacts'] = {};
      }

      await FirebaseFirestore.instance.collection('users').doc(employeeId).set(employeeData, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกข้อมูล "$employeeId" สำเร็จ')));
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _selectDate(BuildContext context, {bool isBirthDate = false}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isBirthDate ? _birthDate : _startDate) ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isBirthDate) _birthDate = picked;
        else _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeToEdit == null ? 'เพิ่มพนักงานใหม่' : 'แก้ไขข้อมูลพนักงาน'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildSectionHeader('ข้อมูลหลัก'),
            _buildImagePicker(),
            const SizedBox(height: 20),
            _buildTextField(_employeeCodeController, 'รหัสพนักงาน*', isEnabled: widget.employeeToEdit == null),
            _buildTextField(_titleController, 'คำนำหน้า*'),
            _buildTextField(_firstNameController, 'ชื่อจริง*'),
            _buildTextField(_lastNameController, 'นามสกุล*'),
            _buildTextField(_nicknameController, 'ชื่อเล่น'),
            
            // --- [START] ADDED CODE ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('บุคคลภายนอก (Outsource)', style: GoogleFonts.anuphan(fontSize: 16)),
              value: _isOutsource,
              onChanged: (bool value) {
                setState(() {
                  _isOutsource = value;
                });
              },
              secondary: Icon(_isOutsource ? Icons.engineering : Icons.business_center),
            ),
            // --- [END] ADDED CODE ---

            _buildSectionHeader('ข้อมูลส่วนตัว'),
            _buildDropdown(_selectedGender, (val) => setState(() => _selectedGender = val), ['ชาย', 'หญิง', 'ไม่ระบุ'], 'เพศ*'),
            _buildDropdown(_selectedMaritalStatus, (val) => setState(() => _selectedMaritalStatus = val), ['โสด', 'สมรส', 'หย่าร้าง', 'หม้าย'], 'สถานภาพ'),
            _buildDatePicker('วันเกิด', _birthDate, () => _selectDate(context, isBirthDate: true)),
            _buildTextField(_nationalIdController, 'เลขบัตรประชาชน'),
            _buildTextField(_phoneController, 'เบอร์โทรศัพท์'),
            _buildTextField(_addressController, 'ที่อยู่', maxLines: 3),

            _buildSectionHeader('ข้อมูลการทำงาน (จัดการในหน้าตั้งค่าสิทธิ์)'),
            _buildReadOnlyTextField('แผนก', _departmentName),
            _buildReadOnlyTextField('ตำแหน่ง', _positionNames.isEmpty ? 'ยังไม่ได้กำหนด' : _positionNames, maxLines: null),
            if (widget.employeeToEdit != null) _buildWeeklyScheduleTable(widget.employeeToEdit!, _allWorkShifts),
            _buildDatePicker('วันเริ่มงาน', _startDate, () => _selectDate(context)),

            _buildSectionHeader('ข้อมูลการเงิน'),
            _buildTextField(_salaryController, 'เงินเดือน', keyboardType: TextInputType.number),
            _buildTextField(_bankNameController, 'ชื่อธนาคาร'),
            _buildTextField(_bankAccountController, 'เลขบัญชีธนาคาร'),

            _buildSectionHeader('ข้อมูลเพิ่มเติม'),
            _buildContactPair(_emergencyContactNameController, _emergencyContactPhoneController, 'ผู้ติดต่อฉุกเฉิน'),
            _buildContactPair(_closeColleagueNameController, _closeColleaguePhoneController, 'พนักงานที่สนิท'),
            _buildContactPair(_closeFriend1NameController, _closeFriend1PhoneController, 'คนสนิท ลำดับ 1'),
            _buildContactPair(_closeFriend2NameController, _closeFriend2PhoneController, 'คนสนิท ลำดับ 2'),
            _buildContactPair(_supervisorNameController, _supervisorPhoneController, 'หัวหน้างาน'),
            _buildTextField(_detailsController, 'หมายเหตุ', maxLines: 4),

            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('บันทึกข้อมูล'),
                    onPressed: _saveEmployee,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
        child: Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
      );

  Widget _buildImagePicker() {
    ImageProvider? imageProvider;
    if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (_networkImageUrl != null) {
      imageProvider = NetworkImage(_networkImageUrl!);
    }

    return Center(
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageProvider,
              child: (imageProvider == null) ? Icon(Icons.person, size: 60, color: Colors.grey.shade400) : null,
            ),
            Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 20, backgroundColor: Theme.of(context).primaryColor, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20), onPressed: _pickImage))),
          ],
        ),
      );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isEnabled = true, int maxLines = 1, TextInputType? keyboardType}) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          enabled: isEnabled,
          validator: (value) => (label.endsWith('*') && (value == null || value.isEmpty)) ? 'กรุณากรอกข้อมูล' : null,
        ),
      );

  Widget _buildContactPair(TextEditingController nameController, TextEditingController phoneController, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: TextFormField(controller: nameController, decoration: InputDecoration(labelText: '$label (ชื่อ)'))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: phoneController, decoration: InputDecoration(labelText: '$label (เบอร์โทร)'), keyboardType: TextInputType.phone)),
          ],
        ),
      );

  Widget _buildReadOnlyTextField(String label, String value, {int? maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: TextFormField(
          key: ValueKey(value),
          initialValue: value,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
          ),
          readOnly: true,
        ),
      );

  Widget _buildDropdown(String? value, ValueChanged<String?> onChanged, List<String> items, String label) {
    String? validValue = (value != null && items.contains(value)) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: validValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
        validator: (value) => (label.endsWith('*') && value == null) ? 'กรุณาเลือกข้อมูล' : null,
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onPressed) {
    final DateFormat formatter = DateFormat('d MMMM yyyy', 'th_TH');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onPressed,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(date != null ? formatter.format(date) : 'กรุณาเลือกวันที่', style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  String _formatShiftTime(String time) {
    if (time.endsWith(':00')) {
      return time.substring(0, time.length - 3);
    }
    return time;
  }

  Widget _buildWeeklyScheduleTable(Employee employee, List<WorkShift> allShifts) {
    final Map<String, String> weekdays = {
      'Monday': 'จ', 'Tuesday': 'อ', 'Wednesday': 'พ',
      'Thursday': 'พฤ', 'Friday': 'ศ', 'Saturday': 'ส', 'Sunday': 'อา'
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'ตารางทำงาน',
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide.none),
        ),
        child: Table(
          children: [
            TableRow(
              children: weekdays.values.map((dayName) => Center(child: Text(dayName, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
            ),
            TableRow(
              children: weekdays.keys.map((dayKey) {
                final shiftId = employee.dailyWorkShifts[dayKey];
                String shiftDisplay = "หยุด";
                Color textColor = Colors.red.shade700;
                if (shiftId != null && shiftId.isNotEmpty) {
                  final shift = allShifts.firstWhereOrNull((s) => s.id == shiftId);
                  shiftDisplay = shift != null ? '${_formatShiftTime(shift.startTime)}-${_formatShiftTime(shift.endTime)}' : 'N/A';
                  textColor = Colors.black87;
                }
                return Center(child: Text(shiftDisplay, style: GoogleFonts.anuphan(fontSize: 11, color: textColor, fontWeight: FontWeight.w600)));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
