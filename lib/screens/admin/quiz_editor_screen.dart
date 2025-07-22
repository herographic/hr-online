// lib/screens/admin/quiz_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/department_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/quiz_model.dart';
import 'package:hr_online/screens/admin/quiz_assignment_screen.dart';
import 'package:hr_online/widgets/employee_avatar.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// Helper class to combine Assignment and Employee data for display
class _AssignmentResult {
  final QuizAssignment assignment;
  final Employee employee;
  _AssignmentResult({required this.assignment, required this.employee});
}


class QuizEditorScreen extends StatefulWidget {
  final String? quizId; // if null, it's a new quiz

  const QuizEditorScreen({super.key, required this.quizId});

  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TabController _tabController;
  
  // Quiz details
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedDepartmentId;
  String? _selectedPositionId;
  bool _isActive = true;
  List<Question> _questions = [];

  // Data for dropdowns
  List<Department> _departments = [];

  // --- [START] NEW STATE: For assignment results ---
  Future<List<_AssignmentResult>>? _assignmentResultsFuture;
  // --- [END] NEW STATE ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadInitialData();

    // --- [START] NEW LOGIC: Trigger fetching results when tab changes ---
    _tabController.addListener(() {
      if (_tabController.index == 1 && widget.quizId != null) {
        setState(() {
          _assignmentResultsFuture = _fetchAssignmentResults();
        });
      }
    });
    // --- [END] NEW LOGIC ---
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // Load departments and positions for dropdowns
    final deptSnapshot = await FirebaseFirestore.instance.collection('departments').orderBy('name').get();
    _departments = deptSnapshot.docs.map((doc) => Department.fromFirestore(doc)).toList();


    if (widget.quizId != null) {
      final quizDoc = await FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId).get();
      if (quizDoc.exists) {
        final questionsSnapshot = await quizDoc.reference.collection('questions').get();
        final data = quizDoc.data()!;
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _selectedDepartmentId = data['departmentId'];
        _selectedPositionId = data['positionId'];
        _isActive = data['isActive'] ?? true;
        _questions = questionsSnapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- [START] NEW METHOD: Fetch and combine assignment/employee data ---
  Future<List<_AssignmentResult>> _fetchAssignmentResults() async {
    if (widget.quizId == null) return [];
    
    final assignmentSnapshot = await FirebaseFirestore.instance
        .collection('quiz_assignments')
        .where('quizId', isEqualTo: widget.quizId)
        .get();

    if (assignmentSnapshot.docs.isEmpty) return [];

    List<_AssignmentResult> results = [];
    for (final doc in assignmentSnapshot.docs) {
      final assignment = QuizAssignment.fromFirestore(doc);
      final employeeDoc = await FirebaseFirestore.instance.collection('users').doc(assignment.employeeId).get();
      if (employeeDoc.exists) {
        results.add(_AssignmentResult(
          assignment: assignment,
          employee: Employee.fromFirestore(employeeDoc),
        ));
      }
    }
    return results;
  }
  // --- [END] NEW METHOD ---

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);


