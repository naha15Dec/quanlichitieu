import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
import '../../services/quick_expense_parser_service.dart';
import '../../services/transaction_service.dart';

class PhotoQuickConfirmScreen extends StatefulWidget {
  final XFile image;
  final String caption;

  const PhotoQuickConfirmScreen({
    super.key,
    required this.image,
    required this.caption,
  });

  @override
  State<PhotoQuickConfirmScreen> createState() =>
      _PhotoQuickConfirmScreenState();
}

class _PhotoQuickConfirmScreenState extends State<PhotoQuickConfirmScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final QuickExpenseParserService _parserService = QuickExpenseParserService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String selectedType = 'expense';
  String selectedCategory = 'Ăn uống';
  DateTime selectedDate = DateTime.now();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    initializeDefaultCategories();
    parseCaptionToForm();
  }

  Future<void> initializeDefaultCategories() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    await _categoryService.createDefaultCategoriesIfNeeded(user.uid);
  }

  void parseCaptionToForm() {
    final result = _parserService.parse(widget.caption);

    titleController.text = result.title.isNotEmpty
        ? result.title
        : widget.caption;

    if (result.amount != null && result.amount! > 0) {
      amountController.text = formatVndInput(result.amount!.round());
    }

    selectedType = result.type;
    selectedCategory = result.category;
  }

  Future<void> saveTransaction() async {
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
      final imageUrls = await _cloudinaryService.uploadImages(
        images: [widget.image],
        folder: 'smart_expense/photo_expenses/${user.uid}',
      );

      final now = DateTime.now();

      final transaction = TransactionModel(
        id: '',
        userId: user.uid,
        title: title,
        amount: amount,
        type: selectedType,
        category: selectedCategory,
        note: note,
        date: selectedDate,
        createdAt: now,
        receiptImages: imageUrls,
      );

      await _transactionService.addTransaction(transaction);

      if (!mounted) return;

      showMessage('Đã lưu giao dịch bằng ảnh');

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('SAVE PHOTO TRANSACTION ERROR: $e');
      showMessage('Lưu giao dịch thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  void changeTransactionType(String type) {
    setState(() {
      selectedType = type;
      selectedCategory = type == 'income' ? 'Lương' : 'Ăn uống';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xác nhận giao dịch')),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _categoryService.getCategoriesByType(
          userId: user.uid,
          type: selectedType,
        ),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categorySnapshot.data ?? [];
          syncSelectedCategory(categories);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageCaptionPreview(),
                const SizedBox(height: 18),
                _buildConfirmForm(categories),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageCaptionPreview() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            FutureBuilder(
              future: widget.image.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: double.infinity,
                    height: 260,
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }

                return Image.memory(
                  snapshot.data!,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                );
              },
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caption đã gửi',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Sửa caption',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmForm(List<CategoryModel> categories) {
    final isIncome = selectedType == 'income';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Form xác nhận',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bạn có thể sửa lại toàn bộ thông tin trước khi lưu.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  title: 'Chi tiêu',
                  icon: Icons.trending_down_rounded,
                  selected: selectedType == 'expense',
                  selectedColor: AppColors.expense,
                  onTap: () => changeTransactionType('expense'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  title: 'Thu nhập',
                  icon: Icons.trending_up_rounded,
                  selected: selectedType == 'income',
                  selectedColor: AppColors.income,
                  onTap: () => changeTransactionType('income'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: titleController,
            hintText: isIncome
                ? 'Ví dụ: Lương tháng này'
                : 'Ví dụ: Hủ tiếu, cafe...',
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
          if (categories.isEmpty)
            _buildEmptyCategoryNotice()
          else
            DropdownButtonFormField<String>(
              initialValue:
                  categories.any((item) => item.name == selectedCategory)
                  ? selectedCategory
                  : categories.first.name,
              borderRadius: BorderRadius.circular(18),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_rounded),
                hintText: 'Danh mục',
              ),
              items: categories.map((category) {
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
          const SizedBox(height: 24),
          AppButton(
            text: isLoading
                ? 'Đang lưu giao dịch...'
                : isIncome
                ? 'Lưu thu nhập bằng ảnh'
                : 'Lưu chi tiêu bằng ảnh',
            isLoading: isLoading,
            onPressed: () {
              if (isLoading) return;
              saveTransaction();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required IconData icon,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? selectedColor : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? selectedColor : AppColors.textSecondary,
              size: 21,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? selectedColor : AppColors.textPrimary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Thời gian ghi nhận: ${DateFormatter.formatDate(selectedDate)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 18),
        ],
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
