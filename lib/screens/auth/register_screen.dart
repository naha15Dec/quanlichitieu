import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty) {
      showMessage('Vui lòng nhập email');
      return;
    }

    if (!email.contains('@')) {
      showMessage('Email không hợp lệ');
      return;
    }

    if (password.isEmpty) {
      showMessage('Vui lòng nhập mật khẩu');
      return;
    }

    if (password.length < 6) {
      showMessage('Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }

    if (confirmPassword.isEmpty) {
      showMessage('Vui lòng xác nhận mật khẩu');
      return;
    }

    if (password != confirmPassword) {
      showMessage('Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await _authService.register(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        await UserService().createUserIfNotExists(
          UserModel(
            uid: user.uid,
            email: user.email ?? email,
            fullName: '',
            phone: '',
            avatarUrl: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;

      showMessage('Đăng ký thành công');

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildRegisterCard(),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -14),
              child: _buildLoginSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 76),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Tạo tài khoản',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bắt đầu theo dõi thu chi,\nngân sách và báo cáo cá nhân.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đăng ký Smart Expense',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tạo tài khoản để dữ liệu chi tiêu được lưu riêng theo từng người dùng.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          AppTextField(
            controller: emailController,
            hintText: 'Email',
            prefixIcon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 16),

          AppTextField(
            controller: passwordController,
            hintText: 'Mật khẩu',
            prefixIcon: Icons.lock_rounded,
            obscureText: true,
          ),

          const SizedBox(height: 16),

          AppTextField(
            controller: confirmPasswordController,
            hintText: 'Xác nhận mật khẩu',
            prefixIcon: Icons.lock_reset_rounded,
            obscureText: true,
          ),

          const SizedBox(height: 24),

          AppButton(
            text: 'Đăng ký',
            isLoading: isLoading,
            onPressed: () {
              if (isLoading) return;
              register();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Đã có tài khoản?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : goToLogin,
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }
}
