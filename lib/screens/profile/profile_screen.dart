import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/user_model.dart';
import '../../screens/notification/notification_setting_screen.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isSaving = false;
  bool hasFilledData = false;

  Future<void> updateProfile(String uid) async {
    final fullName = fullNameController.text.trim();
    final phone = phoneController.text.trim();

    if (fullName.isEmpty) {
      showMessage('Vui lòng nhập họ tên');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _userService.updateUserProfile(
        uid: uid,
        fullName: fullName,
        phone: phone,
      );

      if (!mounted) return;

      showMessage('Cập nhật thông tin thành công');
    } catch (e) {
      showMessage('Cập nhật thông tin thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: AppColors.expense,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await AuthService().logout();
  }

  void fillData(UserModel user) {
    if (hasFilledData) return;

    fullNameController.text = user.fullName;
    phoneController.text = user.phone;

    hasFilledData = true;
  }

  void openNotificationSetting() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingScreen()),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = AuthService().currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserProfile(firebaseUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;

          if (user == null) {
            _userService.createUserIfNotExists(
              UserModel(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? '',
                fullName: '',
                phone: '',
                avatarUrl: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            return const Center(child: CircularProgressIndicator());
          }

          fillData(user);

          final displayName = user.fullName.trim().isEmpty
              ? 'Người dùng'
              : user.fullName.trim();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user, displayName),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildProfileForm(user),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildUtilityCard(),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildAccountCard(user),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildLogoutButton(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserModel user, String displayName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 30),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          _buildAvatar(displayName),
          const SizedBox(height: 18),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Tài khoản cá nhân',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String displayName) {
    final firstLetter = displayName.trim().isEmpty
        ? 'U'
        : displayName.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileForm(UserModel user) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin cá nhân',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cập nhật thông tin để cá nhân hóa trải nghiệm sử dụng ứng dụng.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: fullNameController,
            hintText: 'Họ tên',
            prefixIcon: Icons.person_rounded,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: phoneController,
            hintText: 'Số điện thoại',
            prefixIcon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Lưu thông tin',
            isLoading: isSaving,
            onPressed: () {
              if (isSaving) return;
              updateProfile(user.uid);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiện ích cá nhân',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thiết lập các tiện ích hỗ trợ quá trình quản lý chi tiêu hằng ngày.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _buildMenuItem(
            icon: Icons.notifications_active_rounded,
            label: 'Nhắc nhở',
            value: 'Ghi chi tiêu và kiểm tra ngân sách',
            color: AppColors.warning,
            backgroundColor: AppColors.warningSoft,
            onTap: openNotificationSetting,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(UserModel user) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài khoản',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _buildAccountItem(
            icon: Icons.email_rounded,
            label: 'Email đăng nhập',
            value: user.email,
          ),
          const Divider(height: 28),
          _buildAccountItem(
            icon: Icons.cloud_done_rounded,
            label: 'Đồng bộ dữ liệu',
            value: 'Firestore theo userId',
          ),
          const Divider(height: 28),
          _buildAccountItem(
            icon: Icons.lock_rounded,
            label: 'Bảo mật',
            value: 'Firebase Authentication',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textMuted,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.expense,
          side: const BorderSide(color: AppColors.expenseSoft),
          backgroundColor: AppColors.surface,
        ),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
      ),
    );
  }
}
