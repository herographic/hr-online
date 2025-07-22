// hr_online/lib/screens/admin/application_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hr_online/models/job_application_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final String applicationId;

  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _currentStatus;
  
  final _adminNotesController = TextEditingController();
  DateTime? _interviewDate;
  TimeOfDay? _interviewTime;

  @override
  void dispose() {
    _adminNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดใบสมัคร'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_applications')
            .doc(widget.applicationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลใบสมัคร'));
          }

          final application = JobApplication.fromFirestore(snapshot.data!);
          
          if (_currentStatus == null) {
            _currentStatus = application.status;
            _adminNotesController.text = application.adminNotes ?? '';
            if (application.interviewDate != null) {
              _interviewDate = application.interviewDate!.toDate();
              _interviewTime = TimeOfDay.fromDateTime(_interviewDate!);
            }
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildApplicantHeader(application),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'ตำแหน่งที่สมัคร',
                  icon: Icons.work_outline,
                  children: [
                    _buildInfoRow('ตำแหน่งที่ 1:', '${application.position1} (เงินเดือน: ${application.salary1})'),
                    if (application.position2.isNotEmpty)
                      _buildInfoRow('ตำแหน่งสำรอง:', '${application.position2} (เงินเดือน: ${application.salary2})'),
                    _buildInfoRow('ประเภทการจ้าง:', application.employmentType),
                  ],
                ),
                _buildInfoCard(
                  title: 'ข้อมูลส่วนตัว',
                  icon: Icons.person_outline,
                  children: [
                    _buildInfoRow('ชื่อ-สกุล:', '${application.title} ${application.firstName} ${application.lastName} (${application.nickname})'),
                    _buildInfoRow('วันเกิด:', application.birthDate != null ? DateFormat('d MMMM yyyy', 'th_TH').format(application.birthDate!) : '-'),
                    _buildInfoRow('เลขบัตรประชาชน:', application.idCardNumber),
                    _buildInfoRow('สถานะการเกณฑ์ทหาร:', application.militaryStatus),
                    _buildInfoRow('สถานะการศึกษา:', application.graduationStatus),
                  ],
                ),
                _buildInfoCard(
                  title: 'ข้อมูลติดต่อ',
                  icon: Icons.contact_mail_outlined,
                  children: [
                    _buildInfoRow('เบอร์โทรศัพท์:', application.phoneNumber, isLink: true, url: 'tel:${application.phoneNumber}'),
                    if (application.secondaryPhoneNumber.isNotEmpty)
                      _buildInfoRow('เบอร์โทรสำรอง:', application.secondaryPhoneNumber, isLink: true, url: 'tel:${application.secondaryPhoneNumber}'),
                    _buildInfoRow('อีเมล:', application.email, isLink: true, url: 'mailto:${application.email}'),
                    _buildInfoRow('ที่อยู่:', application.address),
                  ],
                ),
                _buildDynamicListCard(
                  title: 'ประวัติการศึกษา',
                  icon: Icons.school_outlined,
                  items: application.educationHistory,
                  itemBuilder: (item) => 'สถาบัน: ${item['institution']}\nสาขา: ${item['major']}, GPA: ${item['gpa']}, ปีที่จบ: ${item['year']}',
                ),
                 _buildDynamicListCard(
                  title: 'สหกิจศึกษา / การฝึกงาน',
                  icon: Icons.business_center_outlined,
                  items: application.internships,
                  itemBuilder: (item) => 'บริษัท: ${item['company']}\nตำแหน่ง: ${item['position']}\nรายละเอียด: ${item['details']}',
                ),
                _buildDynamicListCard(
                  title: 'ประสบการณ์ทำงาน',
                  icon: Icons.history_edu_outlined,
                  items: application.workHistory,
                  itemBuilder: (item) {
                    final durationYears = item['durationYears'] ?? '';
                    final durationMonths = item['durationMonths'] ?? '';
                    String durationText = '';
                    if (durationYears.isNotEmpty) durationText += '$durationYears ปี ';
                    if (durationMonths.isNotEmpty) durationText += '$durationMonths เดือน';

                    return 'บริษัท: ${item['company']}\n'
                           'ตำแหน่ง: ${item['position']}\n'
                           'ระยะเวลา: ${durationText.isNotEmpty ? durationText : '-'}\n'
                           'เงินเดือนล่าสุด: ${item['salaryReceived'] ?? '-'}\n'
                           'รายละเอียดงาน: ${item['jobDetails'] ?? '-'}\n'
                           'เหตุผลที่ออก: ${item['reason'] ?? '-'}';
                  },
                ),
                _buildSkillsCard(application),
                _buildAttachmentsCard(application),
                _buildOfficeUseCard(application),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicantHeader(JobApplication app) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: (app.photoUrl != null && app.photoUrl!.isNotEmpty) ? NetworkImage(app.photoUrl!) : null,
          child: (app.photoUrl == null || app.photoUrl!.isEmpty) ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${app.firstName} ${app.lastName}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('สมัครเมื่อ: ${DateFormat('d MMM yyyy, HH:mm', 'th_TH').format(app.appliedAt.toDate())}', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ]),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLink = false, String? url}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: isLink
                ? InkWell(
                    child: Text(value.isEmpty ? '-' : value, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    onTap: () async {
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  )
                : Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, color: checked ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildDynamicListCard({required String title, required IconData icon, required List<Map<String, dynamic>> items, required String Function(Map<String, dynamic>) itemBuilder}) {
    if (items.isEmpty || items.every((item) => item.values.every((v) => v.toString().isEmpty))) {
      return const SizedBox.shrink();
    }
    return _buildInfoCard(
      title: title,
      icon: icon,
      children: List.generate(items.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(itemBuilder(items[index])),
        );
      }),
    );
  }

  Widget _buildSkillsCard(JobApplication app) {
    String touchTypeStatus;
    if (app.canTouchType == true) {
      touchTypeStatus = 'ได้';
    } else if (app.canTouchType == false) {
      touchTypeStatus = 'ไม่ได้';
    } else {
      touchTypeStatus = 'ไม่ได้ระบุ';
    }

    return _buildInfoCard(
      title: 'ทักษะและความสามารถ',
      icon: Icons.psychology_outlined,
      children: [
        const Text('ทักษะคอมพิวเตอร์:', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildCheckRow('MS-OFFICE (Word, Excel, PowerPoint)', app.hasMsOfficeSkill),
        _buildCheckRow('ใช้เครื่องปริ้นท์/เครื่องถ่ายเอกสารได้', app.canUsePrinterCopier),
        _buildInfoRow('ความสามารถโดยรวม:', app.computerProficiency),
        const Divider(height: 20),
        const Text('ความสามารถในการพิมพ์ดีด:', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildInfoRow('พิมพ์ไทย/อังกฤษ:', '${app.thaiTypingSpeed} / ${app.engTypingSpeed} คำต่อนาที'),
        _buildInfoRow('พิมพ์สัมผัส:', touchTypeStatus),
        const Divider(height: 20),
        const Text('การเขียนโปรแกรมและ AI:', style: TextStyle(fontWeight: FontWeight.bold)),
        _buildInfoRow('ภาษาโปรแกรม:', app.programmingLanguages.isNotEmpty ? app.programmingLanguages.join(', ') : '-'),
        _buildInfoRow('Chat AI ที่ใช้:', app.chatAiUsed.isNotEmpty ? app.chatAiUsed.join(', ') : '-'),
        const Divider(height: 20),
        const Text('เหตุผลที่อยากร่วมงาน:', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(app.motivation.isEmpty ? '-' : app.motivation),
      ],
    );
  }

  Widget _buildAttachmentsCard(JobApplication app) {
    final List<Widget> attachmentLinks = [
      if (app.idCardCopyUrl != null) _buildAttachmentLink('สำเนาบัตรประชาชน', app.idCardCopyUrl!),
      if (app.houseRegCopyUrl != null) _buildAttachmentLink('สำเนาทะเบียนบ้าน', app.houseRegCopyUrl!),
      if (app.portfolioUrl != null) _buildAttachmentLink('ผลงาน (Portfolio)', app.portfolioUrl!),
      if (app.employmentCertificateUrl != null) _buildAttachmentLink('ใบรับรองผ่านงาน', app.employmentCertificateUrl!),
      ...app.otherDocumentsUrls.asMap().entries.map((entry) => _buildAttachmentLink('เอกสารอื่นๆ ${entry.key + 1}', entry.value)),
      if (app.signatureUrl != null) ...[
        const Divider(),
        const Text('ลายมือชื่อ:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Image.network(app.signatureUrl!, height: 100),
      ]
    ];

    if (attachmentLinks.isEmpty) return const SizedBox.shrink();

    return _buildInfoCard(
      title: 'เอกสารแนบ',
      icon: Icons.attach_file_outlined,
      children: attachmentLinks,
    );
  }

  Widget _buildAttachmentLink(String label, String url) {
    return ListTile(
      leading: const Icon(Icons.description_outlined, color: Colors.blue),
      title: Text(label, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildOfficeUseCard(JobApplication application) {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.admin_panel_settings_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              Text('สำหรับเจ้าหน้าที่', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const Divider(height: 24),
            DropdownButtonFormField<String>(
              value: _currentStatus,
              decoration: const InputDecoration(labelText: 'สถานะใบสมัคร'),
              items: ['pending', 'more_info', 'interview', 'hired', 'rejected']
                  .map((status) => DropdownMenuItem(value: status, child: Text(_getStatusText(status))))
                  .toList(),
              onChanged: (value) => setState(() => _currentStatus = value),
            ),
            const SizedBox(height: 16),
            if (_currentStatus == 'more_info')
              TextFormField(
                controller: _adminNotesController,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ขอข้อมูลเพิ่มเติม)',
                  hintText: 'เช่น ขอเอกสารรับรองการทำงานเพิ่มเติม',
                ),
                maxLines: 3,
              ),
            if (_currentStatus == 'interview')
              _buildInterviewDatePicker(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateApplicationStatus,
                child: _isSaving
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('บันทึกสถานะ'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInterviewDatePicker() {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'เลือกวันและเวลานัดสัมภาษณ์',
        hintText: _interviewDate != null
            ? DateFormat('d MMMM yyyy, HH:mm', 'th_TH').format(_interviewDate!)
            : 'กรุณาเลือก',
        suffixIcon: const Icon(Icons.calendar_month),
      ),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _interviewDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (pickedDate == null) return;

        final pickedTime = await showTimePicker(
          context: context,
          initialTime: _interviewTime ?? TimeOfDay.now(),
        );
        if (pickedTime == null) return;

        setState(() {
          _interviewDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _interviewTime = pickedTime;
        });
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'รอพิจารณา';
      case 'more_info': return 'ขอข้อมูลเพิ่มเติม';
      case 'interview': return 'นัดสัมภาษณ์';
      case 'hired': return 'รับเข้าทำงาน';
      case 'rejected': return 'ไม่ผ่านการพิจารณา';
      default: return status;
    }
  }

  void _updateApplicationStatus() async {
    if (_currentStatus == null) return;
    if (_currentStatus == 'interview' && _interviewDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกวันและเวลานัดสัมภาษณ์')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> dataToUpdate = {
        'status': _currentStatus,
        'adminNotes': _adminNotesController.text,
        'interviewDate': _currentStatus == 'interview' ? Timestamp.fromDate(_interviewDate!) : null,
      };

      await FirebaseFirestore.instance
          .collection('job_applications')
          .doc(widget.applicationId)
          .update(dataToUpdate);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตสถานะสำเร็จ'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
