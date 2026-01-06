// lib/common/firebase_service.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:jalnetra01/models/reading_model.dart';
import 'package:jalnetra01/models/user_models.dart';
import '../firebase_options.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Explicit storage bucket (safe for all platforms)
  late final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: DefaultFirebaseOptions.currentPlatform.storageBucket,
  );

  // ─────────────────────────────────────────────
  // AUTH & USER MANAGEMENT
  // ─────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> signUp(
    String email,
    String password,
    String name,
    UserRole role, {
    String? phone,
    String? employeeId,
    String? department,
    String? designation,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) return null;

      final appUser = AppUser(
        id: user.uid,
        name: name,
        email: email,
        role: role,
        phone: phone,
        employeeId: employeeId,
        department: department,
        designation: designation,
      );

      await _firestore.collection('users').doc(user.uid).set({
        ...appUser.toMap(),
        'isAccountVerified': false,
      });

      return appUser;
    } catch (e) {
      debugPrint('❌ SignUp Error: $e');
      rethrow;
    }
  }

  Future<AppUser?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await getUserData(result.user!.uid);
    } catch (e) {
      debugPrint('❌ SignIn Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return AppUser.fromMap(data);
    } catch (e) {
      debugPrint('❌ GetUserData Error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN USER MANAGEMENT
  // ─────────────────────────────────────────────

  Stream<List<AppUser>> getUsersByRole(UserRole role) {
    final roleStr = role.toString().split('.').last;
    return _firestore
        .collection('users')
        .where('role', isEqualTo: roleStr)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return AppUser.fromMap(data);
          }).toList(),
        );
  }

  Stream<List<AppUser>> getUnverifiedUsers() {
    return _firestore
        .collection('users')
        .where('isAccountVerified', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return AppUser.fromMap(data);
          }).toList(),
        );
  }

  Future<void> updateUserRole(String uid, UserRole role, bool verified) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role.toString().split('.').last,
      'isAccountVerified': verified,
    });
  }

  // ─────────────────────────────────────────────
  // SOS ALERT (PUBLIC USER)
  // ─────────────────────────────────────────────

  Future<void> sendSosNotification({
    required String userEmail,
    required String message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated for SOS');
      }

      await _firestore.collection('sos_alerts').add({
        'senderId': currentUser.uid,
        'senderEmail': userEmail,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'NEW',
        'alertedRoles': [UserRole.fieldOfficer.name, UserRole.supervisor.name],
      });

      debugPrint('🚨 SOS alert sent by $userEmail');
    } catch (e, st) {
      debugPrint('❌ SOS Error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // READING SUBMISSION (FIELD OFFICER & PUBLIC)
  // ─────────────────────────────────────────────

  Future<void> submitReading(WaterReading reading, File imageFile) async {
    await _submitReadingInternal(
      collectionName: 'readings',
      reading: reading,
      imageFile: imageFile,
    );
  }

  Future<void> submitPublicReading(WaterReading reading, File imageFile) async {
    await _submitReadingInternal(
      collectionName: 'public_readings',
      reading: reading,
      imageFile: imageFile,
    );
  }

  /// 🔥 CORE upload + Firestore write logic
  Future<void> _submitReadingInternal({
    required String collectionName,
    required WaterReading reading,
    required File imageFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final safeSiteId = reading.siteId.replaceAll(RegExp(r'[^\w\-]'), '');
      final safeTime = DateTime.now().millisecondsSinceEpoch.toString();

      final fileName = '${user.uid}_$safeTime.jpg';
      final imagePath = '$collectionName/$safeSiteId/$fileName';

      debugPrint('📤 Uploading image to: $imagePath');

      final ref = _storage.ref(imagePath);
      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

      final docRef = _firestore.collection(collectionName).doc();

      final finalReading = WaterReading(
        id: docRef.id,
        siteId: reading.siteId,
        officerId: user.uid,
        waterLevel: reading.waterLevel,
        imagePath: imagePath,
        location: reading.location,
        timestamp: reading.timestamp,
        isVerified: false,
        isManual: reading.isManual,
      );

      await docRef.set(finalReading.toMap());

      debugPrint('✅ Reading saved with imagePath');
    } catch (e, st) {
      debugPrint('🔥 SubmitReading Error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // REMOVE USER (ADMIN ONLY)
  // ─────────────────────────────────────────────
  Future<void> removeUser(String userId) async {
    try {
      // 1️⃣ Remove user document from Firestore
      await _firestore.collection('users').doc(userId).delete();

      debugPrint('🗑️ User removed from Firestore: $userId');
    } catch (e, st) {
      debugPrint('❌ RemoveUser Error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Stream<List<WaterReading>> getCommunityInputs() {
    return _firestore
        .collection('readings')
        .where('isVerified', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => WaterReading.fromFirestore(d)).toList(),
        );
  }

  Stream<List<WaterReading>> getAllVerifiedReadings() {
    return _firestore
        .collection('readings')
        .where('isVerified', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => WaterReading.fromFirestore(d)).toList(),
        );
  }

  Future<void> updateVerificationStatus(String readingId, bool verified) async {
    await _firestore.collection('readings').doc(readingId).update({
      'isVerified': verified,
    });
  }
}
