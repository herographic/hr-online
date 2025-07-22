// lib/screens/admin/job_posting_editor_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/job_posting_model.dart';
import 'package:hr_online/models/position_model.dart' as app_pos;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class JobPostingEditorScreen extends StatefulWidget {
  final Employee loggedInEmployee;
  final JobPosting? jobPostingToEdit;

  const JobPostingEditorScreen({
    super.key,
    required this.loggedInEmployee,
    this.jobPostingToEdit,
  });

  @override
  State<JobPostingEditorScreen> createState() => _JobPostingEditorScreenState();
}

class _JobPostingEditorScreenState extends State<JobPostingEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isDataLoading = true;

  // Form Controllers
  final _detailsController = TextEditingController();
  final _openingsController = TextEditingController();
  final _compensationController = TextEditingController();
  final _educationController = TextEditingController();
  final _locationController = TextEditingController();
  final _benefitsController = TextEditingController();
  final _shiftInfoController = TextEditingController();
  final _considerationsController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // Dropdown and Date values
  String? _selectedDepartmentId;
  String? _selectedPositionId;
  String _selectedGender = 'ไม่ระบุ';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isUrgent = false;

  // Data for dropdowns
  List<Department> _allDepartments = [];
  List<app_pos.Position> _allPositions = [];
  List<app_pos.Position> _filteredPositions = [];

  // Image handling
  File? _positionImageFile;
  String? _networkPositionImageUrl;
  final List<File> _workImageFiles = [];
  List<String> _networkWorkImageUrls = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  @override
  void dispose() {
    _detailsController.dispose();
    _openingsController.dispose();
    _compensationController.dispose();
    _educationController.dispose();
    _locationController.dispose();
    _benefitsController.dispose();
    _shiftInfoController.dispose();
    _considerationsController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final deptsSnapshot = await FirebaseFirestore.instance.collection('departments').orderBy('name').get();
      final posSnapshot = await FirebaseFirestore.instance.collection('positions').orderBy('name').get();

      _allDepartments = deptsSnapshot.docs.map((d) => Department.fromFirestore(d)).toList();
      _allPositions = posSnapshot.docs.map((p) => app_pos.Position.fromFirestore(p)).toList();

      if (widget.jobPostingToEdit != null) {
        final post = widget.jobPostingToEdit!;
        _detailsController.text = post.jobDetails;
        _openingsController.text = post.openings.toString();
        _compensationController.text = post.compensation;
        _educationController.text = post.educationLevel;
        _locationController.text = post.workLocation;
        _benefitsController.text = post.benefits;
        _shiftInfoController.text = post.workShiftInfo;
        _considerationsController.text = post.specialConsiderations;
        _contactPhoneController.text = post.contactPhone;
        _selectedDepartmentId = post.departmentId;
        _selectedPositionId = post.positionId;
        _selectedGender = post.gender;
        _startDate = post.applicationStartDate.toDate();
        _endDate = post.applicationEndDate.toDate();
        _isUrgent = post.isUrgent;
        _networkPositionImageUrl = post.positionImageUrl;
        _networkWorkImageUrls = post.workImageUrls;
        _filterPositionsForDepartment(post.departmentId);
      } else {
        _contactPhoneController.text = widget.loggedInEmployee.phoneNumber;
      }

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดในการโหลดข้อมูล: $e")));
    } finally {
      if(mounted) setState(() => _isDataLoading = false);
    }
  }

  void _filterPositionsForDepartment(String? departmentId) {
    setState(() {
      _selectedDepartmentId = departmentId;
      _filteredPositions = _allPositions.where((p) => p.departmentId == departmentId).toList();
      // Reset position if it's not in the new list
      if (!_filteredPositions.any((p) => p.id == _selectedPositionId)) {
        _selectedPositionId = null;
      }
    });
  }

  Future<void> _pickImage(ImageSource source, {bool isPositionImage = true}) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1024);
    if (pickedFile != null) {
      setState(() {
        if (isPositionImage) {
          _positionImageFile = File(pickedFile.path);
        } else {
          _workImageFiles.add(File(pickedFile.path));
        }
      });
    }
  }

  Future<String?> _uploadFile(File file, String path) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(path).child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Upload images
      String? positionImageUrl = _networkPositionImageUrl;
      if (_positionImageFile != null) {
        positionImageUrl = await _uploadFile(_positionImageFile!, 'job_postings/position_images');
      }

      List<String> workImageUrls = List.from(_networkWorkImageUrls);
      for (var file in _workImageFiles) {
        final url = await _uploadFile(file, 'job_postings/work_images');
        if (url != null) workImageUrls.add(url);
      }
      
      final selectedDept = _allDepartments.firstWhere((d) => d.id == _selectedDepartmentId);
      final selectedPos = _allPositions.firstWhere((p) => p.id == _selectedPositionId);

      final postData = JobPosting(
        id: widget.jobPostingToEdit?.id ?? '',
        departmentId: selectedDept.id,
        departmentName: selectedDept.name,
        positionId: selectedPos.id,
        positionName: selectedPos.name,
        jobDetails: _detailsController.text,
        openings: int.tryParse(_openingsController.text) ?? 1,
        compensation: _compensationController.text,
        educationLevel: _educationController.text,
        workLocation: _locationController.text,
        gender: _selectedGender,
        benefits: _benefitsController.text,
        applicationStartDate: Timestamp.fromDate(_startDate!),
        applicationEndDate: Timestamp.fromDate(_endDate!),
        workShiftInfo: _shiftInfoController.text,
        positionImageUrl: positionImageUrl,
        workImageUrls: workImageUrls,
        requiredDocuments: ['รูปถ่าย', 'สำเนาบัตรประชาชน', 'สำเนาทะเบียนบ้าน', 'สำเนาวุฒิการศึกษา'],
        specialConsiderations: _considerationsController.text,
        contactPhone: _contactPhoneController.text,
        postedBy: widget.loggedInEmployee.employeeId,
        postedByName: widget.loggedInEmployee.fullName,
        postedAt: widget.jobPostingToEdit?.postedAt ?? Timestamp.now(),
        isUrgent: _isUrgent,
      );

      if (widget.jobPostingToEdit == null) {
        await FirebaseFirestore.instance.collection('job_postings').add(postData.toFirestore());
      } else {
        await FirebaseFirestore.instance.collection('job_postings').doc(postData.id).update(postData.toFirestore());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกประกาศสำเร็จ'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('th', 'TH'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobPostingToEdit == null ? 'สร้างประกาศใหม่' : 'แก้ไขประกาศ'),
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white)),
          if (!_isLoading) IconButton(icon: const Icon(Icons.save), onPressed: _savePost, tooltip: 'บันทึก'),
        ],
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionHeader('ตำแหน่งและรายละเอียด'),
                  DropdownButtonFormField<String>(
                    value: _selectedDepartmentId,
                    hint: const Text('เลือกแผนก*'),
                    items: _allDepartments.map((dept) => DropdownMenuItem(value: dept.id, child: Text(dept.name))).toList(),
                    onChanged: (value) => _filterPositionsForDepartment(value),
                    validator: (v) => v == null ? 'กรุณาเลือกแผนก' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedPositionId,
                    hint: const Text('เลือกตำแหน่ง*'),
                    items: _filteredPositions.map((pos) => DropdownMenuItem(value: pos.id, child: Text(pos.name))).toList(),
                    onChanged: (value) => setState(() => _selectedPositionId = value),
                     validator: (v) => v == null ? 'กรุณาเลือกตำแหน่ง' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _detailsController, decoration: const InputDecoration(labelText: 'รายละเอียดงาน*'), maxLines: 5, validator: (v) => v!.isEmpty ? 'กรุณากรอกข้อมูล' : null),
                  
                  _buildSectionHeader('ข้อมูลการรับสมัคร'),
                  TextFormField(controller: _openingsController, decoration: const InputDecoration(labelText: 'จำนวนอัตราที่รับ*'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'กรุณากรอกข้อมูล' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _compensationController, decoration: const InputDecoration(labelText: 'ค่าตอบแทน*', hintText: 'เช่น 15,000 บาท/เดือน'), validator: (v) => v!.isEmpty ? 'กรุณากรอกข้อมูล' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _educationController, decoration: const InputDecoration(labelText: 'วุฒิการศึกษา*'), validator: (v) => v!.isEmpty ? 'กรุณากรอกข้อมูล' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'สถานที่ปฏิบัติงาน*'), validator: (v) => v!.isEmpty ? 'กรุณากรอกข้อมูล' : null),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(labelText: 'เพศ'),
                    items: ['ไม่ระบุ', 'ชาย', 'หญิง'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (value) => setState(() => _selectedGender = value!),
                  ),
                   const SizedBox(height: 16),
                  TextFormField(controller: _benefitsController, decoration: const InputDecoration(labelText: 'สวัสดิการ'), maxLines: 3),
                  const SizedBox(height: 16),
                  TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'ระยะเวลาที่เปิดรับสมัคร*',
                      hintText: _startDate != null ? '${DateFormat('d/M/y', 'th_TH').format(_startDate!)} - ${DateFormat('d/M/y', 'th_TH').format(_endDate!)}' : 'เลือกวันที่',
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () => _selectDateRange(context),
                    validator: (_) => _startDate == null || _endDate == null ? 'กรุณาเลือกวันที่' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _shiftInfoController, decoration: const InputDecoration(labelText: 'เวลาเข้างาน', hintText: 'เช่น 08:00 - 17:00 น.')),
                  
                   _buildSectionHeader('รูปภาพ'),
                  _buildImagePicker('รูปตำแหน่งงาน (รูปหลัก)', _positionImageFile, _networkPositionImageUrl, (source) => _pickImage(source, isPositionImage: true)),
                  const SizedBox(height: 16),
                  _buildMultiImagePicker(),
                  
                  _buildSectionHeader('ข้อมูลเพิ่มเติม'),
                  TextFormField(controller: _considerationsController, decoration: const InputDecoration(labelText: 'ลักษณะที่ต้องการ (พิจารณาเป็นพิเศษ)'), maxLines: 3),
                  const SizedBox(height: 16),
                  TextFormField(controller: _contactPhoneController, decoration: const InputDecoration(labelText: 'เบอร์โทรผู้ติดต่อ*'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'กรุณากรอกข้อมูล' : null),
                  SwitchListTile(
                    title: const Text('ประกาศด่วน'),
                    subtitle: const Text('จะแสดงสัญลักษณ์ "ด่วน" แบบกระพริบ'),
                    value: _isUrgent,
                    onChanged: (value) => setState(() => _isUrgent = value),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _buildImagePicker(String label, File? imageFile, String? networkUrl, Function(ImageSource) onPick) {
    ImageProvider? imageProvider;
    if (imageFile != null) {
      imageProvider = FileImage(imageFile);
    } else if (networkUrl != null) {
      imageProvider = NetworkImage(networkUrl);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
          ),
          child: imageProvider == null ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)) : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(icon: const Icon(Icons.photo_library), label: const Text('เลือกรูป'), onPressed: () => onPick(ImageSource.gallery)),
            TextButton.icon(icon: const Icon(Icons.camera_alt), label: const Text('ถ่ายรูป'), onPressed: () => onPick(ImageSource.camera)),
          ],
        )
      ],
    );
  }

  Widget _buildMultiImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('รูปภาพลักษณะงาน (หลายรูป)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._networkWorkImageUrls.map((url) => _buildImageThumbnail(NetworkImage(url), () => setState(() => _networkWorkImageUrls.remove(url)))),
              ..._workImageFiles.map((file) => _buildImageThumbnail(FileImage(file), () => setState(() => _workImageFiles.remove(file)))),
              InkWell(
                onTap: () => _pickImage(ImageSource.gallery, isPositionImage: false),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_a_photo, color: Colors.grey),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(ImageProvider imageProvider, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0, right: 0,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
