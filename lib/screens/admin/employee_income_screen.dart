// lib/screens/admin/employee_income_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/income_model.dart';
import 'package:hr_online/models/work_shift_model.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class EmployeeIncomeScreen extends StatefulWidget {
  const EmployeeIncomeScreen({super.key});

  @override
  State<EmployeeIncomeScreen> createState() => _EmployeeIncomeScreenState();
}

class _EmployeeIncomeScreenState extends State<EmployeeIncomeScreen> {
  // Data state
  List<Employee> _allEmployees = [];
  List<Department> _allDepartments = [];
  List<WorkShift> _allWorkShifts = [];
  bool _isLoadingData = true;

  // UI State
  Employee? _selectedEmployee;
  EmployeeIncome _incomeModel = EmployeeIncome.initial();
  bool _isSaving = false;

  // Controllers
  final _searchController = TextEditingController();
  Timer? _debounce;
  final Map<String, TextEditingController> _commissionControllers = {};
  final _baseIncomeController = TextEditingController();
  final _otMultiplierController = TextEditingController(text: '1.5');
  IncomeType _selectedIncomeType = IncomeType.monthly;

  // Calculation results
  double _calculatedHourlyRate = 0;
  double _calculatedDailyRate = 0;
  double _calculatedMonthlyRate = 0;
  double _calculatedOtRate = 0;
  double _totalCommission = 0;
  double _grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _initializeCommissionControllers();
    _loadInitialData();
    _baseIncomeController.addListener(_triggerCalculations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _commissionControllers.forEach((_, controller) => controller.dispose());
    _baseIncomeController.dispose();
    _otMultiplierController.dispose();
    super.dispose();
  }