    final quizData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'departmentId': _selectedDepartmentId,
      'positionId': _selectedPositionId,
      'isActive': _isActive,
      'authorId': 'admin', 
      'createdAt': widget.quizId == null ? FieldValue.serverTimestamp() : (await FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId!).get()).data()?['createdAt'],
    };

    try {
      DocumentReference quizRef;
      if (widget.quizId == null) {
        quizRef = await FirebaseFirestore.instance.collection('quizzes').add(quizData);
      } else {
        quizRef = FirebaseFirestore.instance.collection('quizzes').doc(widget.quizId!);
        await quizRef.update(quizData);
      }

      final batch = FirebaseFirestore.instance.batch();
      final questionsCollection = quizRef.collection('questions');

      final oldQuestions = await questionsCollection.get();
      for (final doc in oldQuestions.docs) {
        batch.delete(doc.reference);
      }

      for (final question in _questions) {
        final docRef = questionsCollection.doc(question.id);
        batch.set(docRef, question.toFirestore());
      }
      
      await batch.commit();

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกแบบทดสอบสำเร็จ'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  void _showQuestionDialog({Question? questionToEdit}) {
    showDialog(
      context: context,
      builder: (context) => _QuestionDialog(
        question: questionToEdit,
        onSave: (newQuestion) {
          setState(() {
            if (questionToEdit == null) {
              _questions.add(newQuestion);
            } else {
              final index = _questions.indexWhere((q) => q.id == newQuestion.id);
              if (index != -1) {
                _questions[index] = newQuestion;
              }
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizId == null ? 'สร้างแบบทดสอบใหม่' : 'แก้ไขแบบทดสอบ'),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white)),
          if (!_isSaving) IconButton(icon: const Icon(Icons.save), onPressed: _saveQuiz, tooltip: 'บันทึก'),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ตั้งค่า', icon: Icon(Icons.edit_document)),
            Tab(text: 'มอบหมาย & ผลลัพธ์', icon: Icon(Icons.assignment_ind_outlined)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSettingsTab(),
                _buildAssignmentTab(),
              ],
            ),
    );
  }

  Widget _buildSettingsTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('ข้อมูลทั่วไป'),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'ชื่อแบบทดสอบ*'),
            validator: (value) => value!.isEmpty ? 'กรุณากรอกชื่อแบบทดสอบ' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'คำอธิบาย'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDepartmentId,
            hint: const Text('สำหรับทุกแผนก'),
            items: [
              const DropdownMenuItem(value: null, child: Text("สำหรับทุกแผนก")),
              ..._departments.map((dept) => DropdownMenuItem(value: dept.id, child: Text(dept.name)))
            ],
            onChanged: (value) => setState(() => _selectedDepartmentId = value),
            decoration: const InputDecoration(labelText: 'จำกัดสำหรับแผนก'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('เปิดใช้งานแบบทดสอบ'),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
          const Divider(height: 32),
          _buildSectionHeader('รายการคำถาม (${_questions.length} ข้อ)'),
          if (_questions.isEmpty)
            const Center(child: Text('ยังไม่มีคำถามในแบบทดสอบนี้', style: TextStyle(color: Colors.grey))),
          ..._questions.map((q) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('ประเภท: ${q.type.name}, คะแนน: ${q.points}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showQuestionDialog(questionToEdit: q)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _questions.removeWhere((item) => item.id == q.id))),
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('เพิ่มคำถาม'),
              onPressed: () => _showQuestionDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTab() {
    if (widget.quizId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('กรุณาบันทึกแบบทดสอบก่อนทำการมอบหมายงาน หรือดูผลลัพธ์', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.assignment_add),
            label: const Text('มอบหมายแบบทดสอบให้พนักงาน'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => QuizAssignmentScreen(
                  quizId: widget.quizId!,
                  quizTitle: _titleController.text,
                ),
              )).then((_) {
                // Refresh results after returning from assignment screen
                setState(() {
                  _assignmentResultsFuture = _fetchAssignmentResults();
                });
              });
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSectionHeader('ผลการทดสอบ'),
        ),
        // --- [START] MODIFIED CODE: Use FutureBuilder to display results ---
        Expanded(
          child: FutureBuilder<List<_AssignmentResult>>(
            future: _assignmentResultsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('ยังไม่มีพนักงานที่ได้รับมอบหมาย'));
              }

              final results = snapshot.data!;
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final isCompleted = result.assignment.status == 'completed';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: EmployeeAvatar(
                        imageUrl: result.employee.profileImageUrl,
                        gender: result.employee.gender,
                        radius: 24,
                      ),
                      title: Text(result.employee.fullName),
                      subtitle: Text(
                        isCompleted
                            ? 'ทำแล้ว - ${DateFormat('d/M/yy HH:mm').format(result.assignment.completedAt!.toDate())}'
                            : 'รอดำเนินการ',
                        style: TextStyle(color: isCompleted ? Colors.green : Colors.orange),
                      ),
                      trailing: isCompleted
                          ? Text(
                              '${result.assignment.score} คะแนน',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
        // --- [END] MODIFIED CODE ---
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
      ),
    );
  }
}

// Dialog for Adding/Editing Questions (No changes)
class _QuestionDialog extends StatefulWidget {
  final Question? question;
  final Function(Question) onSave;

  const _QuestionDialog({this.question, required this.onSave});

  @override
  State<_QuestionDialog> createState() => __QuestionDialogState();
}

