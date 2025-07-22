// lib/widgets/work_submission_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_online/models/employee_model.dart';
import 'package:hr_online/models/work_submission_model.dart';
import 'package:hr_online/providers/attendance_status_provider.dart';
import 'package:hr_online/screens/image_viewer_screen.dart';
import 'package:hr_online/widgets/employee_status_avatar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WorkSubmissionCard extends StatefulWidget {
  final WorkSubmission submission;
  final Employee? loggedInEmployee;
  final bool isUserAdmin;

  const WorkSubmissionCard({
    super.key,
    required this.submission,
    required this.isUserAdmin,
    this.loggedInEmployee,
  });

  @override
  State<WorkSubmissionCard> createState() => _WorkSubmissionCardState();
}

class _WorkSubmissionCardState extends State<WorkSubmissionCard> {
  List<String> _scoreGivingPositionIds = [];
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    if (widget.isUserAdmin) {
      setState(() => _isLoadingPermissions = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('score_permissions').get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _scoreGivingPositionIds = List<String>.from(data['allowedPositionIds'] ?? []);
        });
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _isLoadingPermissions = false);
      }
    }
  }

  Future<void> _updateRating(int score) async {
    final scorerId = widget.loggedInEmployee?.employeeId;
    if (scorerId == null) return;

    final submissionRef = FirebaseFirestore.instance.collection('work_submissions').doc(widget.submission.id);
    final employeeRef = FirebaseFirestore.instance.collection('users').doc(widget.submission.authorId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final submissionSnapshot = await transaction.get(submissionRef);
        final employeeSnapshot = await transaction.get(employeeRef);

        if (!submissionSnapshot.exists || !employeeSnapshot.exists) {
          throw Exception("Document does not exist!");
        }

        final submissionData = submissionSnapshot.data()!;
        final employeeData = employeeSnapshot.data()!;
        final currentRatings = Map<String, int>.from(submissionData['ratings'] ?? {});
        final oldScoreFromThisUser = currentRatings[scorerId] ?? 0;

        if (oldScoreFromThisUser > 0) {
          throw ('คุณได้ให้คะแนนโพสต์นี้ไปแล้ว');
        }

        currentRatings[scorerId] = score;

        final newSubmissionTotalScore = currentRatings.values.fold(0, (sum, item) => sum + item);
        final scoreDifference = newSubmissionTotalScore - (submissionData['totalScore'] ?? 0);
        final newEmployeeTotalScore = (employeeData['totalScore'] ?? 0) + scoreDifference;

        transaction.update(submissionRef, {
          'ratings': currentRatings,
          'totalScore': newSubmissionTotalScore,
        });

        transaction.update(employeeRef, {
          'totalScore': newEmployeeTotalScore,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showScoreDialog() {
    int selectedScore = 5;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ให้คะแนนผลงาน'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$selectedScore', style: Theme.of(context).textTheme.headlineMedium),
                  Slider(
                    value: selectedScore.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: selectedScore.toString(),
                    onChanged: (double value) {
                      setDialogState(() {
                        selectedScore = value.toInt();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateRating(selectedScore);
                  },
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildContent(),
            if (widget.submission.imageUrls.isNotEmpty) _buildImageGallery(context),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AttendanceStatusProvider>(
      builder: (context, attendanceProvider, child) {
        final attendanceStatus = attendanceProvider.statuses[widget.submission.authorId] ?? EmployeeAttendanceStatus.unknown;
        
        final bool isOnline = attendanceStatus == EmployeeAttendanceStatus.checkedIn;
        final Color onlineStatusColor = isOnline ? Colors.green.shade400 : Colors.red.shade400;
        final String onlineStatusText = isOnline ? 'Online' : 'Offline';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.submission.authorId).snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(children: [SizedBox(width: 75, height: 75), CircularProgressIndicator(color: Colors.white)])
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final totalScore = userData['totalScore'] ?? 0;
            final authorGender = userData['gender'] as String?;
            final postTime = thaiDateFormat.format(widget.submission.timestamp.toDate());

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  EmployeeStatusAvatar(
                    employeeId: widget.submission.authorId,
                    imageUrl: widget.submission.authorImageUrl,
                    gender: authorGender,
                    radius: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.submission.authorNickname} (${widget.submission.authorId})',
                          style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white, shadows: [const Shadow(blurRadius: 2, color: Colors.black38)]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.submission.authorDepartment ?? 'ไม่ระบุแผนก'} • ${widget.submission.authorPosition ?? 'ไม่ระบุตำแหน่ง'}',
                          style: GoogleFonts.anuphan(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 9, height: 9,
                              decoration: BoxDecoration(color: onlineStatusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                            ),
                            const SizedBox(width: 5),
                            Text(onlineStatusText, style: GoogleFonts.anuphan(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            Text("  •  ", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                            Icon(Icons.military_tech_outlined, color: Colors.amber.shade200, size: 14),
                            const SizedBox(width: 4),
                            Text('$totalScore', style: GoogleFonts.anuphan(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            Text("  •  ", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(postTime, style: GoogleFonts.anuphan(fontSize: 12, color: Colors.white.withOpacity(0.9)), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  final DateFormat thaiDateFormat = DateFormat('d MMM yy, HH:mm', 'th_TH');

  Widget _buildContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.submission.title, style: GoogleFonts.anuphan(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1a237e))),
          const Divider(height: 24),
          Text(widget.submission.details, style: GoogleFonts.sarabun(fontSize: 15, color: Colors.black87, height: 1.6)),
          if (widget.submission.expectedResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'ผลลัพธ์ที่คาดหวัง: ', style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, color: Colors.black)),
                TextSpan(text: widget.submission.expectedResult, style: GoogleFonts.sarabun(color: Colors.black87, fontSize: 14)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: widget.submission.imageUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageViewerScreen(imageUrls: widget.submission.imageUrls, initialIndex: index))),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.submission.imageUrls[index],
                    width: 100,
                    height: 100,
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
    );
  }

  Widget _buildFooter() {
    final scorerId = widget.loggedInEmployee?.employeeId ?? 'guest';
    final bool hasRated = widget.submission.ratings.containsKey(scorerId);
    final bool isLiked = hasRated && widget.submission.ratings[scorerId] == 1;

    bool canGiveDetailedScore = false;
    if (widget.isUserAdmin) {
      canGiveDetailedScore = true;
    } else if (widget.loggedInEmployee != null && !_isLoadingPermissions) {
      final bool sameDepartment = widget.loggedInEmployee!.departmentCode == widget.submission.authorDepartmentId;
      if (sameDepartment) {
        final userPositionIds = widget.loggedInEmployee!.positions.map((p) => p['id'].toString()).toList();
        final hasScoringRole = userPositionIds.any((posId) => _scoreGivingPositionIds.contains(posId));
        if (hasScoringRole) {
          canGiveDetailedScore = true;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.submission.taggedEmployees.isNotEmpty)
            Tooltip(
              message: 'แท็กถึง: ${widget.submission.taggedEmployees.map((e) => e['name']).join(', ')}',
              child: const Icon(Icons.alternate_email, size: 20, color: Colors.grey),
            ),
          const Spacer(),
          Row(
            children: [
              TextButton.icon(
                onPressed: hasRated ? null : () => _updateRating(1),
                icon: Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, color: isLiked ? Theme.of(context).primaryColor : Colors.grey),
                label: Text('${widget.submission.ratings.length}', style: TextStyle(color: isLiked ? Theme.of(context).primaryColor : Colors.grey)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              if (canGiveDetailedScore)
                IconButton(
                  icon: const Icon(Icons.star_border, color: Colors.amber),
                  tooltip: 'ให้คะแนน',
                  onPressed: hasRated ? null : _showScoreDialog,
                ),
              const SizedBox(width: 8),
              const Icon(Icons.military_tech, color: Colors.orange, size: 20),
              const SizedBox(width: 4),
              Text(
                '${widget.submission.totalScore}',
                style: GoogleFonts.anuphan(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
