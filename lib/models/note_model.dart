// lib/models/note_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AllocationNote {
  final String id;
  final String text;
  final Timestamp timestamp;
  final String author; // e.g., "Admin"

  AllocationNote({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.author,
  });

  factory AllocationNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AllocationNote(
      id: doc.id,
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      author: data['author'] ?? 'Unknown',
    );
  }
}
