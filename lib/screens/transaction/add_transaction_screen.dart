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
import '../../services/transaction_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  String selectedType = 'expense';
  String selectedCategory = 'Ăn uống';
  DateTime selectedDate = DateTime.now();

  bool isLoading = false;

  final List<XFile> selectedReceiptImages = [];

  final List<_QuickTransactionTemplate> quickTemplates = const [
    _QuickTransactionTemplate(
      title: 'Ăn uống',
      category: 'Ăn uống',
      type: 'expense',
      icon: Icons.restaurant_rounded,
      color: AppColors.expense,
      backgroundColor: AppColors.expenseSoft,
    ),
    _QuickTransactionTemplate(
      title: 'Cà phê',
      category: 'Ăn uống',
      type: 'expense',
      icon: Icons.local_cafe_rounded,
      color: AppColors.warning,
      backgroundColor: AppColors.warningSoft,
    ),
    _QuickTransactionTemplate(
      title: 'Xăng xe',
      category: 'Di chuyển',
      type: 'expense',
      icon: Icons.local_gas_station_rounded,
      color: AppColors.primary,
      backgroundColor: AppColors.primaryLight,
    ),
    _QuickTransactionTemplate(
      title: 'Mua sắm',
      category: 'Mua sắm',
      type: 'expense',
      icon: Icons.shopping_bag_rounded,
      color: AppColors.info,
      backgroundColor: AppColors.infoSoft,
    ),
    _QuickTransactionTemplate(
      title: 'Lương',
      category: 'Lương',
      type: 'income',
      icon: Icons.payments_rounded,
      color: AppColors.income,
      backgroundColor: AppColors.incomeSoft,
    ),
    _QuickTransactionTemplate(
      title: 'Làm thêm',
      category: 'Làm thêm',
      type: 'income',
      icon: Icons.work_rounded,
      color: AppColors.secondary,
      backgroundColor: AppColors.secondaryLight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    initializeDefaultCategories();
  }

  Future<void> initializeDefaultCategories() async {
    final user = AuthService().currentUser;

    if (user == null) return;

    await _categoryService.createDefaultCategoriesIfNeeded(user.uid);
  }

  Future<void> addTransaction() async {
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
      final now = DateTime.now();

      List<String> receiptImageUrls = [];

      if (selectedReceiptImages.isNotEmpty) {
        receiptImageUrls = await _cloudinaryService.uploadImages(
          images: selectedReceiptImages,
          folder: 'smart_expense/receipts/${user.uid}',
        );
      }

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
        receiptImages: receiptImageUrls,
      );

      await _transactionService.addTransaction(transaction);

      if (!mounted) return;

      showMessage('Thêm giao dịch thành công');

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('ADD TRANSACTION ERROR: $e');
      showMessage('Thêm giao dịch thất bại');
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
        selectedReceiptImages.addAll(images);
      });
    } catch (e) {
      showMessage('Không thể chọn ảnh hóa đơn');
    }
  }

  void removeReceiptImage(int index) {
    setState(() {
      selectedReceiptImages.removeAt(index);
    });
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

  void changeTransactionType(String type) {
    setState(() {
      selectedType = type;
      selectedCategory = type == 'income' ? 'Lương' : 'Ăn uống';
    });
  }

  void applyQuickTemplate(_QuickTransactionTemplate template) {
    setState(() {
      selectedType = template.type;
      selectedCategory = template.category;
      titleController.text = template.title;
    });

    FocusScope.of(context).unfocus();
  }

  void selectToday() {
    setState(() {
      selectedDate = DateTime.now();
    });
  }

  void selectYesterday() {
    final now = DateTime.now();

    setState(() {
      selectedDate = now.subtract(const Duration(days: 1));
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
      appBar: AppBar(title: const Text('Thêm giao dịch')),
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
                _buildHeaderCard(
                  isIncome: isIncome,
                  activeColor: activeColor,
                  activeSoftColor: activeSoftColor,
                ),
                const SizedBox(height: 18),
                _buildQuickAddSection(),
                const SizedBox(height: 18),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin giao dịch',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bạn có thể dùng thêm nhanh ở trên hoặc nhập thủ công thông tin bên dưới.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                      if (categories.isEmpty)
                        _buildEmptyCategoryNotice()
                      else
                        DropdownButtonFormField<String>(
                          initialValue:
                              categories.any(
                                (item) => item.name == selectedCategory,
                              )
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
                      const SizedBox(height: 18),
                      _buildReceiptPicker(),
                      const SizedBox(height: 24),
                      AppButton(
                        text: isLoading
                            ? 'Đang lưu giao dịch...'
                            : isIncome
                            ? 'Lưu thu nhập'
                            : 'Lưu chi tiêu',
                        isLoading: isLoading,
                        onPressed: () {
                          if (isLoading) return;
                          addTransaction();
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
            'Ghi nhận nhanh khoản thu chi',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thêm giao dịch mới',
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
                  onTap: () => changeTransactionType('expense'),
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
                  onTap: () => changeTransactionType('income'),
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

  Widget _buildQuickAddSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thêm nhanh',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chọn mẫu phổ biến để tự điền loại giao dịch, danh mục và tên giao dịch.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: quickTemplates.map((template) {
              final isSelected =
                  titleController.text.trim() == template.title &&
                  selectedType == template.type &&
                  selectedCategory == template.category;

              return _buildQuickAddChip(
                template: template,
                isSelected: isSelected,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddChip({
    required _QuickTransactionTemplate template,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: isLoading ? null : () => applyQuickTemplate(template),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? template.color : template.backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? template.color : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              template.icon,
              color: isSelected ? Colors.white : template.color,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              template.title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPicker() {
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
          'Bạn có thể đính kèm ảnh hóa đơn để lưu lại bằng chứng chi tiêu.',
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
                    selectedReceiptImages.isEmpty
                        ? 'Chọn ảnh hóa đơn'
                        : 'Đã chọn ${selectedReceiptImages.length} ảnh',
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
        if (selectedReceiptImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedReceiptImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = selectedReceiptImages[index];

                return InkWell(
                  onTap: isLoading
                      ? null
                      : () => openLocalReceiptImagePreview(image),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: isLoading
                              ? null
                              : () {
                                  removeReceiptImage(index);
                                },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateQuickButton(
                label: 'Hôm nay',
                selected: _isSameDate(selectedDate, DateTime.now()),
                onTap: selectToday,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDateQuickButton(
                label: 'Hôm qua',
                selected: _isSameDate(
                  selectedDate,
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
                onTap: selectYesterday,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
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
        ),
      ],
    );
  }

  Widget _buildDateQuickButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
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

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _QuickTransactionTemplate {
  final String title;
  final String category;
  final String type;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _QuickTransactionTemplate({
    required this.title,
    required this.category,
    required this.type,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
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
