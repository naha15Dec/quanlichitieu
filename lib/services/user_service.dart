import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore
      .instance
      .collection('users');

  Future<void> createUserIfNotExists(UserModel user) async {
    final doc = await _users.doc(user.uid).get();

    if (!doc.exists) {
      await _users.doc(user.uid).set(user.toMap());
    }
  }

  Stream<UserModel?> getUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.data()!);
    });
  }

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String phone,
  }) async {
    await _users.doc(uid).update({'fullName': fullName, 'phone': phone});
  }

  Future<void> updateAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) async {
    await _users.doc(uid).update({'avatarUrl': avatarUrl});
  }
}
