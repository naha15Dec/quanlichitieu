import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/vnd_input_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/transaction_service.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController titleController;
  late TextEditingController amountController;
  late TextEditingController noteController;

  late String selectedType;
  late String selectedCategory;
  late DateTime selectedDate;

  late List<String> existingReceiptImages;
  final List<XFile> newReceiptImages = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.transaction.title);

    amountController = TextEditingController(
      text: NumberFormat.decimalPattern(
        'vi_VN',
      ).format(widget.transaction.amount),
    );

    noteController = TextEditingController(text: widget.transaction.note);

    selectedType = widget.transaction.type;
    selectedCategory = widget.transaction.category;
    selectedDate = widget.transaction.date;
    existingReceiptImages = List<String>.from(widget.transaction.receiptImages);

    initializeDefaultCategories();
  }

  Future<void> initializeDefaultCategories() async {
    final user = AuthService().currentUser;

    if (user == null) return;

    await _categoryService.createDefaultCategoriesIfNeeded(user.uid);
  }

  Future<void> updateTransaction() async {
    final user = AuthService().currentUser;

    if (user == null) {
      showMessage('Bạn chưa đăng nhập');
      return;
    }

    final title = titleController.text.trim();
    final amount = parseVndInput(amountController.text);
    final note = noteController.text.trim();

    if (title.isEmpty) {
      showMessage('Vui lòng nhập tên giao dịch');
      return;
    }

    if (amount <= 0) {
      showMessage('Số tiền phải lớn hơn 0');
      return;
    }

    if (selectedCategory.trim().isEmpty) {
      showMessage('Vui lòng chọn danh mục');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      List<String> uploadedNewUrls = [];

      if (newReceiptImages.isNotEmpty) {
        uploadedNewUrls = await _cloudinaryService.uploadImages(
          images: newReceiptImages,
          folder: 'smart_expense/receipts/${user.uid}',
        );
      }

      final allReceiptImages = [...existingReceiptImages, ...uploadedNewUrls];

      final updatedTransaction = widget.transaction.copyWith(
        title: title,
        amount: amount,
        type: selectedType,
        category: selectedCategory,
        note: note,
        date: selectedDate,
        updatedAt: DateTime.now(),
        receiptImages: allReceiptImages,
      );

      await _transactionService.updateTransaction(updatedTransaction);

      if (!mounted) return;

      showMessage('Cập nhật giao dịch thành công');

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('UPDATE TRANSACTION ERROR: $e');
      showMessage('Cập nhật giao dịch thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> pickReceiptImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (images.isEmpty) return;

      setState(() {
        newReceiptImages.addAll(images);
      });
    } catch (e) {
      showMessage('Không thể chọn ảnh hóa đơn');
    }
  }

  void removeExistingReceiptImage(int index) {
    setState(() {
      existingReceiptImages.removeAt(index);
    });
  }

  void removeNewReceiptImage(int index) {
    setState(() {
      newReceiptImages.removeAt(index);
    });
  }

  void openNetworkReceiptImagePreview(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NetworkReceiptImagePreviewScreen(imageUrl: imageUrl),
      ),
    );
  }

  void openLocalReceiptImagePreview(XFile image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LocalReceiptImagePreviewScreen(image: image),
      ),
    );
  }

  Future<void> pickTransactionDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      helpText: 'Chọn ngày giao dịch',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });
  }

  void changeTransactionType(String type, List<CategoryModel> categories) {
    setState(() {
      selectedType = type;

      final newTypeCategories = categories.where((item) {
        return item.type == type;
      }).toList();

      if (newTypeCategories.isNotEmpty) {
        selectedCategory = newTypeCategories.first.name;
      } else {
        selectedCategory = '';
      }
    });
  }

  void syncSelectedCategory(List<CategoryModel> categories) {
    if (categories.isEmpty) return;

    final exists = categories.any((item) => item.name == selectedCategory);

    if (!exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          selectedCategory = categories.first.name;
        });
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    final isIncome = selectedType == 'income';
    final activeColor = isIncome ? AppColors.income : AppColors.expense;
    final activeSoftColor = isIncome
        ? AppColors.incomeSoft
        : AppColors.expenseSoft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sửa giao dịch')),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _categoryService.getCategoriesByUser(user.uid),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCategories = categorySnapshot.data ?? [];
          final currentCategories = allCategories.where((item) {
            return item.type == selectedType;
          }).toList();

          syncSelectedCategory(currentCategories);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(
                  categories: allCategories,
                  isIncome: isIncome,
                  activeColor: activeColor,
                  activeSoftColor: activeSoftColor,
                ),
                const SizedBox(height: 18),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cập nhật thông tin',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        controller: titleController,
                        hintText: isIncome
                            ? 'Ví dụ: Lương tháng này'
                            : 'Ví dụ: Ăn trưa, mua sách...',
                        prefixIcon: Icons.edit_rounded,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: amountController,
                        hintText: 'Số tiền',
                        prefixIcon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [VndInputFormatter()],
                      ),
                      const SizedBox(height: 16),
                      if (currentCategories.isEmpty)
                        _buildEmptyCategoryNotice()
                      else
                        DropdownButtonFormField<String>(
                          value:
                              currentCategories.any(
                                (item) => item.name == selectedCategory,
                              )
                              ? selectedCategory
                              : currentCategories.first.name,
                          borderRadius: BorderRadius.circular(18),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.category_rounded),
                            hintText: 'Danh mục',
                          ),
                          items: currentCategories.map((category) {
                            return DropdownMenuItem(
                              value: category.name,
                              child: Row(
                                children: [
                                  Icon(
                                    _getIconByName(category.iconName),
                                    size: 20,
                                    color: category.type == 'income'
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(category.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  if (value == null) return;

                                  setState(() {
                                    selectedCategory = value;
                                  });
                                },
                        ),
                      const SizedBox(height: 16),
                      _buildDatePicker(),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: noteController,
                        hintText: 'Ghi chú thêm nếu có',
                        prefixIcon: Icons.notes_rounded,
                      ),
                      const SizedBox(height: 18),
                      _buildReceiptEditor(),
                      const SizedBox(height: 24),
                      AppButton(
                        text: isLoading
                            ? 'Đang cập nhật...'
                            : isIncome
                            ? 'Cập nhật thu nhập'
                            : 'Cập nhật chi tiêu',
                        isLoading: isLoading,
                        onPressed: () {
                          if (isLoading) return;
                          updateTransaction();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard({
    required List<CategoryModel> categories,
    required bool isIncome,
    required Color activeColor,
    required Color activeSoftColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điều chỉnh thông tin giao dịch',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sửa giao dịch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  title: 'Chi tiêu',
                  subtitle: 'Khoản tiền đã dùng',
                  icon: Icons.trending_down_rounded,
                  selected: selectedType == 'expense',
                  selectedColor: AppColors.expense,
                  onTap: () => changeTransactionType('expense', categories),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  title: 'Thu nhập',
                  subtitle: 'Khoản tiền nhận được',
                  icon: Icons.trending_up_rounded,
                  selected: selectedType == 'income',
                  selectedColor: AppColors.income,
                  onTap: () => changeTransactionType('income', categories),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? selectedColor.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: selected ? selectedColor : Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.textSecondary : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptEditor() {
    final totalCount = existingReceiptImages.length + newReceiptImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh hóa đơn',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bạn có thể thêm ảnh mới hoặc xóa ảnh khỏi giao dịch này.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: isLoading ? null : pickReceiptImages,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    totalCount == 0
                        ? 'Chọn ảnh hóa đơn'
                        : 'Đang có $totalCount ảnh hóa đơn',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        if (totalCount > 0) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(existingReceiptImages.length, (index) {
                  final imageUrl = existingReceiptImages[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildExistingReceiptImage(
                      imageUrl: imageUrl,
                      index: index,
                    ),
                  );
                }),
                ...List.generate(newReceiptImages.length, (index) {
                  final image = newReceiptImages[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildNewReceiptImage(image: image, index: index),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExistingReceiptImage({
    required String imageUrl,
    required int index,
  }) {
    return InkWell(
      onTap: isLoading ? null : () => openNetworkReceiptImagePreview(imageUrl),
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              imageUrl,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return Container(
                  width: 92,
                  height: 92,
                  color: AppColors.surfaceSoft,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 92,
                  height: 92,
                  color: AppColors.expenseSoft,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.expense,
                  ),
                );
              },
            ),
          ),
          _buildRemoveImageButton(
            onTap: () => removeExistingReceiptImage(index),
          ),
        ],
      ),
    );
  }

  Widget _buildNewReceiptImage({required XFile image, required int index}) {
    return InkWell(
      onTap: isLoading ? null : () => openLocalReceiptImagePreview(image),
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FutureBuilder(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: 92,
                    height: 92,
                    color: AppColors.surfaceSoft,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                return Image.memory(
                  snapshot.data!,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Mới',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _buildRemoveImageButton(onTap: () => removeNewReceiptImage(index)),
        ],
      ),
    );
  }

  Widget _buildRemoveImageButton({required VoidCallback onTap}) {
    return Positioned(
      top: 6,
      right: 6,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_rounded, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa có danh mục. Vào Cá nhân → Danh mục cá nhân để tạo danh mục mặc định.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: isLoading ? null : pickTransactionDate,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormatter.formatDate(selectedDate),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconByName(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'salary':
        return Icons.payments_rounded;
      case 'bonus':
        return Icons.card_giftcard_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'gift':
        return Icons.redeem_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class _NetworkReceiptImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  const _NetworkReceiptImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: const Text(
          'Xem ảnh hóa đơn',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return const CircularProgressIndicator(color: Colors.white);
              },
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Không thể tải ảnh hóa đơn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalReceiptImagePreviewScreen extends StatelessWidget {
  final XFile image;

  const _LocalReceiptImagePreviewScreen({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: const Text(
          'Xem ảnh hóa đơn',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: FutureBuilder(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator(color: Colors.white);
                }

                return Image.memory(snapshot.data!, fit: BoxFit.contain);
              },
            ),
          ),
        ),
      ),
    );
  }
}
