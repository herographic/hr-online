// lib/models/qr_location_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class QrLocation {
  final String id;
  final String name;
  // --- [START] NEW FIELDS ---
  final double? latitude;
  final double? longitude;
  final double? radius; // Allowed check-in radius in meters
  // --- [END] NEW FIELDS ---

  QrLocation({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.radius,
  });

  factory QrLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return QrLocation(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      // --- [START] NEW DATA MAPPING ---
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      radius: (data['radius'] as num?)?.toDouble(),
      // --- [END] NEW DATA MAPPING ---
    );
  }

  // Helper method to convert to map, useful for saving
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }
}