class __QuestionDialogState extends State<_QuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _textController;
  late TextEditingController _pointsController;
  QuestionType _selectedType = QuestionType.singleChoice;
  List<TextEditingController> _optionControllers = [];
  List<bool> _correctAnswers_Multi = [];
  int? _correctAnswer_Single;
  late TextEditingController _correctAnswer_Text;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question?.text);
    _pointsController = TextEditingController(text: widget.question?.points.toString() ?? '1');
    _correctAnswer_Text = TextEditingController();
    
    if (widget.question != null) {
      _selectedType = widget.question!.type;
      _optionControllers = widget.question!.options.map((opt) => TextEditingController(text: opt)).toList();
      
      if (_selectedType == QuestionType.singleChoice) {
        _correctAnswer_Single = widget.question!.correctAnswers.isNotEmpty ? int.tryParse(widget.question!.correctAnswers.first) : null;
      } else if (_selectedType == QuestionType.multipleChoice) {
        _correctAnswers_Multi = List.generate(_optionControllers.length, (index) => widget.question!.correctAnswers.contains(index.toString()));
      } else {
        _correctAnswer_Text.text = widget.question!.correctAnswers.firstOrNull ?? '';
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _pointsController.dispose();
    _correctAnswer_Text.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
      if (_selectedType == QuestionType.multipleChoice) {
        _correctAnswers_Multi.add(false);
      }
    });
  }
  
  void _removeOption(int index) {
    setState(() {
      _optionControllers.removeAt(index).dispose();
      if (_selectedType == QuestionType.multipleChoice) {
        _correctAnswers_Multi.removeAt(index);
      }
      if (_selectedType == QuestionType.singleChoice && _correctAnswer_Single == index) {
        _correctAnswer_Single = null;
      }
    });
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    List<String> correctAnswers = [];
    if (_selectedType == QuestionType.singleChoice) {
      if (_correctAnswer_Single != null) correctAnswers.add(_correctAnswer_Single.toString());
    } else if (_selectedType == QuestionType.multipleChoice) {
      for (int i = 0; i < _correctAnswers_Multi.length; i++) {
        if (_correctAnswers_Multi[i]) correctAnswers.add(i.toString());
      }
    } else {
      if (_correctAnswer_Text.text.isNotEmpty) correctAnswers.add(_correctAnswer_Text.text);
    }

    if ((_selectedType != QuestionType.textInput && correctAnswers.isEmpty) || (_selectedType == QuestionType.textInput && correctAnswers.first.isEmpty) ) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากำหนดคำตอบที่ถูกต้อง'), backgroundColor: Colors.orange));
        return;
    }

    final newQuestion = Question(
      id: widget.question?.id ?? const Uuid().v4(),
      text: _textController.text,
      type: _selectedType,
      options: _optionControllers.map((c) => c.text).toList(),
      correctAnswers: correctAnswers,
      points: int.tryParse(_pointsController.text) ?? 1,
    );
    
    widget.onSave(newQuestion);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'เพิ่มคำถามใหม่' : 'แก้ไขคำถาม'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(labelText: 'คำถาม*'),
                validator: (v) => v!.isEmpty ? 'กรุณากรอกคำถาม' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<QuestionType>(
                value: _selectedType,
                items: QuestionType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.name))).toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
                decoration: const InputDecoration(labelText: 'ประเภทคำถาม'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pointsController,
                decoration: const InputDecoration(labelText: 'คะแนน*'),
                keyboardType: TextInputType.number,
                validator: (v) => (v!.isEmpty || (int.tryParse(v) ?? 0) <= 0) ? 'คะแนนต้องมากกว่า 0' : null,
              ),
              const Divider(height: 24),
              if (_selectedType == QuestionType.singleChoice || _selectedType == QuestionType.multipleChoice)
                ..._buildChoiceOptions(),
              if (_selectedType == QuestionType.textInput)
                TextFormField(
                  controller: _correctAnswer_Text,
                  decoration: const InputDecoration(labelText: 'คำตอบที่ถูกต้อง*'),
                   validator: (v) => v!.isEmpty ? 'กรุณากรอกคำตอบ' : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        ElevatedButton(onPressed: _handleSave, child: const Text('บันทึก')),
      ],
    );
  }

  List<Widget> _buildChoiceOptions() {
    return [
      const Text('ตัวเลือกและคำตอบ', style: TextStyle(fontWeight: FontWeight.bold)),
      ...List.generate(_optionControllers.length, (index) {
        return Row(
          children: [
            if (_selectedType == QuestionType.singleChoice)
              Radio<int>(
                value: index,
                groupValue: _correctAnswer_Single,
                onChanged: (value) => setState(() => _correctAnswer_Single = value),
              ),
            if (_selectedType == QuestionType.multipleChoice)
              Checkbox(
                value: _correctAnswers_Multi[index],
                onChanged: (value) => setState(() => _correctAnswers_Multi[index] = value!),
              ),
            Expanded(
              child: TextFormField(
                controller: _optionControllers[index],
                decoration: InputDecoration(labelText: 'ตัวเลือกที่ ${index + 1}'),
              ),
            ),
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeOption(index)),
          ],
        );
      }),
      const SizedBox(height: 8),
      TextButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มตัวเลือก'),
        onPressed: _addOption,
      ),
    ];
  }
}
