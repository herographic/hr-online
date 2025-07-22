// lib/models/personal_note_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalNote {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final Timestamp timestamp;

  PersonalNote({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
  });

  factory PersonalNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PersonalNote(
      id: doc.id,
      text: data['text'] ?? '',
      authorId: data['authorId'] ?? 'N/A',
      authorName: data['authorName'] ?? 'Unknown',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'timestamp': timestamp,
    };
  }
}
