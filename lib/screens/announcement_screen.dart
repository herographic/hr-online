// lib/screens/announcement_screen.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/announcement_model.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/screens/image_viewer_screen.dart';
import 'package:hr_online/widgets/app_layout.dart';
import 'package:hr_online/widgets/employee_status_avatar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class AnnouncementScreen extends StatefulWidget {
  final bool isUserAdmin;
  final Employee? loggedInEmployee;

  const AnnouncementScreen({
    super.key,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Employee> _allEmployees = [];
  bool _isLoadingEmployees = true;
  Employee? _mentionedEmployee;
  bool _isUploading = false;

  final List<Uint8List> _imageBytesList = [];

  @override
  void initState() {
    super.initState();
    _loadAllEmployees();
  }

  Future<void> _loadAllEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').orderBy('employee_name').get();
      if (mounted) {
        setState(() {
          _allEmployees = snapshot.docs.map((doc) => Employee.fromFirestore(doc)).toList();
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดรายชื่อพนักงาน: $e')));
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytesList.add(bytes);
        });
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกรูปได้: $e')));
    }
  }

  Future<void> _postAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _imageBytesList.isEmpty) return;

    setState(() => _isUploading = true);

    List<String> imageUrls = [];
    List<String> imageFileNames = [];

    try {
      if (_imageBytesList.isNotEmpty) {
        await Future.wait(_imageBytesList.map((bytes) async {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageBytesList.indexOf(bytes)}.jpg';
          final ref = FirebaseStorage.instance.ref().child('announcement_images').child(fileName);
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
          imageFileNames.add(fileName);
        }));
      }
      
      final authorPos = widget.loggedInEmployee?.positions.isNotEmpty ?? false
        ? widget.loggedInEmployee!.positions.map((p) => p['name'] ?? '').join(', ')
        : 'ไม่ระบุตำแหน่ง';

      final announcement = Announcement(
        id: '',
        text: text,
        authorId: widget.loggedInEmployee?.employeeId ?? 'admin',
        authorName: widget.loggedInEmployee?.nickname ?? 'ผู้ดูแลระบบ',
        authorImageUrl: widget.loggedInEmployee?.profileImageUrl,
        authorGender: widget.loggedInEmployee?.gender,
        authorPosition: authorPos,
        mentionedEmployeeId: _mentionedEmployee?.employeeId,
        timestamp: Timestamp.now(),
        imageUrls: imageUrls,
        imageFileNames: imageFileNames,
      );

      await FirebaseFirestore.instance.collection('announcements').add(announcement.toFirestore());

      _messageController.clear();
      setState(() {
        _mentionedEmployee = null;
        _imageBytesList.clear();
      });
      FocusScope.of(context).unfocus();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการโพสต์: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบประกาศนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final docSnapshot = await FirebaseFirestore.instance.collection('announcements').doc(docId).get();
        final announcement = Announcement.fromFirestore(docSnapshot);

        if (announcement.imageFileNames != null && announcement.imageFileNames!.isNotEmpty) {
          await Future.wait(announcement.imageFileNames!.map((fileName) {
            return FirebaseStorage.instance.ref().child('announcement_images').child(fileName).delete();
          }));
        }
        
        await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
      }
    }
  }

  Future<void> _showMentionDialog() async {
    final selected = await showDialog<Employee>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredEmployees = _allEmployees.where((emp) {
              final query = searchQuery.toLowerCase();
              return emp.fullName.toLowerCase().contains(query) ||
                     emp.nickname.toLowerCase().contains(query) ||
                     emp.employeeId.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('กล่าวถึงพนักงาน'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => setDialogState(() => searchQuery = value),
                      decoration: const InputDecoration(labelText: 'ค้นหา...', prefixIcon: Icon(Icons.search)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = filteredEmployees[index];
                          return ListTile(
                            leading: EmployeeStatusAvatar(
                              employeeId: employee.employeeId,
                              imageUrl: employee.profileImageUrl, 
                              gender: employee.gender, 
                              radius: 20
                            ),
                            title: Text(employee.fullName),
                            subtitle: Text(employee.employeeId),
                            onTap: () => Navigator.of(context).pop(employee),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() => _mentionedEmployee = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    const newGradient = LinearGradient(
      colors: [Color(0xFF0575E6), Color(0xFF021B79)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return AppLayout(
      isUserAdmin: widget.isUserAdmin,
      loggedInEmployee: widget.loggedInEmployee,
      overrideTitle: 'ประกาศข่าวสาร',
      // --- [START] MODIFIED CODE ---
      // Changed to false to show the drawer menu icon
      showBackButton: false, 
      // --- [END] MODIFIED CODE ---
      bodyGradient: newGradient,
      bodySlivers: [
        SliverFillRemaining(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('announcements').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting || _isLoadingEmployees) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('ยังไม่มีประกาศ', style: GoogleFonts.anuphan(color: Colors.white70)));
                    }

                    final announcements = snapshot.data!.docs.map((doc) => Announcement.fromFirestore(doc)).toList();

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(12.0),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) {
                        final announcement = announcements[index];
                        Employee? mentionedEmployee = _allEmployees.firstWhereOrNull((e) => e.employeeId == announcement.mentionedEmployeeId);
                        
                        return _AnnouncementCard(
                          announcement: announcement,
                          mentionedEmployee: mentionedEmployee,
                          isUserAdmin: widget.isUserAdmin,
                          onDelete: () => _deleteAnnouncement(announcement.id),
                        );
                      },
                    );
                  },
                ),
              ),
              _buildPostInputArea(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isUploading) const LinearProgressIndicator(),
            if (_imageBytesList.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageBytesList.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_imageBytesList[index], height: 100, width: 100, fit: BoxFit.cover),
                          ),
                          Container(
                            margin: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: InkWell(
                              onTap: () => setState(() => _imageBytesList.removeAt(index)),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_mentionedEmployee != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: EmployeeStatusAvatar(
                      employeeId: _mentionedEmployee!.employeeId,
                      imageUrl: _mentionedEmployee!.profileImageUrl, 
                      gender: _mentionedEmployee!.gender, 
                      radius: 12
                    ),
                    label: Text('กล่าวถึง: ${_mentionedEmployee!.nickname}'),
                    onDeleted: () => setState(() => _mentionedEmployee = null),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(icon: Icon(Icons.alternate_email, color: Theme.of(context).primaryColor), onPressed: _isUploading ? null : _showMentionDialog, tooltip: 'กล่าวถึงพนักงาน'),
                IconButton(icon: Icon(Icons.attach_file, color: Theme.of(context).primaryColor), onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery), tooltip: 'แนบไฟล์รูปภาพ'),
                IconButton(icon: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor), onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera), tooltip: 'ถ่ายรูป'),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'พิมพ์ข้อความ...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 5,
                    minLines: 1,
                    enabled: !_isUploading,
                  ),
                ),
                IconButton(icon: Icon(Icons.send, color: Theme.of(context).primaryColor), onPressed: _isUploading ? null : _postAnnouncement),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final Employee? mentionedEmployee;
  final bool isUserAdmin;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    this.mentionedEmployee,
    required this.isUserAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final thaiDateFormat = DateFormat('d MMM yy, HH:mm', 'th_TH');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.blueGrey.withOpacity(0.05),
            child: Row(
              children: [
                EmployeeStatusAvatar(
                  employeeId: announcement.authorId,
                  imageUrl: announcement.authorImageUrl, 
                  gender: announcement.authorGender, 
                  radius: 22
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${announcement.authorName} (${announcement.authorId})',
                        style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        announcement.authorPosition ?? 'ไม่ระบุตำแหน่ง',
                        style: GoogleFonts.anuphan(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        thaiDateFormat.format(announcement.timestamp.toDate()),
                        style: GoogleFonts.anuphan(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (isUserAdmin)
                  IconButton(icon: Icon(Icons.delete_outline, color: Colors.grey.shade600, size: 20), onPressed: onDelete, splashRadius: 20, tooltip: 'ลบประกาศ'),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (announcement.text.isNotEmpty)
                  Text(announcement.text, style: GoogleFonts.anuphan(fontSize: 14, height: 1.5)),
                
                if (announcement.imageUrls != null && announcement.imageUrls!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: announcement.text.isNotEmpty ? 12.0 : 0),
                    child: SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: announcement.imageUrls!.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageViewerScreen(
                                    imageUrls: announcement.imageUrls!,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  announcement.imageUrls![index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                                  errorBuilder: (context, error, stack) => const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                if (mentionedEmployee != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Chip(
                      avatar: EmployeeStatusAvatar(
                        employeeId: mentionedEmployee!.employeeId,
                        imageUrl: mentionedEmployee!.profileImageUrl, 
                        gender: mentionedEmployee!.gender, 
                        radius: 14
                      ),
                      label: Text('ถึง: ${mentionedEmployee!.nickname}', style: GoogleFonts.anuphan(fontSize: 12)),
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
