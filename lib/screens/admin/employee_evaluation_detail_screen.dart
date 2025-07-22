import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/job_description_model.dart';
import 'package:uuid/uuid.dart';

/// Represents the evaluation data for a single job description assigned to an employee.
class EmployeeEvaluation {
  final String id;
  final String jobDescriptionId;
  final String jobDescriptionTitle;
  final Timestamp assignedAt;
  final Map<String, int> scores; // Key: subItemId, Value: score
  final int totalPossiblePoints;

  EmployeeEvaluation({
    required this.id,
    required this.jobDescriptionId,
    required this.jobDescriptionTitle,
    required this.assignedAt,
    required this.scores,
    required this.totalPossiblePoints,
  });

  factory EmployeeEvaluation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeEvaluation(
      id: doc.id,
      jobDescriptionId: data['jobDescriptionId'] ?? '',
      jobDescriptionTitle: data['jobDescriptionTitle'] ?? '',
      assignedAt: data['assignedAt'] ?? Timestamp.now(),
      scores: Map<String, int>.from(data['scores'] ?? {}),
      totalPossiblePoints: data['totalPossiblePoints'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobDescriptionId': jobDescriptionId,
      'jobDescriptionTitle': jobDescriptionTitle,
      'assignedAt': assignedAt,
      'scores': scores,
      'totalPossiblePoints': totalPossiblePoints,
    };
  }
}

class EmployeeEvaluationDetailScreen extends StatefulWidget {
  final Employee employee;
  const EmployeeEvaluationDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeEvaluationDetailScreen> createState() =>
      _EmployeeEvaluationDetailScreenState();
}

class _EmployeeEvaluationDetailScreenState
    extends State<EmployeeEvaluationDetailScreen> {
  late Stream<QuerySnapshot> _evaluationsStream;

  @override
  void initState() {
    super.initState();
    _evaluationsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employee.employeeId)
        .collection('evaluations')
        .orderBy('assignedAt', descending: true)
        .snapshots();
  }

  Future<void> _addEvaluation(List<EmployeeEvaluation> currentEvaluations) async {
    // --- [START] VALIDATION LOGIC ---
    if (currentEvaluations.length >= 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ไม่สามารถเพิ่มหัวข้อประเมินเกิน 10 หัวข้อได้'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    // --- [END] VALIDATION LOGIC ---

    final allJobDescriptions = await FirebaseFirestore.instance
        .collection('job_descriptions')
        .orderBy('title')
        .get();

    final descriptions = allJobDescriptions.docs
        .map((doc) => JobDescription.fromFirestore(doc))
        .toList();

    if (!mounted) return;

    final JobDescription? selectedJob = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกรายละเอียดงานเพื่อประเมิน'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: descriptions.length,
            itemBuilder: (context, index) {
              final desc = descriptions[index];
              return ListTile(
                title: Text(desc.title),
                onTap: () => Navigator.of(context).pop(desc),
              );
            },
          ),
        ),
      ),
    );

    if (selectedJob != null) {
      // --- [START] VALIDATION LOGIC ---
      final currentTotalPossible = currentEvaluations.fold<int>(
          0, (sum, eval) => sum + eval.totalPossiblePoints);
      final newTopicPossible =
          selectedJob.subItems.fold<int>(0, (sum, item) => sum + item.points);

      if (currentTotalPossible + newTopicPossible > 100) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('คะแนนเต็มรวมของทุกหัวข้อจะเกิน 100 ไม่ได้'),
              backgroundColor: Colors.orange),
        );
        return;
      }
      // --- [END] VALIDATION LOGIC ---

      final newEvaluation = EmployeeEvaluation(
        id: const Uuid().v4(),
        jobDescriptionId: selectedJob.id,
        jobDescriptionTitle: selectedJob.title,
        assignedAt: Timestamp.now(),
        scores: {},
        totalPossiblePoints: newTopicPossible,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employee.employeeId)
          .collection('evaluations')
          .doc(newEvaluation.id)
          .set(newEvaluation.toFirestore());
    }
  }

  void _updateScore(
      EmployeeEvaluation evaluation, String subItemId, int score) {
    final updatedScores = Map<String, int>.from(evaluation.scores);
    updatedScores[subItemId] = score;

    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employee.employeeId)
        .collection('evaluations')
        .doc(evaluation.id)
        .update({'scores': updatedScores});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ประเมิน: ${widget.employee.nickname}'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _evaluationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีหัวข้อการประเมิน'));
          }

          final evaluations = snapshot.data!.docs
              .map((doc) => EmployeeEvaluation.fromFirestore(doc))
              .toList();

          // --- [START] MODIFIED SCORE CALCULATION ---
          final totalAchieved = evaluations.fold<int>(
              0, (sum, eval) => sum + eval.scores.values.fold(0, (s, i) => s + i));
          // --- [END] MODIFIED SCORE CALCULATION ---

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'คะแนนรวม: '),
                          TextSpan(
                            // --- [START] MODIFIED SCORE DISPLAY ---
                            text: '$totalAchieved / 100',
                            // --- [END] MODIFIED SCORE DISPLAY ---
                            style: GoogleFonts.anuphan(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Theme.of(context).primaryColor),
                          ),
                        ]),
                        style: GoogleFonts.anuphan(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: evaluations.length,
                  itemBuilder: (context, index) {
                    final evaluation = evaluations[index];
                    return _EvaluationCard(
                      employeeId: widget.employee.employeeId,
                      evaluation: evaluation,
                      onScoreChanged: _updateScore,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: _evaluationsStream,
        builder: (context, snapshot) {
          final evaluations = snapshot.data?.docs
              .map((doc) => EmployeeEvaluation.fromFirestore(doc))
              .toList() ?? [];
          return FloatingActionButton.extended(
            onPressed: () => _addEvaluation(evaluations),
            label: const Text('เพิ่มหัวข้อประเมิน'),
            icon: const Icon(Icons.add),
          );
        }
      ),
    );
  }
}

