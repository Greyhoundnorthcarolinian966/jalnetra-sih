// lib/models/reading_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WaterReading {
  final String id;
  final String siteId;
  final String officerId;
  final double waterLevel;

  /// ✅ Firebase Storage path
  /// Example: public_readings/TN-CHN-001/uid_timestamp.jpg
  final String imagePath;

  final GeoPoint location;
  final DateTime timestamp;
  final bool isVerified;
  final bool isManual;

  WaterReading({
    required this.id,
    required this.siteId,
    required this.officerId,
    required this.waterLevel,
    required this.imagePath,
    required this.location,
    required this.timestamp,
    this.isVerified = false,
    required this.isManual,
  });

  // ─────────────────────────────────────────────
  // FROM FIRESTORE
  // ─────────────────────────────────────────────
  factory WaterReading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return WaterReading(
      id: doc.id,
      siteId: data['siteId'] ?? '',
      officerId: data['officerId'] ?? '',
      waterLevel: (data['waterLevel'] as num?)?.toDouble() ?? 0.0,

      // ✅ READ STORAGE PATH
      imagePath: data['imagePath'] ?? '',

      location: data['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
      isManual: data['isManual'] ?? false,
    );
  }

  // ─────────────────────────────────────────────
  // TO FIRESTORE
  // ─────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
      'officerId': officerId,
      'waterLevel': waterLevel,

      // ✅ STORE PATH, NOT URL
      'imagePath': imagePath,

      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'isVerified': isVerified,
      'isManual': isManual,
    };
  }
}
