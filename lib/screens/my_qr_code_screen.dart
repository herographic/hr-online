// lib/screens/my_qr_code_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQRCodeScreen extends StatefulWidget {
  final Employee loggedInEmployee;

  const MyQRCodeScreen({super.key, required this.loggedInEmployee});

  @override
  State<MyQRCodeScreen> createState() => _MyQRCodeScreenState();
}

class _MyQRCodeScreenState extends State<MyQRCodeScreen> {
  late Timer _timer;
  String _qrData = '';
  int _countdown = 15; // QR code regenerates every 15 seconds

  @override
  void initState() {
    super.initState();
    _generateQRData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _generateQRData();
      }
    });
  }

  void _generateQRData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _qrData = '${widget.loggedInEmployee.employeeId};$timestamp';
      _countdown = 15; // Reset countdown
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      isUserAdmin: false, // This screen is for employees only
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'QR Code ของฉัน',
      showBackButton: true,
      bodySlivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 250.0,
                      gapless: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'แสดง QR Code นี้เพื่อลงเวลา',
                    style: GoogleFonts.anuphan(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'QR Code จะเปลี่ยนในอีก',
                    style: GoogleFonts.anuphan(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_countdown วินาที',
                    style: GoogleFonts.anuphan(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
