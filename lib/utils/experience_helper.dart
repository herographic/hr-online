// lib/utils/experience_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/exp_log_model.dart';

class ExperienceUtils {
  
  /// Adds experience points to a user, handles level ups, and logs the transaction.
  static Future<void> addExperience(
    String employeeId, 
    int amount,
    {required String sourceType, required String sourceDetails}
  ) async {
    if (employeeId.isEmpty || amount <= 0) return;

    final employeeRef = FirebaseFirestore.instance.collection('users').doc(employeeId);
    final expLogRef = FirebaseFirestore.instance.collection('exp_log').doc();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final employeeSnapshot = await transaction.get(employeeRef);
        if (!employeeSnapshot.exists) return;

        int currentLevel = employeeSnapshot.data()?['level'] ?? 1;
        int currentExp = employeeSnapshot.data()?['exp'] ?? 0;
        int currentNextLevelExp = employeeSnapshot.data()?['nextLevelExp'] ?? 100;

        currentExp += amount;

        while (currentExp >= currentNextLevelExp) {
          currentLevel++;
          currentExp -= currentNextLevelExp;
          currentNextLevelExp = _getExpForNextLevel(currentLevel);
        }

        transaction.update(employeeRef, {
          'level': currentLevel,
          'exp': currentExp,
          'nextLevelExp': currentNextLevelExp,
        });

        final newLog = ExpLog(
          id: expLogRef.id,
          employeeId: employeeId,
          amount: amount,
          sourceType: sourceType,
          sourceDetails: sourceDetails,
          timestamp: Timestamp.now(),
        );
        transaction.set(expLogRef, newLog.toFirestore());

      });
    } catch (e) {
      // Handle or log error silently
      print("Failed to add experience for $employeeId: $e");
    }
  }

  static int _getExpForNextLevel(int level) {
    return 100 + ((level - 1) * 50);
  }

  static String getLevelTitle(int level) {
    return LevelingSystem.getTitleForLevel(level);
  }
}
