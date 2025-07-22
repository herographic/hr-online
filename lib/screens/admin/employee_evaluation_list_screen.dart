import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/admin/employee_evaluation_detail_screen.dart';
import 'package:hr_online/widgets/employee_avatar.dart';

class EmployeeEvaluationListScreen extends StatefulWidget {
  const EmployeeEvaluationListScreen({super.key});

  @override
  State<EmployeeEvaluationListScreen> createState() =>
      _EmployeeEvaluationListScreenState();
}

class _EmployeeEvaluationListScreenState
    extends State<EmployeeEvaluationListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกพนักงานเพื่อประเมิน'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อ หรือรหัสพนักงาน...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('employee_name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('ไม่มีข้อมูลพนักงาน'));
                }

                final employees = snapshot.data!.docs
                    .map((doc) => Employee.fromFirestore(doc))
                    .where((emp) {
                  if (_searchQuery.isEmpty) return true;
                  return emp.fullName.toLowerCase().contains(_searchQuery) ||
                      emp.employeeId.contains(_searchQuery);
                }).toList();

                if (employees.isEmpty) {
                  return const Center(child: Text('ไม่พบข้อมูลที่ค้นหา'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100.0),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    // --- [START] MODIFIED WIDGET ---
                    // Replaced ListTile with a new custom widget to handle evaluation data fetching
                    return _EmployeeEvaluationListItem(employee: employee);
                    // --- [END] MODIFIED WIDGET ---
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- [START] NEW WIDGET ---
/// A list item that fetches and displays evaluation summary for a single employee.
class _EmployeeEvaluationListItem extends StatelessWidget {
  final Employee employee;

  const _EmployeeEvaluationListItem({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(employee.employeeId)
            .collection('evaluations')
            .snapshots(),
        builder: (context, snapshot) {
          // Default values while loading or if there's no data
          int topicCount = 0;
          int totalScore = 0;

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final evaluations = snapshot.data!.docs
                .map((doc) => EmployeeEvaluation.fromFirestore(doc))
                .toList();

            topicCount = evaluations.length;
            totalScore = evaluations.fold<int>(
                0,
                (sum, eval) =>
                    sum + eval.scores.values.fold(0, (s, i) => s + i));
          }

          return ListTile(
            leading: EmployeeAvatar(
                imageUrl: employee.profileImageUrl,
                gender: employee.gender,
                radius: 20),
            title: Text(employee.fullName,
                style: GoogleFonts.anuphan(fontSize: 16)),
            subtitle: RichText(
              text: TextSpan(
                style: GoogleFonts.anuphan(
                    fontSize: 12, color: Colors.grey.shade600),
                children: <TextSpan>[
                  TextSpan(text: 'ID: ${employee.employeeId} | '),
                  TextSpan(
                      text: '$topicCount หัวข้อ',
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' / '),
                  TextSpan(
                      text: '$totalScore คะแนน',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing:
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    EmployeeEvaluationDetailScreen(employee: employee),
              ),
            ),
          );
        },
      ),
    );
  }
}
// --- [END] NEW WIDGET ---
