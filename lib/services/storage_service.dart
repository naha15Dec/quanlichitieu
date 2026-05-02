import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadAvatar({
    required String uid,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();

    final ref = _storage.ref().child('avatars/$uid.jpg');

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    return await ref.getDownloadURL();
  }
}
