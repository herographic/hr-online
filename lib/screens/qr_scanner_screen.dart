// lib/screens/qr_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum ScanStep { waitingForScan, showConfirmation, processing, success }

class QRScannerScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;
  final bool isForCompensation;

  const QRScannerScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
    this.isForCompensation = false,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  ScanStep _currentStep = ScanStep.waitingForScan;
  String? _scannedLocationName;
  String _attendanceType = '';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_currentStep != ScanStep.waitingForScan || !mounted) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null || !code.startsWith('HRLOC::')) {
      return;
    }

    _scannerController.stop();
    _handleLocationScan(code);
  }

  Future<void> _handleLocationScan(String code) async {
    setState(() {
      _currentStep = ScanStep.processing;
    });

    try {
      final locationId = code.split('::')[1];
      final doc = await firestore.FirebaseFirestore.instance
          .collection('qr_locations')
          .doc(locationId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _scannedLocationName = doc.data()?['name'] ?? 'ไม่พบชื่อสถานที่';
          _currentStep = ScanStep.showConfirmation;
        });
      } else {
        _showErrorAndReset('QR Code สถานที่ไม่ถูกต้อง');
      }
    } catch (e) {
      _showErrorAndReset('รูปแบบ QR Code ไม่ถูกต้อง');
    }
  }

  // --- [START] NEW METHOD: Final Confirmation Dialog ---
  Future<void> _showFinalConfirmationDialog(String attendanceType) async {
    final typeTextMap = {
      'checkIn': 'เข้างาน',
      'checkOut': 'ออกงาน',
      'breakOut': 'ออกพัก',
      'breakIn': 'เข้าพัก',
    };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการลงเวลา'),
        content: Text('คุณต้องการยืนยันการลงเวลา "${typeTextMap[attendanceType]}" ที่ $_scannedLocationName ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _processAttendance(attendanceType);
    }
  }
  // --- [END] NEW METHOD ---

  Future<firestore.GeoPoint?> _fetchCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      _showErrorAndReset("กรุณาเปิดบริการตำแหน่ง (GPS) ในโทรศัพท์ของคุณ");
      return null;
    }

    PermissionStatus permission = await Permission.location.status;
    if (permission.isDenied) {
      permission = await Permission.location.request();
    }

    if (permission.isPermanentlyDenied || permission.isDenied) {
      _showErrorAndReset("แอปพลิเคชันต้องการสิทธิ์เข้าถึงตำแหน่งเพื่อบันทึกเวลา");
      return null;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));
      return firestore.GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      _showErrorAndReset(
          "ไม่สามารถดึงตำแหน่งปัจจุบันได้ กรุณาตรวจสอบว่า GPS เปิดอยู่และรับสัญญาณได้");
      return null;
    }
  }

  Future<void> _processAttendance(String attendanceType) async {
    if (widget.loggedInEmployee == null) {
      _showErrorAndReset('ไม่พบข้อมูลผู้ใช้ที่ล็อกอินอยู่');
      return;
    }

    setState(() {
      _currentStep = ScanStep.processing;
      _attendanceType = attendanceType;
    });

    final currentLocation = await _fetchCurrentLocation();
    if (currentLocation == null) {
      _resetScanner();
      return;
    }

    try {
      final now = DateTime.now();
      final docId =
          '${widget.loggedInEmployee!.employeeId}_${DateFormat('yyyy-MM-dd').format(now)}';
      final docRef = firestore.FirebaseFirestore.instance
          .collection('attendance_log')
          .doc(docId);
      final docSnapshot = await docRef.get();
      final docData = docSnapshot.data();

      if (attendanceType == 'checkIn') {
        if (docSnapshot.exists && docData?['checkIn'] != null) {
          throw Exception('คุณได้สแกนเข้างานสำหรับวันนี้ไปแล้ว');
        }
      } else if (attendanceType == 'checkOut') {
        if (!docSnapshot.exists || docData?['checkIn'] == null) {
          throw Exception('กรุณาสแกนเข้างานก่อนสแกนออก');
        }
        if (docData?['checkOut'] != null) {
          throw Exception('คุณได้สแกนออกงานสำหรับวันนี้ไปแล้ว');
        }
      } else if (attendanceType == 'breakOut') {
        if (!docSnapshot.exists || docData?['checkIn'] == null) {
          throw Exception('กรุณาสแกนเข้างานก่อนออกพัก');
        }
        if (docData?['breakOut'] != null) {
          throw Exception('คุณได้สแกนออกพักไปแล้ว');
        }
      } else if (attendanceType == 'breakIn') {
        if (!docSnapshot.exists || docData?['breakOut'] == null) {
          throw Exception('กรุณาสแกนออกพักก่อนเข้าพัก');
        }
        if (docData?['breakIn'] != null) {
          throw Exception('คุณได้สแกนเข้าพักไปแล้ว');
        }
      }

      final Map<String, dynamic> dataToUpdate = {
        'employeeId': widget.loggedInEmployee!.employeeId,
        'employeeName': widget.loggedInEmployee!.fullName,
        'employeeNickname': widget.loggedInEmployee!.nickname,
        'date':
            firestore.Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'status': 'present',
        'markedBy': widget.loggedInEmployee!.employeeId,
        'isCompensationDay': widget.isForCompensation,
      };

      switch (attendanceType) {
        case 'checkIn':
          dataToUpdate['checkIn'] = firestore.FieldValue.serverTimestamp();
          dataToUpdate['checkInLocationName'] = _scannedLocationName;
          dataToUpdate['checkInLocation'] = currentLocation;
          break;
        case 'checkOut':
          dataToUpdate['checkOut'] = firestore.FieldValue.serverTimestamp();
          dataToUpdate['checkOutLocationName'] = _scannedLocationName;
          dataToUpdate['checkOutLocation'] = currentLocation;
          break;
        case 'breakOut':
          dataToUpdate['breakOut'] = firestore.FieldValue.serverTimestamp();
          break;
        case 'breakIn':
          dataToUpdate['breakIn'] = firestore.FieldValue.serverTimestamp();
          break;
      }

      await docRef.set(dataToUpdate, firestore.SetOptions(merge: true));

      if (mounted) {
        context
            .read<AttendanceStatusProvider>()
            .listenToAttendanceForDate(DateTime.now());
      }

      setState(() {
        _currentStep = ScanStep.success;
      });
    } catch (e) {
      _showErrorAndReset(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showErrorAndReset(String message) {
    if (!mounted) return;
    showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('เกิดข้อผิดพลาด'),
                  content: Text(message),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('ตกลง'))
                  ],
                ))
        .then((_) => _resetScanner());
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() {
      _currentStep = ScanStep.waitingForScan;
      _scannedLocationName = null;
    });
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loggedInEmployee == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ผิดพลาด')),
        body: const Center(child: Text('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่')),
      );
    }

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'สแกนเพื่อลงเวลา',
      showBackButton: true,
      bodySlivers: [
        SliverFillRemaining(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _buildCurrentStepWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case ScanStep.waitingForScan:
        return _buildScannerView();
      case ScanStep.showConfirmation:
        return _buildConfirmationView();
      case ScanStep.processing:
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case ScanStep.success:
        return _buildSuccessView();
      }
  }

  Widget _buildScannerView() {
    return Column(
      key: const ValueKey('scanner'),
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(controller: _scannerController, onDetect: _onDetect),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.7), width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('สแกน QR Code',
                    style: GoogleFonts.anuphan(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text('ณ จุดลงเวลาที่กำหนด',
                    style:
                        GoogleFonts.anuphan(fontSize: 16, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationView() {
    return Container(
      key: const ValueKey('confirmation'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ลงเวลาที่:',
              style: GoogleFonts.anuphan(
                  fontSize: 20, color: Colors.grey.shade700)),
          Text(_scannedLocationName ?? 'N/A',
              style: GoogleFonts.anuphan(
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const Divider(height: 40),
          EmployeeAvatar(
            imageUrl: widget.loggedInEmployee?.profileImageUrl,
            gender: widget.loggedInEmployee?.gender,
            radius: 60,
          ),
          const SizedBox(height: 16),
          Text(widget.loggedInEmployee?.fullName ?? '',
              style:
                  GoogleFonts.anuphan(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('ID: ${widget.loggedInEmployee?.employeeId ?? ''}',
              style:
                  GoogleFonts.anuphan(fontSize: 16, color: Colors.grey.shade600)),
          const Spacer(),
          Text('กรุณาเลือกประเภทการลงเวลา',
              style: GoogleFonts.anuphan(fontSize: 16)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('เข้างาน'),
                  // --- [START] MODIFIED CODE ---
                  onPressed: () => _showFinalConfirmationDialog('checkIn'),
                  // --- [END] MODIFIED CODE ---
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
              ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกงาน'),
                  // --- [START] MODIFIED CODE ---
                  onPressed: () => _showFinalConfirmationDialog('checkOut'),
                  // --- [END] MODIFIED CODE ---
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
              ElevatedButton.icon(
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('ออกพัก'),
                  // --- [START] MODIFIED CODE ---
                  onPressed: () => _showFinalConfirmationDialog('breakOut'),
                  // --- [END] MODIFIED CODE ---
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
              ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('เข้าพัก'),
                  // --- [START] MODIFIED CODE ---
                  onPressed: () => _showFinalConfirmationDialog('breakIn'),
                  // --- [END] MODIFIED CODE ---
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue)),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
              onPressed: _resetScanner,
              child: const Text('ยกเลิกและสแกนใหม่',
                  style: TextStyle(color: Colors.grey)))
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    Color themeColor = Colors.grey;
    String successMessage = 'บันทึกเวลาสำเร็จ!';
    switch (_attendanceType) {
      case 'checkIn':
        successMessage = 'บันทึกเวลาเข้างานสำเร็จ!';
        themeColor = Colors.green;
        break;
      case 'checkOut':
        successMessage = 'บันทึกเวลาออกงานสำเร็จ!';
        themeColor = Colors.red;
        break;
      case 'breakOut':
        successMessage = 'บันทึกเวลาออกพักสำเร็จ!';
        themeColor = Colors.orange;
        break;
      case 'breakIn':
        successMessage = 'บันทึกเวลาเข้าพักสำเร็จ!';
        themeColor = Colors.blue;
        break;
    }

    return Container(
      key: const ValueKey('success'),
      color: themeColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 120),
              const SizedBox(height: 24),
              Text(successMessage,
                  style: GoogleFonts.anuphan(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 16),
              Text('สถานที่: $_scannedLocationName',
                  style: GoogleFonts.anuphan(fontSize: 18, color: Colors.white)),
              Text('เวลา: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                  style: GoogleFonts.anuphan(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: themeColor),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
