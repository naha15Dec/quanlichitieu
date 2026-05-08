import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/vnd_input_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final TransactionService _transactionService = TransactionService();

  late TextEditingController titleController;
  late TextEditingController amountController;
  late TextEditingController noteController;

  late String selectedType;
  late String selectedCategory;
  late DateTime selectedDate;

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

  List<String> get currentCategories {
    return selectedType == 'income' ? incomeCategories : expenseCategories;
  }

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
    selectedDate = widget.transaction.date;

    final originalCategory = widget.transaction.category.trim();

    if (selectedType == 'income') {
      selectedCategory = incomeCategories.contains(originalCategory)
          ? originalCategory
          : incomeCategories.first;
    } else {
      selectedCategory = expenseCategories.contains(originalCategory)
          ? originalCategory
          : expenseCategories.last;
    }
  }

  Future<void> updateTransaction() async {
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
      final updatedTransaction = widget.transaction.copyWith(
        title: title,
        amount: amount,
        type: selectedType,
        category: selectedCategory,
        note: note,
        date: selectedDate,
        updatedAt: DateTime.now(),
      );

      await _transactionService.updateTransaction(updatedTransaction);

      if (!mounted) return;

      showMessage('Cập nhật giao dịch thành công');

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      showMessage('Cập nhật giao dịch thất bại');
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
        if (!incomeCategories.contains(selectedCategory)) {
          selectedCategory = incomeCategories.first;
        }
      } else {
        if (!expenseCategories.contains(selectedCategory)) {
          selectedCategory = expenseCategories.first;
        }
      }
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
      appBar: AppBar(title: const Text('Sửa giao dịch')),
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
                    text: isIncome ? 'Cập nhật thu nhập' : 'Cập nhật chi tiêu',
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
}
