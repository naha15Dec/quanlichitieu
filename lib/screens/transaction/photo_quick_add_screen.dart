import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import 'photo_quick_confirm_screen.dart';

class PhotoQuickAddScreen extends StatefulWidget {
  const PhotoQuickAddScreen({super.key});

  @override
  State<PhotoQuickAddScreen> createState() => _PhotoQuickAddScreenState();
}

class _PhotoQuickAddScreenState extends State<PhotoQuickAddScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController captionController = TextEditingController();

  XFile? selectedImage;
  bool isOpeningCamera = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      capturePhoto();
    });
  }

  Future<void> capturePhoto() async {
    if (isOpeningCamera) return;

    setState(() {
      isOpeningCamera = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      showMessage('Không thể mở camera');
    } finally {
      if (mounted) {
        setState(() {
          isOpeningCamera = false;
        });
      }
    }
  }

  void removePhoto() {
    setState(() {
      selectedImage = null;
      captionController.clear();
    });
  }

  void goToConfirmScreen() {
    final image = selectedImage;
    final caption = captionController.text.trim();

    if (image == null) {
      showMessage('Vui lòng chụp ảnh giao dịch trước');
      return;
    }

    if (caption.isEmpty) {
      showMessage('Vui lòng nhập caption trước khi gửi');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoQuickConfirmScreen(image: image, caption: caption),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = selectedImage != null;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Ghi nhanh bằng ảnh',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isOpeningCamera ? null : capturePhoto,
            icon: const Icon(Icons.camera_alt_rounded),
            tooltip: 'Chụp lại',
          ),
        ],
      ),
      body: SafeArea(
        child: hasImage ? _buildCapturedPhotoView() : _buildEmptyCameraView(),
      ),
    );
  }

  Widget _buildEmptyCameraView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: isOpeningCamera ? null : capturePhoto,
              borderRadius: BorderRadius.circular(34),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isOpeningCamera)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      isOpeningCamera
                          ? 'Đang mở camera...'
                          : 'Chụp ảnh giao dịch',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bấm để mở camera',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ảnh sẽ được dùng làm khoảnh khắc giao dịch. Caption chỉ dùng để tự điền form xác nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedPhotoView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
            child: Column(
              children: [
                _buildPhotoCard(),
                const SizedBox(height: 16),
                _buildActionBar(),
                const SizedBox(height: 10),
                const Text(
                  'Gửi để tạo form xác nhận',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: Stack(
        children: [
          FutureBuilder(
            future: selectedImage!.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: double.infinity,
                  height: 560,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }

              return Image.memory(
                snapshot.data!,
                width: double.infinity,
                height: 560,
                fit: BoxFit.cover,
              );
            },
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.50),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _buildCircleButton(
                  icon: Icons.close_rounded,
                  onTap: removePhoto,
                ),
                const Spacer(),
                _buildCircleButton(
                  icon: Icons.camera_alt_rounded,
                  onTap: capturePhoto,
                ),
              ],
            ),
          ),

          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: captionController,
                  minLines: 1,
                  maxLines: 3,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Thêm caption... VD: hủ tiếu -20k',
                    hintStyle: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.45),
                    prefixIcon: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        captionController.clear();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                  onSubmitted: (_) => goToConfirmScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: _buildTextActionButton(
            icon: Icons.refresh_rounded,
            label: 'Chụp lại',
            onTap: capturePhoto,
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: goToConfirmScreen,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Xóa',
            onTap: removePhoto,
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isOpeningCamera ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.46),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }

  Widget _buildTextActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isOpeningCamera ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
