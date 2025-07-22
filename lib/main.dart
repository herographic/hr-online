// lib/main.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/screens/home_screen.dart';
import 'package:hr_online/screens/login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await initializeDateFormatting('th_TH', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    print("Failed to sign in anonymously: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final String? employeeId = prefs.getString('loggedInUserId');

  Widget initialScreen = const LoginScreen();

  if (employeeId != null && employeeId.isNotEmpty) {
    if (employeeId == 'admin') {
      initialScreen = const HomeScreen(isUserAdmin: true, loggedInEmployee: null);
    } else {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(employeeId).get();
        if (doc.exists) {
          final employee = Employee.fromFirestore(doc);
          
          // --- [START] KEY MODIFICATION ---
          // Determine the initial screen based on the 'isAdmin' flag
          // when the app starts.
          initialScreen = HomeScreen(
            isUserAdmin: employee.isAdmin, // Use the flag from the model
            loggedInEmployee: employee,
          );
          // --- [END] KEY MODIFICATION ---
        }
      } catch (e) {
        print("Error fetching saved user data: $e");
      }
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AttendanceStatusProvider(),
      child: MyApp(initialScreen: initialScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  static const Color primaryColor = Color(0xFF0072ff);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.anuphan(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            textStyle: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          labelStyle: GoogleFonts.anuphan(color: Colors.black54),
          hintStyle: GoogleFonts.anuphan(color: Colors.grey.shade500),
        ), colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(secondary: primaryColor),
      ),
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('th', ''),
      ],
      locale: const Locale('th'),
      home: initialScreen,
    );
  }
}
