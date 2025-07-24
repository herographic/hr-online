// lib/models/income_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum IncomeType { monthly, daily, hourly }

class EmployeeIncome {
  final double baseIncome;
  final IncomeType baseIncomeType;
  final double otRateMultiplier;
  final Map<String, double> commissionRates;

  EmployeeIncome({
    this.baseIncome = 0.0,
    this.baseIncomeType = IncomeType.monthly,
    this.otRateMultiplier = 1.5,
    required this.commissionRates,
  });

  // Helper to get a default empty model
  factory EmployeeIncome.initial() {
    return EmployeeIncome(
      commissionRates: {
        'picking': 0.0,
        'loading': 0.0,
        'scanning': 0.0,
        'delivery': 0.0,
        'sales': 0.0,
        'other': 0.0,
      },
    );
  }

  factory EmployeeIncome.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EmployeeIncome(
      baseIncome: (data['baseIncome'] as num?)?.toDouble() ?? 0.0,
      baseIncomeType: _incomeTypeFromString(data['baseIncomeType']),
      otRateMultiplier: (data['otRateMultiplier'] as num?)?.toDouble() ?? 1.5,
      commissionRates: Map<String, double>.from(
        (data['commissionRates'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'baseIncome': baseIncome,
      'baseIncomeType': baseIncomeType.name,
      'otRateMultiplier': otRateMultiplier,
      'commissionRates': commissionRates,
    };
  }

  static IncomeType _incomeTypeFromString(String? type) {
    switch (type) {
      case 'daily':
        return IncomeType.daily;
      case 'hourly':
        return IncomeType.hourly;
      default:
        return IncomeType.monthly;
    }
  }
}
