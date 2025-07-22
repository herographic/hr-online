import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Represents a single sub-item within a job description, including its score.
class JobSubItem {
  final String id;
  final String description;
  final int points;

  JobSubItem({
    required this.id,
    required this.description,
    required this.points,
  });

  /// Converts a JobSubItem instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'points': points,
    };
  }

  /// Creates a JobSubItem instance from a map.
  factory JobSubItem.fromMap(Map<String, dynamic> map) {
    return JobSubItem(
      id: map['id'] ?? const Uuid().v4(),
      description: map['description'] ?? '',
      points: map['points'] ?? 0,
    );
  }
}

/// Represents a main job description category which contains multiple sub-items.
class JobDescription {
  final String id;
  final String title;
  final List<JobSubItem> subItems;
  final Timestamp createdAt;

  JobDescription({
    required this.id,
    required this.title,
    required this.subItems,
    required this.createdAt,
  });

  /// Creates a JobDescription instance from a Firestore document.
  factory JobDescription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final subItemsList = data['subItems'] as List<dynamic>? ?? [];
    return JobDescription(
      id: doc.id,
      title: data['title'] ?? '',
      subItems: subItemsList.map((item) => JobSubItem.fromMap(item as Map<String, dynamic>)).toList(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  /// Converts a JobDescription instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subItems': subItems.map((item) => item.toMap()).toList(),
      'createdAt': createdAt,
    };
  }
}
