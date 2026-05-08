import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore
      .instance
      .collection('users');

  Future<void> createUserIfNotExists(UserModel user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final now = DateTime.now();

      final newUser = user.copyWith(
        createdAt: user.createdAt ?? now,
        updatedAt: user.updatedAt ?? now,
      );

      await docRef.set(newUser.toMap());
    }
  }

  Stream<UserModel?> getUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data();

      if (!doc.exists || data == null) {
        return null;
      }

      return UserModel.fromMap(data);
    });
  }

  Future<UserModel?> getUserProfileOnce(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();

    if (!doc.exists || data == null) {
      return null;
    }

    return UserModel.fromMap(data);
  }

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String phone,
  }) async {
    await _users.doc(uid).update({
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) async {
    await _users.doc(uid).update({
      'avatarUrl': avatarUrl.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
