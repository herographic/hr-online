// lib/screens/upload_employee_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart';

class UploadEmployeeScreen extends StatefulWidget {
  final bool? isUserAdmin;
  final Employee? loggedInEmployee;

  const UploadEmployeeScreen({
    super.key,
    this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<UploadEmployeeScreen> createState() => _UploadEmployeeScreenState();
}

class _UploadEmployeeScreenState extends State<UploadEmployeeScreen> {
  String _status = 'พร้อมที่จะอัปโหลดข้อมูลพนักงานจากไฟล์ CSV';
  bool _isLoading = false;
  double _progress = 0.0;
  int _totalRecords = 0;
  int _uploadedRecords = 0;
  int _skippedRecords = 0;
  final String _uploadPassword = "12345678"; // --- [START] ADDED CODE --- รหัสผ่านสำหรับป้องกัน

  // --- [START] ADDED CODE ---
  /// แสดง Dialog เพื่อให้ผู้ใช้กรอกรหัสผ่านก่อนอัปโหลด
  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // ผู้ใช้ต้องกดปุ่มเพื่อปิด
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการอัปโหลด'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: ListBody(
                children: <Widget>[
                  const Text('กรุณากรอกรหัสผ่านเพื่อดำเนินการต่อ'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true, // ซ่อนรหัสผ่าน
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'รหัสผ่าน',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกรหัสผ่าน';
                      }
                      if (value != _uploadPassword) {
                        return 'รหัสผ่านไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('ยืนยัน'),
              onPressed: () {
                // ตรวจสอบความถูกต้องของฟอร์ม (และรหัสผ่าน)
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(); // ปิด Dialog
                  _uploadData(); // เริ่มการอัปโหลด
                }
              },
            ),
          ],
        );
      },
    );
  }
  // --- [END] ADDED CODE ---

  Future<void> _uploadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'กำลังเริ่มต้น...';
      _progress = 0.0;
      _totalRecords = 0;
      _uploadedRecords = 0;
      _skippedRecords = 0;
    });

    try {
      if (!mounted) return;
      setState(() => _status = 'กำลังอ่านไฟล์ employee_data.csv...');

      final rawData = await rootBundle.loadString("assets/employee_data.csv");
      const csvConverter = CsvToListConverter(eol: '\n', fieldDelimiter: ',');
      final List<List<dynamic>> listData = csvConverter.convert(rawData);
      
      if (listData.length < 2) {
        if (!mounted) return;
        setState(() {
          _status = 'ไฟล์ CSV ว่างเปล่าหรือมีแต่หัวข้อ';
          _isLoading = false;
        });
        return;
      }

      final headers = listData[0].map((h) => h.toString().trim()).toList();
      final records = listData.sublist(1);
      _totalRecords = records.length;

      final CollectionReference usersRef = FirebaseFirestore.instance.collection('users');
      
      int batchCounter = 0;
      var batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < records.length; i++) {
        final row = records[i];
        if (row.length != headers.length) {
          _skippedRecords++;
          continue;
        }
        
        final rowAsStrings = row.map((value) => value.toString()).toList();
        final Map<String, dynamic> rowData = Map.fromIterables(headers, rowAsStrings);
        
        String employeeCode = rowData['employee_code']?.toString().trim() ?? '';
        if (employeeCode.isEmpty) {
          _skippedRecords++;
          continue; 
        }
        if (employeeCode.length < 4) {
          employeeCode = employeeCode.padLeft(4, '0');
        }
        rowData['employee_code'] = employeeCode; 

        String mobilePhone = rowData['mobilephone']?.toString().trim() ?? '';
        if (mobilePhone.length == 9 && !mobilePhone.startsWith('0')) {
          mobilePhone = '0$mobilePhone';
        }
        rowData['mobilephone'] = mobilePhone; 
        
        final DocumentReference docRef = usersRef.doc(employeeCode);
        
        batch.set(docRef, rowData, SetOptions(merge: true));
        batchCounter++;
        
        _uploadedRecords++;

        if (batchCounter >= 500) {
           await batch.commit();
           batch = FirebaseFirestore.instance.batch();
           batchCounter = 0;
        }

        if (!mounted) return;
        setState(() {
          _progress = (i + 1) / _totalRecords;
          _status = 'กำลังอัปโหลด: $_uploadedRecords/$_totalRecords';
        });
      }
      
      if (batchCounter > 0) {
        await batch.commit();
      }

      if (!mounted) return;
      setState(() {
        _status = 'อัปโหลดสำเร็จ!\nเพิ่ม/อัปเดต: $_uploadedRecords รายการ\nข้าม: $_skippedRecords รายการ';
        _isLoading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = 'เกิดข้อผิดพลาด: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin ?? true,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'อัปโหลดข้อมูล',
      bodySlivers: [
        SliverFillRemaining(
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 60, color: Color(0xFF0072ff)),
                    const SizedBox(height: 16),
                    Text(
                      'อัปโหลดข้อมูลพนักงาน',
                      style: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.anuphan(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: _progress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade300,
                              color: const Color(0xFF0072ff),
                            ),
                            const SizedBox(height: 8),
                            Text('${(_progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.anuphan()),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.file_upload),
                      label: Text('เริ่มอัปโหลด', style: GoogleFonts.anuphan()),
                      // --- [START] MODIFIED CODE ---
                      // เปลี่ยนจากการเรียก _uploadData() ตรงๆ เป็นการเรียก _showPasswordDialog()
                      onPressed: _isLoading ? null : _showPasswordDialog,
                      // --- [END] MODIFIED CODE ---
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        backgroundColor: const Color(0xFF0072ff),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
