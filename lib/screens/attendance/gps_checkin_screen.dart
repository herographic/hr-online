// lib/screens/attendance/gps_checkin_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/attendance_log_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/qr_location_model.dart';
import 'package:hr_online/screens/attendance/attendance_summary_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:geolocator/geolocator.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GpsCheckinScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const GpsCheckinScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<GpsCheckinScreen> createState() => _GpsCheckinScreenState();
}

class _GpsCheckinScreenState extends State<GpsCheckinScreen> {
  List<QrLocation> _locations = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = true;
  bool _isProcessingCheckin = false;
  String? _permissionError;

  bool _showMapLoading = true;
  Timer? _countdownTimer;
  int _countdown = 5;

  @override
  void initState() {
    super.initState();
    _initialize();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        if (mounted) setState(() => _countdown--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _showMapLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _fetchLocations();
    await _startLocationUpdates();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final snapshot = await firestore.FirebaseFirestore.instance
          .collection('qr_locations')
          .where('latitude', isNotEqualTo: null)
          .get();
      if (mounted) {
        setState(() {
          _locations = snapshot.docs
              .map((doc) => QrLocation.fromFirestore(doc))
              .toList();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _permissionError = 'กรุณาเปิด GPS');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _permissionError = 'กรุณาอนุญาตให้แอปเข้าถึงตำแหน่ง');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _permissionError = 'คุณได้ปฏิเสธการเข้าถึงตำแหน่งถาวร');
      return;
    }

    setState(() => _permissionError = null);
    _positionStream =
        Geolocator.getPositionStream().listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  Future<void> _showAttendanceTypeDialog(QrLocation location) async {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ลงเวลาที่: ${location.name}'),
          content: const Text('กรุณาเลือกประเภทการลงเวลาของคุณ'),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding:
              const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          actions: <Widget>[
            SizedBox(
              width: double.maxFinite,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('เข้างาน'),
                    onPressed: () => Navigator.of(context).pop('checkIn'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('ออกงาน'),
                    onPressed: () => Navigator.of(context).pop('checkOut'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('ออกพัก'),
                    onPressed: () => Navigator.of(context).pop('breakOut'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('เข้าพัก'),
                    onPressed: () => Navigator.of(context).pop('breakIn'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ],
              ),
            ),
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    ).then((attendanceType) {
      if (attendanceType != null) {
        _showFinalConfirmationDialog(location, attendanceType);
      }
    });
  }

  Future<void> _showFinalConfirmationDialog(QrLocation location, String attendanceType) async {
     final typeTextMap = {
      'checkIn': 'เข้างาน',
      'checkOut': 'ออกงาน',
      'breakOut': 'ออกพัก',
      'breakIn': 'เข้าพัก',
    };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลงเวลา'),
        content: Text('คุณต้องการยืนยันการลงเวลา "${typeTextMap[attendanceType]}" ที่ ${location.name} ใช่หรือไม่?'),
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
      _processAttendance(location, attendanceType);
    }
  }
  
  Future<void> _processAttendance(
      QrLocation location, String attendanceType) async {
    if (widget.loggedInEmployee == null) {
      _showError('ไม่พบข้อมูลผู้ใช้');
      return;
    }

    setState(() => _isProcessingCheckin = true);

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
          throw Exception('คุณได้ลงเวลาเข้างานสำหรับวันนี้ไปแล้ว');
        }
      } else if (attendanceType == 'checkOut') {
        if (!docSnapshot.exists || docData?['checkIn'] == null) {
          throw Exception('กรุณาลงเวลาเข้างานก่อนลงเวลาออก');
        }
        if (docData?['checkOut'] != null) {
          throw Exception('คุณได้ลงเวลาออกงานสำหรับวันนี้ไปแล้ว');
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
      };

      switch (attendanceType) {
        case 'checkIn':
          dataToUpdate['checkIn'] = firestore.FieldValue.serverTimestamp();
          dataToUpdate['checkInLocationName'] = location.name;
          dataToUpdate['checkInLocation'] = firestore.GeoPoint(
              _currentPosition!.latitude, _currentPosition!.longitude);
          break;
        case 'checkOut':
          dataToUpdate['checkOut'] = firestore.FieldValue.serverTimestamp();
          dataToUpdate['checkOutLocationName'] = location.name;
          dataToUpdate['checkOutLocation'] = firestore.GeoPoint(
              _currentPosition!.latitude, _currentPosition!.longitude);
          break;
        case 'breakOut':
          dataToUpdate['breakOut'] = firestore.FieldValue.serverTimestamp();
          break;
        case 'breakIn':
          dataToUpdate['breakIn'] = firestore.FieldValue.serverTimestamp();
          break;
      }

      await docRef.set(dataToUpdate, firestore.SetOptions(merge: true));

      final updatedDoc = await docRef.get();
      final updatedLog = AttendanceLog.fromFirestore(updatedDoc);

      if (mounted) {
        context
            .read<AttendanceStatusProvider>()
            .listenToAttendanceForDate(DateTime.now());
        
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => AttendanceSummaryScreen(
            log: updatedLog,
            employee: widget.loggedInEmployee!,
            attendanceType: attendanceType,
          ),
        ));
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isProcessingCheckin = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'เช็คอินด้วย GPS',
      showBackButton: true,
      bodySlivers: [
        if (_showMapLoading)
          _buildLoadingSliver()
        else
          ..._buildMainContentSlivers(),
      ],
      floatingActionButton: const SizedBox.shrink(),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://i.stack.imgur.com/g2VlB.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade800,
                child: const Center(
                    child: Icon(Icons.map_outlined,
                        color: Colors.white54, size: 100)),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          ),
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    'กำลังค้นหาตำแหน่งและสถานที่ใกล้เคียง',
                    style: GoogleFonts.anuphan(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_countdown',
                    style: GoogleFonts.orbitron(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMainContentSlivers() {
    return [
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.my_location, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    _currentPosition == null
                        ? 'กำลังค้นหาตำแหน่งของคุณ...'
                        : 'พบตำแหน่งของคุณแล้ว',
                    style: GoogleFonts.anuphan(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              if (_currentPosition != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                    style: GoogleFonts.anuphan(
                        color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      _buildLocationListSliver(),
    ];
  }

  Widget _buildLocationListSliver() {
    if (_isLoading) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_permissionError != null) {
      return SliverFillRemaining(
          child: Center(
              child: Text(_permissionError!,
                  style: const TextStyle(color: Colors.white))));
    }
    if (_locations.isEmpty) {
      return const SliverFillRemaining(
          child: Center(
              child: Text('ไม่พบสถานที่ที่สามารถเช็คอินด้วย GPS ได้',
                  style: TextStyle(color: Colors.white))));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final location = _locations[index];
          double distance = -1;
          if (_currentPosition != null &&
              location.latitude != null &&
              location.longitude != null) {
            distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              location.latitude!,
              location.longitude!,
            );
          }
          final bool inRange =
              distance != -1 && distance <= (location.radius ?? 50);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.name,
                      style: GoogleFonts.anuphan(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ระยะห่าง:', style: GoogleFonts.anuphan()),
                      Text(
                        distance == -1
                            ? 'คำนวณ...'
                            : '${distance.toStringAsFixed(0)} เมตร',
                        style: GoogleFonts.anuphan(
                            fontWeight: FontWeight.bold,
                            color: inRange ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessingCheckin || !inRange)
                          ? null
                          : () => _showAttendanceTypeDialog(location),
                      icon: _isProcessingCheckin
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.location_on_outlined),
                      label: Text(
                          _isProcessingCheckin ? 'กำลังบันทึก...' : 'ลงเวลาที่นี่'),
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
        childCount: _locations.length,
      ),
    );
  }
}
