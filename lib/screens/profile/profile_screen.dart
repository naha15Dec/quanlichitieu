import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isUploadingAvatar = false;
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
      showMessage('Cập nhật thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> pickAndUploadAvatar(String uid) async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (image == null) return;

    setState(() {
      isUploadingAvatar = true;
    });

    try {
      final avatarUrl = await StorageService().uploadAvatar(
        uid: uid,
        image: image,
      );

      await _userService.updateAvatarUrl(uid: uid, avatarUrl: avatarUrl);

      if (!mounted) return;

      showMessage('Cập nhật ảnh đại diện thành công');
    } catch (e) {
      debugPrint('UPLOAD AVATAR ERROR: $e');

      if (!mounted) return;

      showMessage('Upload ảnh thất bại: $e');
    } finally {
      if (mounted) {
        setState(() {
          isUploadingAvatar = false;
        });
      }
    }
  }

  void fillData(UserModel user) {
    if (hasFilledData) return;

    fullNameController.text = user.fullName;
    phoneController.text = user.phone;

    hasFilledData = true;
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
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserProfile(firebaseUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;

          if (user == null) {
            return const Center(child: Text('Chưa có thông tin người dùng'));
          }

          fillData(user);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AppCard(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isUploadingAvatar
                        ? null
                        : () {
                            pickAndUploadAvatar(user.uid);
                          },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          backgroundImage: user.avatarUrl.isNotEmpty
                              ? NetworkImage(user.avatarUrl)
                              : null,
                          child: user.avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 46,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),

                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: isUploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    user.email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  AppTextField(
                    controller: fullNameController,
                    hintText: 'Họ tên',
                    prefixIcon: Icons.person_outline,
                  ),

                  const SizedBox(height: 16),

                  AppTextField(
                    controller: phoneController,
                    hintText: 'Số điện thoại',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 24),

                  AppButton(
                    text: 'Lưu thông tin',
                    isLoading: isSaving,
                    onPressed: () {
                      updateProfile(user.uid);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