  void _initializeCommissionControllers() {
    _incomeModel.commissionRates.forEach((key, value) {
      _commissionControllers[key] = TextEditingController(text: value.toStringAsFixed(2));
      _commissionControllers[key]!.addListener(_triggerCalculations);
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').orderBy('employee_name').get(),
        FirebaseFirestore.instance.collection('departments').get(),
        FirebaseFirestore.instance.collection('work_shifts').get(),
      ]);
      if (mounted) {
        setState(() {
          _allEmployees = (results[0] as QuerySnapshot).docs.map((d) => Employee.fromFirestore(d)).toList();
          _allDepartments = (results[1] as QuerySnapshot).docs.map((d) => Department.fromFirestore(d)).toList();
          _allWorkShifts = (results[2] as QuerySnapshot).docs.map((d) => WorkShift.fromFirestore(d)).toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onEmployeeSelected(Employee employee) async {
    setState(() {
      _selectedEmployee = employee;
      _isLoadingData = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employee.employeeId)
          .collection('income_settings')
          .doc('main')
          .get();
      
      if (doc.exists) {
        _incomeModel = EmployeeIncome.fromFirestore(doc);
      } else {
        _incomeModel = EmployeeIncome.initial();
      }
      
      // Update UI with fetched/new data
      _updateControllersFromModel();
      _triggerCalculations();

    } catch (e) {
      // Handle error
    } finally {
      if(mounted) setState(() => _isLoadingData = false);
    }
  }

  // --- [START] NEW METHOD ---
  /// Clears the current selection and resets the form.
  void _clearSelection() {
    setState(() {
      _selectedEmployee = null;
      _incomeModel = EmployeeIncome.initial(); // Reset the data model

      _updateControllersFromModel(); // Update all text fields from the reset model
      _triggerCalculations(); // Recalculate to show zero values
      _searchController.clear(); // Clear search text
      
      FocusScope.of(context).unfocus(); // Hide keyboard
    });
  }
  // --- [END] NEW METHOD ---

  /// Updates all TextEditingControllers with values from the current _incomeModel.
  void _updateControllersFromModel() {
    _baseIncomeController.text = _incomeModel.baseIncome.toStringAsFixed(2);
    _otMultiplierController.text = _incomeModel.otRateMultiplier.toString();
    _selectedIncomeType = _incomeModel.baseIncomeType;
    _incomeModel.commissionRates.forEach((key, value) {
      _commissionControllers[key]?.text = value.toStringAsFixed(2);
    });
  }

  void _triggerCalculations() {
    if (_selectedEmployee == null) {
       setState(() {
        _calculatedHourlyRate = 0;
        _calculatedDailyRate = 0;
        _calculatedMonthlyRate = 0;
        _calculatedOtRate = 0;
        _totalCommission = 0;
        _grandTotal = 0;
      });
      return;
    };

    final baseIncome = double.tryParse(_baseIncomeController.text) ?? 0.0;
    
    double workHoursPerDay = 12.0; // Default
    final todayShiftId = _selectedEmployee!.dailyWorkShifts[DateFormat('EEEE').format(DateTime.now())];
    final shift = _allWorkShifts.firstWhereOrNull((s) => s.id == todayShiftId);
    if (shift != null) {
      try {
        final startTime = TimeOfDay(hour: int.parse(shift.startTime.split(':')[0]), minute: int.parse(shift.startTime.split(':')[1]));
        final endTime = TimeOfDay(hour: int.parse(shift.endTime.split(':')[0]), minute: int.parse(shift.endTime.split(':')[1]));
        final startMinutes = startTime.hour * 60 + startTime.minute;
        final endMinutes = endTime.hour * 60 + endTime.minute;
        workHoursPerDay = (endMinutes - startMinutes) / 60;
        if (workHoursPerDay <= 0) workHoursPerDay += 24;
      } catch (e) { /* use default */ }
    }

    int workDaysInMonth = 26; // Default
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final nonWorkDays = _selectedEmployee!.dailyWorkShifts.values.where((id) => id == null || id.isEmpty).length;
    workDaysInMonth = daysInMonth - (nonWorkDays * 4);

    double hourly = 0, daily = 0, monthly = 0;
    if (workHoursPerDay > 0 && workDaysInMonth > 0) {
      switch (_selectedIncomeType) {
        case IncomeType.hourly:
          hourly = baseIncome;
          daily = hourly * workHoursPerDay;
          monthly = daily * workDaysInMonth;
          break;
        case IncomeType.daily:
          daily = baseIncome;
          hourly = daily / workHoursPerDay;
          monthly = daily * workDaysInMonth;
          break;
        case IncomeType.monthly:
          monthly = baseIncome;
          daily = monthly / workDaysInMonth;
          hourly = daily / workDaysInMonth;
          break;
      }
    }
    
    final otMultiplier = double.tryParse(_otMultiplierController.text) ?? 1.5;
    final otRate = hourly * otMultiplier;
    final totalComm = _commissionControllers.values.fold<double>(0.0, (sum, controller) => sum + (double.tryParse(controller.text) ?? 0.0));
    final grandTotal = monthly + otRate + totalComm;

    setState(() {
      _calculatedHourlyRate = hourly;
      _calculatedDailyRate = daily;
      _calculatedMonthlyRate = monthly;
      _calculatedOtRate = otRate;
      _totalCommission = totalComm;
      _grandTotal = grandTotal;
    });
  }

  Future<void> _saveIncomeSettings() async {
    if (_selectedEmployee == null) return;
    setState(() => _isSaving = true);

    try {
      final Map<String, double> commissions = {};
      _commissionControllers.forEach((key, controller) {
        commissions[key] = double.tryParse(controller.text) ?? 0.0;
      });

      final newIncomeData = EmployeeIncome(
        baseIncome: double.tryParse(_baseIncomeController.text) ?? 0.0,
        baseIncomeType: _selectedIncomeType,
        otRateMultiplier: double.tryParse(_otMultiplierController.text) ?? 1.5,
        commissionRates: commissions,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedEmployee!.employeeId)
          .collection('income_settings')
          .doc('main')
          .set(newIncomeData.toFirestore());

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ'), backgroundColor: Colors.green));
      }

    } catch (e) {
      // handle error
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _allEmployees.where((emp) {
      if (_searchController.text.isEmpty) return true;
      final query = _searchController.text.toLowerCase();
      return emp.fullName.toLowerCase().contains(query) || emp.employeeId.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('กำหนดรายได้พนักงาน'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหารหัส หรือชื่อพนักงาน...',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState((){}),
            ),
          ),
          if (_searchController.text.isNotEmpty && _selectedEmployee == null)
            Expanded(
              child: ListView.builder(
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final emp = filteredEmployees[index];
                  final dept = _allDepartments.firstWhereOrNull((d) => d.id == emp.departmentCode);
                  return ListTile(
                    title: Text(emp.fullName),
                    subtitle: Text('ID: ${emp.employeeId} | แผนก: ${dept?.name ?? 'N/A'}'),
                    onTap: () {
                      _onEmployeeSelected(emp);
                      _searchController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          if (_selectedEmployee != null)
            Expanded(
              child: _isLoadingData
                  ? const Center(child: CircularProgressIndicator())
                  : _buildIncomeForm(),
            ),
        ],
      ),
    );
  }

  Widget _buildIncomeForm() {
    final dept = _allDepartments.firstWhereOrNull((d) => d.id == _selectedEmployee!.departmentCode);
    final position = _selectedEmployee!.positions.map((p) => p['name']).join(', ');
    final currencyFormat = NumberFormat("#,##0.00", "en_US");

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- [START] MODIFIED WIDGET ---
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_selectedEmployee!.fullName, style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 18)),
          subtitle: Text('ID: ${_selectedEmployee!.employeeId}\nแผนก: ${dept?.name ?? 'N/A'} | ตำแหน่ง: $position'),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.clear, color: Colors.red),
            tooltip: 'ล้างข้อมูลและเลือกพนักงานใหม่',
            onPressed: _clearSelection,
          ),
        ),
        // --- [END] MODIFIED WIDGET ---
        const Divider(),

        _buildSectionHeader('ค่าคอมมิชชั่น'),
        _buildCommissionInput('หยิบจัดสินค้า', _commissionControllers['picking']!),
        _buildCommissionInput('เติมโหลดสินค้า', _commissionControllers['loading']!),
        _buildCommissionInput('สแกนสินค้า', _commissionControllers['scanning']!),
        _buildCommissionInput('ขนส่งสินค้า', _commissionControllers['delivery']!),
        _buildCommissionInput('การขาย', _commissionControllers['sales']!),
        _buildCommissionInput('สวัสดิการอื่นๆ', _commissionControllers['other']!),
        
        const SizedBox(height: 24),
        _buildSectionHeader('รายได้พื้นฐาน'),
        Row(
          children: [
            Expanded(child: _buildEditableField(_baseIncomeController, "รายได้", keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _buildEditableField(_otMultiplierController, "ตัวคูณโอที", keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<IncomeType>(
          segments: const [
            ButtonSegment(value: IncomeType.monthly, label: Text('ต่อเดือน')),
            ButtonSegment(value: IncomeType.daily, label: Text('ต่อวัน')),
            ButtonSegment(value: IncomeType.hourly, label: Text('ต่อ ชม.')),
          ],
          selected: {_selectedIncomeType},
          onSelectionChanged: (newSelection) {
            setState(() {
              _selectedIncomeType = newSelection.first;
              _triggerCalculations();
            });
          },
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('สรุปการคำนวณ (โดยประมาณ)'),
        _buildReadOnlyField('รายได้/ชม:', '${currencyFormat.format(_calculatedHourlyRate)} บาท'),
        _buildReadOnlyField('รายได้/วัน:', '${currencyFormat.format(_calculatedDailyRate)} บาท'),
        _buildReadOnlyField('รายได้/เดือน:', '${currencyFormat.format(_calculatedMonthlyRate)} บาท'),
        _buildReadOnlyField('โอที/ชม:', '${currencyFormat.format(_calculatedOtRate)} บาท'),
        const Divider(),
        _buildReadOnlyField('รวมค่าคอมมิชชั่น:', '${currencyFormat.format(_totalCommission)} บาท'),
        _buildReadOnlyField('รวมรายได้ทั้งหมด:', '${currencyFormat.format(_grandTotal)} บาท', isBold: true),
        
        const SizedBox(height: 24),
        _isSaving
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                onPressed: _saveIncomeSettings,
                icon: const Icon(Icons.save),
                label: const Text('บันทึกการตั้งค่า'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              )
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
        child: Text(title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
      );

  Widget _buildCommissionInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'บาท/รก',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _buildEditableField(TextEditingController controller, String label, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
    );
  }

  Widget _buildReadOnlyField(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.anuphan(fontSize: 15)),
          Text(value, style: GoogleFonts.anuphan(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
