// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String employeeId = _employeeIdController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) พยายามเข้าสู่ระบบด้วยอีเมลพื้นฐานจากรหัสพนักงานเสมอ
      final String fallbackEmail = '$employeeId@hrsoft.com';
      DocumentSnapshot? employeeDoc;
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fallbackEmail,
          password: password,
        );
      } on FirebaseAuthException catch (firstErr) {
        // 2) หากไม่พบผู้ใช้ ลองอ่าน Firestore เพื่อหาอีเมลจริง (ถ้าอ่านได้)
        if (firstErr.code == 'user-not-found') {
          try {
                employeeDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(employeeId)
                .get();
            if (employeeDoc.exists) {
              final data = employeeDoc.data() as Map<String, dynamic>? ?? {};
              final String altEmail = ((data['authEmail'] as String?) ?? (data['email'] as String?) ?? '').trim();
              if (altEmail.isNotEmpty && altEmail != fallbackEmail) {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: altEmail,
                  password: password,
                );
              } else {
                rethrow; // ไม่มีอีเมลอื่นให้ลอง
              }
            } else {
              rethrow;
            }
          } catch (_) {
            rethrow; // อ่าน Firestore ไม่ได้หรือเกิดข้อผิดพลาด
          }
        } else {
          // wrong-password / อื่นๆ -> โยนต่อไปให้ handler ด้านล่าง
          throw firstErr;
        }
      }

      // 3) เข้าสู่ระบบสำเร็จ -> ดึงข้อมูลพนักงานจาก Firestore (ตอนนี้ Auth แล้ว กฎส่วนใหญ่จะผ่าน)
      employeeDoc ??= await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get();
      if (!employeeDoc.exists) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูลพนักงานในระบบ';
        });
        return;
      }
          final employee = Employee.fromFirestore(employeeDoc);
    final resolvedId = (employee.employeeId.isNotEmpty)
      ? employee.employeeId
      : employeeDoc.id;
    await prefs.setString('loggedInUserId', resolvedId);

      if (!mounted) return;

      final bool isAdmin = employee.employeeId == '0539' || employee.isAdmin;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            isUserAdmin: isAdmin,
            loggedInEmployee: employee,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'ไม่พบบัญชีผู้ใช้นี้ กรุณาสมัครสมาชิกก่อน';
          break;
        case 'wrong-password':
          errorMessage = 'รหัสผ่านไม่ถูกต้อง';
          break;
        case 'invalid-email':
          errorMessage = 'รูปแบบรหัสพนักงานไม่ถูกต้อง';
          break;
        case 'user-disabled':
          errorMessage = 'บัญชีผู้ใช้นี้ถูกปิดใช้งาน';
          break;
        case 'too-many-requests':
          errorMessage = 'มีการพยายามเข้าสู่ระบบมากเกินไป กรุณาลองใหม่ภายหลัง';
          break;
        case 'network-request-failed':
          errorMessage = 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
          break;
        default:
          errorMessage = 'เกิดข้อผิดพลาด: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String employeeId = _employeeIdController.text.trim();
    final String password = _passwordController.text.trim();
    final String name = _nameController.text.trim();
    final String profileEmail = _emailController.text.trim();

    try {
      // ใช้อีเมลสำหรับ Auth เป็น {employeeId}@hrsoft.com เสมอ เพื่อให้ล็อกอินด้วยรหัสพนักงานได้แน่นอน
      final String authEmail = '$employeeId@hrsoft.com';
      // เตรียมอ้างอิงเอกสาร Firestore ของพนักงาน
      final usersCol = FirebaseFirestore.instance.collection('users');
      final docRef = usersCol.doc(employeeId);
      final snapshot = await docRef.get();

      // สร้างบัญชีใหม่/อัปเกรดบัญชี anonymous ใน Firebase Authentication
      UserCredential userCredential;
      try {
        final current = FirebaseAuth.instance.currentUser;
        final credential = EmailAuthProvider.credential(
          email: authEmail,
          password: password,
        );
        if (current != null && current.isAnonymous) {
          // อัปเกรด anonymous -> email/password
          userCredential = await current.linkWithCredential(credential);
        } else {
          // สมัครสมาชิกใหม่ปกติ
          userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: authEmail,
            password: password,
          );
        }
        // อัปเดตชื่อโปรไฟล์ใน Auth
        await userCredential.user!.updateDisplayName(name);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use' || e.code == 'credential-already-in-use') {
          // กรณีมีบัญชี Auth อยู่แล้ว: อัปเดตเฉพาะฟิลด์ยืนยันตัวตนใน Firestore แล้วให้ผู้ใช้ไปเข้าสู่ระบบ
          final Map<String, dynamic> mergeOnlyNew = {
            'authEmail': authEmail,
            if (profileEmail.isNotEmpty) 'emailaddress': profileEmail,
            'registeredAt': Timestamp.now(),
          };
          await docRef.set(mergeOnlyNew, SetOptions(merge: true));
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() {
              _isLoginMode = true;
              _errorMessage = 'มีบัญชีสำหรับรหัสพนักงานนี้แล้ว กรุณาเข้าสู่ระบบ';
            });
          }
          return;
        }
        rethrow;
      }

      // สร้างหรืออัปเดตข้อมูลพนักงานใน Firestore
      final first = name.split(' ').first;
      final last = name.split(' ').length > 1 ? name.split(' ').last : '';
      final nick = first;

  // สร้าง/อัปเดตข้อมูลใน Firestore แบบ merge ไม่ทับข้อมูลเก่า (docRef/snapshot ถูกเตรียมไว้แล้วด้านบน)

      final Map<String, dynamic> mergeOnlyNew = {
        'authEmail': authEmail,
        'firebaseUid': userCredential.user!.uid,
        'registeredAt': Timestamp.now(),
        if (profileEmail.isNotEmpty) 'emailaddress': profileEmail,
      };

      if (snapshot.exists) {
        // เอกสารมีอยู่แล้ว -> อัปเดตเฉพาะฟิลด์ใหม่ (merge)
        await docRef.set(mergeOnlyNew, SetOptions(merge: true));
      } else {
        // ยังไม่มี -> สร้างเอกสารใหม่แบบ minimal + ฟิลด์ใหม่ โดยไม่รบกวน schema เดิม
        final Map<String, dynamic> createMinimal = {
          'employee_code': employeeId,
          'employee_title_lv': 'นาย',
          'employee_name': first,
          'employee_last_name': last,
          'employee_nickname': nick,
          'nationality': 'TH',
          'department_code': '',
          'mobilephone': '',
          'iden_code': '',
          'bank_account_code': '',
          'bank_id': '',
          'position_code': '',
          'position_no': '',
          'salary_code': '',
          'time_code': '',
          'holiday_code': '',
          'state_code': '',
          'district_code': '',
          'subdistrict_code': '',
          'begin_dt': '',
          'detail_code': ' ',
          // merge-only fields
          ...mergeOnlyNew,
        };
        await docRef.set(createMinimal, SetOptions(merge: true));
      }

      // Logout จาก Firebase Auth หลังสมัครสมาชิก
      await FirebaseAuth.instance.signOut();

      setState(() {
        _isLoginMode = true;
        _errorMessage = null;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ',
            style: GoogleFonts.anuphan(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'รหัสผ่านอ่อนแอเกินไป กรุณาใช้รหัสผ่านที่มีความปลอดภัยมากขึ้น';
          break;
        case 'email-already-in-use':
          errorMessage = 'อีเมลนี้ถูกใช้งานแล้ว';
          break;
        case 'invalid-email':
          errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        case 'operation-not-allowed':
          errorMessage = 'การสมัครสมาชิกไม่ได้รับอนุญาต';
          break;
        case 'network-request-failed':
          errorMessage = 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
          break;
        default:
          errorMessage = 'เกิดข้อผิดพลาดในการสมัครสมาชิก: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Removed overwrite dialog: registration now always uses employeeId@hrsoft.com for Auth

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Deep blue
              Color(0xFF3B82F6), // Medium blue
              Color(0xFF60A5FA), // Light blue
              Color(0xFF93C5FD), // Very light blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  Container(
                    margin: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.business_center,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'HR SOFT',
                          style: GoogleFonts.anuphan(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLoginMode ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                          style: GoogleFonts.anuphan(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Glass Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Employee ID Field
                                _buildGlassTextField(
                                  controller: _employeeIdController,
                                  label: 'รหัสพนักงาน',
                                  icon: Icons.badge_outlined,
                                  validator: (value) => (value == null || value.isEmpty)
                                      ? 'กรุณากรอกรหัสพนักงาน'
                                      : null,
                                ),
                                
                                if (!_isLoginMode) ...[
                                  const SizedBox(height: 24),
                                  _buildGlassTextField(
                                    controller: _nameController,
                                    label: 'ชื่อ-นามสกุล',
                                    icon: Icons.person_outline,
                                    validator: (value) => (value == null || value.isEmpty)
                                        ? 'กรุณากรอกชื่อ-นามสกุล'
                                        : null,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildGlassTextField(
                                    controller: _emailController,
                                    label: 'อีเมล (ไม่บังคับ)',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ],

                                const SizedBox(height: 24),
                                
                                // Password Field
                                _buildGlassTextField(
                                  controller: _passwordController,
                                  label: 'รหัสผ่าน',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) => (value == null || value.isEmpty)
                                      ? 'กรุณากรอกรหัสผ่าน'
                                      : null,
                                ),

                                if (!_isLoginMode) ...[
                                  const SizedBox(height: 24),
                                  _buildGlassTextField(
                                    controller: _confirmPasswordController,
                                    label: 'ยืนยันรหัสผ่าน',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscureConfirmPassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 22,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'กรุณายืนยันรหัสผ่าน';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'รหัสผ่านไม่ตรงกัน';
                                      }
                                      return null;
                                    },
                                  ),
                                ],

                                const SizedBox(height: 32),

                                // Error Message
                                if (_errorMessage != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.anuphan(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                // Submit Button
                                _isLoading
                                    ? Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                        child: const CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(15),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isLoginMode ? _login : _register,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                          ),
                                          child: Text(
                                            _isLoginMode ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                                            style: GoogleFonts.anuphan(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                const SizedBox(height: 20),

                                // Toggle Mode Button
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isLoginMode = !_isLoginMode;
                                        _errorMessage = null;
                                        _employeeIdController.clear();
                                        _passwordController.clear();
                                        _confirmPasswordController.clear();
                                        _nameController.clear();
                                        _emailController.clear();
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: GoogleFonts.anuphan(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        children: [
                                          TextSpan(
                                            text: _isLoginMode 
                                                ? 'ยังไม่มีบัญชี? ' 
                                                : 'มีบัญชีแล้ว? ',
                                          ),
                                          TextSpan(
                                            text: _isLoginMode 
                                                ? 'สมัครสมาชิก' 
                                                : 'เข้าสู่ระบบ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                              decorationColor: Colors.white,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  offset: const Offset(1, 1),
                                                  blurRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // คำอธิบายเพิ่มเติมสำหรับโหมดล็อกอิน
                                if (_isLoginMode)
                                  Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🔐 วิธีเข้าสู่ระบบ:',
                                          style: GoogleFonts.anuphan(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '• รหัสพนักงาน: ใส่รหัสพนักงานของคุณ\n'
                                          '• รหัสผ่าน: ใส่รหัสผ่านที่ตั้งไว้\n',
                                          style: GoogleFonts.anuphan(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.9),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // คำอธิบายเพิ่มเติมสำหรับโหมดสมัครสมาชิก
                                if (!_isLoginMode)
                                  Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📝 ข้อมูลที่ต้องกรอก:',
                                          style: GoogleFonts.anuphan(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '• รหัสพนักงาน: รหัสประจำตัวของคุณ\n'
                                          '• ชื่อ-นามสกุล: ชื่อจริงของคุณ\n'
                                          '• อีเมล: สำหรับติดต่อ (ไม่บังคับ)\n'
                                          '• รหัสผ่าน: ตั้งรหัสผ่านสำหรับเข้าระบบ\n'
                                          '• ยืนยันรหัสผ่าน: กรอกรหัสผ่านซ้ำ',
                                          style: GoogleFonts.anuphan(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.9),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label แสดงด้านบน
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // TextField
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.anuphan(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: _getHintText(label),
              hintStyle: GoogleFonts.anuphan(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.8),
                size: 22,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  String _getHintText(String label) {
    switch (label) {
      case 'รหัสพนักงาน':
        return 'กรอกรหัสพนักงาน เช่น 0539';
      case 'ชื่อ-นามสกุล':
        return 'กรอกชื่อและนามสกุลของคุณ';
      case 'อีเมล (ไม่บังคับ)':
        return 'example@company.com';
      case 'รหัสผ่าน':
        return 'กรอกรหัสผ่าน';
      case 'ยืนยันรหัสผ่าน':
        return 'กรอกรหัสผ่านอีกครั้ง';
      default:
        return '';
    }
  }
}
