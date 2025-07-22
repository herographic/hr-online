import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String? authorGender;
  final String? authorPosition; // <-- ADDED: To store author's position
  final String? mentionedEmployeeId;
  final Timestamp timestamp;

  // --- [START] MODIFIED CODE ---
  final List<String>? imageUrls; // URL ของรูปภาพที่อัปโหลดแล้ว (List)
  final List<String>? imageFileNames; // ชื่อไฟล์บน Storage (List)
  // --- [END] MODIFIED CODE ---

  Announcement({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    this.authorGender,
    this.authorPosition, // <-- ADDED
    this.mentionedEmployeeId,
    required this.timestamp,
    this.imageUrls,
    this.imageFileNames,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      text: data['text'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Admin',
      authorImageUrl: data['authorImageUrl'],
      authorGender: data['authorGender'],
      authorPosition: data['authorPosition'], // <-- ADDED
      mentionedEmployeeId: data['mentionedEmployeeId'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imageFileNames: List<String>.from(data['imageFileNames'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'authorImageUrl': authorImageUrl,
      'authorGender': authorGender,
      'authorPosition': authorPosition, // <-- ADDED
      'mentionedEmployeeId': mentionedEmployeeId,
      'timestamp': timestamp,
      'imageUrls': imageUrls,
      'imageFileNames': imageFileNames,
    };
  }
}