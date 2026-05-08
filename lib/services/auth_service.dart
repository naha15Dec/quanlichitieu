import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';

      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';

      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';

      case 'wrong-password':
        return 'Mật khẩu không chính xác.';

      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';

      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';

      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng nhập mật khẩu mạnh hơn.';

      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật trong Firebase.';

      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra internet.';

      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';

      default:
        return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
  }
}