class _EvaluationCard extends StatefulWidget {
  final String employeeId;
  final EmployeeEvaluation evaluation;
  final Function(EmployeeEvaluation, String, int) onScoreChanged;

  const _EvaluationCard(
      {required this.evaluation, required this.onScoreChanged, required this.employeeId});

  @override
  State<_EvaluationCard> createState() => _EvaluationCardState();
}

class _EvaluationCardState extends State<_EvaluationCard> {
  final Map<String, TextEditingController> _controllers = {};
  Timer? _debounce;

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }
  
  void _handleScoreChange(String subItemId, String value, int maxPoints) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      int score = int.tryParse(value) ?? 0;
      if (score > maxPoints) {
        score = maxPoints;
        _controllers[subItemId]?.text = maxPoints.toString();
        _controllers[subItemId]?.selection = TextSelection.fromPosition(
            TextPosition(offset: _controllers[subItemId]!.text.length));
      }
      widget.onScoreChanged(widget.evaluation, subItemId, score);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('job_descriptions')
          .doc(widget.evaluation.jobDescriptionId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final jobDesc = JobDescription.fromFirestore(snapshot.data!);
        final achievedScore = widget.evaluation.scores.values
            .fold<int>(0, (sum, item) => sum + item);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(widget.evaluation.jobDescriptionTitle,
                style: GoogleFonts.anuphan(fontWeight: FontWeight.bold)),
            subtitle:
                Text('คะแนน: $achievedScore / ${widget.evaluation.totalPossiblePoints}'),
            initiallyExpanded: true,
            children: jobDesc.subItems.map((subItem) {
              final controller = _controllers.putIfAbsent(
                  subItem.id,
                  () => TextEditingController(
                      text: (widget.evaluation.scores[subItem.id] ?? 0)
                          .toString()));
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(subItem.description,
                            style: GoogleFonts.anuphan())),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          suffixText: '/ ${subItem.points}',
                        ),
                        onChanged: (value) =>
                            _handleScoreChange(subItem.id, value, subItem.points),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
