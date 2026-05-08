import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/vnd_input_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionService _transactionService = TransactionService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String selectedType = 'expense';
  String selectedCategory = 'Ăn uống';
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  final List<String> expenseCategories = [
    'Ăn uống',
    'Mua sắm',
    'Di chuyển',
    'Học tập',
    'Giải trí',
    'Sức khỏe',
    'Nhà cửa',
    'Khác',
  ];

  final List<String> incomeCategories = [
    'Lương',
    'Thưởng',
    'Làm thêm',
    'Đầu tư',
    'Quà tặng',
    'Khác',
  ];

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

  List<String> get currentCategories {
    return selectedType == 'income' ? incomeCategories : expenseCategories;
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

    setState(() {
      isLoading = true;
    });

    try {
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
      );

      await _transactionService.addTransaction(transaction);

      if (!mounted) return;

      showMessage('Thêm giao dịch thành công');

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      showMessage('Thêm giao dịch thất bại');
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

      if (type == 'income') {
        selectedCategory = incomeCategories.first;
      } else {
        selectedCategory = expenseCategories.first;
      }
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
    final isIncome = selectedType == 'income';
    final activeColor = isIncome ? AppColors.income : AppColors.expense;
    final activeSoftColor = isIncome
        ? AppColors.incomeSoft
        : AppColors.expenseSoft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thêm giao dịch')),
      body: SingleChildScrollView(
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

                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    borderRadius: BorderRadius.circular(18),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_rounded),
                      hintText: 'Danh mục',
                    ),
                    items: currentCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
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
                    text: isIncome ? 'Lưu thu nhập' : 'Lưu chi tiêu',
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
