// data_importer.dart
// วิธีรัน: dart run data_importer.dart

import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/firebase_options.dart'; 

// --- Main execution function ---
void main() async {
  print('--- HR Online Data Importer (Final Version) ---');
  print('This script will import basic employee data and skip Department/Position.');
  print('Initializing Firebase...');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase Initialized Successfully.');

  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  try {
    // --- 1. Read data from CSV file ---
    const filePath = 'ข้อมูลพนักงาน.xlsx - Simple.csv';
    print('\nReading data from "$filePath"...');
    final file = File(filePath);
    if (!await file.exists()) {
      print('❌ ERROR: File not found at "$filePath". Make sure the file is in the project root directory.');
      return;
    }
    final csvString = await file.readAsString(encoding: utf8);
    final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(csvString);

    if (rows.length <= 1) {
      print('❌ ERROR: CSV file is empty or contains only a header.');
      return;
    }
    
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.sublist(1);
    print('✅ Found ${dataRows.length} employee records in the file.');

    int updatedCount = 0;
    int createdCount = 0;
    int errorCount = 0;

    // --- 2. Process each row ---
    print('\nStarting data processing...');
    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.every((element) => element.toString().trim().isEmpty)) continue;

      final record = Map<String, dynamic>.fromIterables(header, row);
      final employeeId = record['รหัส']?.toString().trim() ?? '';

      if (employeeId.isEmpty) {
        print('⚠️ [Row ${i + 2}] Skipped: Employee ID is empty.');
        errorCount++;
        continue;
      }

      try {
        // --- Prepare data for Firestore (excluding department and position) ---
        final employeeData = {
          'employeeId': employeeId,
          'firstName': record['ชื่อ']?.toString().trim() ?? '',
          'lastName': record['นามสกุล']?.toString().trim() ?? '',
          'nickname': record['ชื่อเล่น']?.toString().trim() ?? '',
          'phoneNumber': record['เบอร์โทร']?.toString().trim() ?? '',
        };

        // --- Check if employee exists and update/create ---
        final querySnapshot = await db.collection('employees').where('employeeId', isEqualTo: employeeId).limit(1).get();
        
        if (querySnapshot.docs.isNotEmpty) {
          // Employee exists -> Update only the data from Excel
          final docId = querySnapshot.docs.first.id;
          await db.collection('employees').doc(docId).update(employeeData);
          print('🔄 [Row ${i + 2}] Updated employee: $employeeId');
          updatedCount++;
        } else {
          // Employee does not exist -> Create new record with empty positions
          final fullData = {
            ...employeeData,
            'uid': '',
            'positions': [], // IMPORTANT: Set positions to empty list
            'nationalId': '',
            'gender': 'ไม่ระบุ',
            'birthDate': Timestamp.now(),
            'maritalStatus': 'โสด',
            'address': '',
            'emergencyContact': {'name': '', 'phone': '', 'relationship': ''},
            'bankAccount': {'bankName': '', 'accountNumber': ''},
            'workShiftId': '', 
            'startDate': Timestamp.now(),
            'createdAt': FieldValue.serverTimestamp(),
            'profileImageUrl': null,
            'details': null,
            'salary': null,
            'daysOff': [],
          };

          // Create Auth user
          final email = '$employeeId@hronline.app';
          final password = employeeId;
          try {
            final userCredential = await auth.createUserWithEmailAndPassword(email: email, password: password);
            fullData['uid'] = userCredential.user?.uid ?? '';
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              print('ℹ️ [Row ${i + 2}] Auth user for $email already exists. Skipping auth creation.');
            } else {
              throw e;
            }
          }

          await db.collection('employees').add(fullData);
          print('✨ [Row ${i + 2}] Created new employee: $employeeId');
          createdCount++;
        }
      } catch (e) {
        print('❌ [Row ${i + 2}] FAILED for employee $employeeId. Error: $e');
        errorCount++;
      }
    }

    // --- 3. Final Summary ---
    print('\n--- Import Complete ---');
    print('✅ Successfully Created: $createdCount');
    print('🔄 Successfully Updated: $updatedCount');
    print('❌ Failed or Skipped:   $errorCount');
    print('-----------------------');

  } catch (e) {
    print('\n❌ An unexpected error occurred: $e');
  }
}
