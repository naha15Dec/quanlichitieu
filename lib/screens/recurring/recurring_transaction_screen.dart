import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/vnd_input_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/category_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';
import '../../services/recurring_transaction_service.dart';

class RecurringTransactionScreen extends StatefulWidget {
  const RecurringTransactionScreen({super.key});

  @override
  State<RecurringTransactionScreen> createState() =>
      _RecurringTransactionScreenState();
}

class _RecurringTransactionScreenState
    extends State<RecurringTransactionScreen> {
  final RecurringTransactionService _service = RecurringTransactionService();
  final CategoryService _categoryService = CategoryService();

  bool isGenerating = false;

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

  Future<void> generateDueTransactions(
    List<RecurringTransactionModel> items,
  ) async {
    final user = AuthService().currentUser;

    if (user == null) {
      showMessage('Bạn chưa đăng nhập');
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      final count = await _service.generateDueTransactions(
        userId: user.uid,
        recurringItems: items,
      );

      if (!mounted) return;

      if (count == 0) {
        showMessage('Hiện chưa có giao dịch định kỳ nào đến hạn');
      } else {
        showMessage('Đã tạo $count giao dịch đến hạn');
      }
    } catch (e) {
      debugPrint('GENERATE RECURRING ERROR: $e');
      showMessage('Tạo giao dịch định kỳ thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  Future<void> deleteRecurring(RecurringTransactionModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa giao dịch định kỳ'),
          content: Text('Bạn có chắc muốn xóa mẫu "${item.title}" không?'),
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
                'Xóa',
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

    try {
      await _service.deleteRecurringTransaction(item.id);

      if (!mounted) return;

      showMessage('Đã xóa giao dịch định kỳ');
    } catch (e) {
      showMessage('Xóa giao dịch định kỳ thất bại');
    }
  }

  Future<void> toggleActive(RecurringTransactionModel item) async {
    try {
      await _service.updateRecurringTransaction(
        item.copyWith(isActive: !item.isActive),
      );
    } catch (e) {
      showMessage('Cập nhật trạng thái thất bại');
    }
  }

  void openForm({RecurringTransactionModel? recurring}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _RecurringTransactionFormSheet(
          recurring: recurring,
          onSaved: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Giao dịch định kỳ')),
      body: StreamBuilder<List<RecurringTransactionModel>>(
        stream: _service.getRecurringTransactionsByUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          final activeCount = items.where((item) => item.isActive).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(
                  totalCount: items.length,
                  activeCount: activeCount,
                ),
                const SizedBox(height: 20),
                _buildGenerateCard(items),
                const SizedBox(height: 20),
                _buildListSection(items),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          openForm();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildHeaderCard({required int totalCount, required int activeCount}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            'Tự động hóa khoản thu chi lặp lại',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Giao dịch định kỳ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Tổng mẫu',
                  value: '$totalCount',
                  icon: Icons.repeat_rounded,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Đang bật',
                  value: '$activeCount',
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateCard(List<RecurringTransactionModel> items) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tạo giao dịch đến hạn',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Khi bấm nút này, hệ thống sẽ kiểm tra các mẫu đang đến hạn và tự tạo giao dịch thật.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            text: 'Tạo giao dịch đến hạn',
            isLoading: isGenerating,
            onPressed: () {
              if (isGenerating) return;
              generateDueTransactions(items);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(List<RecurringTransactionModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danh sách mẫu định kỳ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildRecurringItem(item),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.repeat_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có giao dịch định kỳ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy tạo các khoản lặp lại như tiền trọ, internet, lương tháng...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringItem(RecurringTransactionModel item) {
    final isIncome = item.type == 'income';
    final color = isIncome ? AppColors.income : AppColors.expense;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isIncome ? Icons.payments_rounded : Icons.repeat_rounded,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_frequencyLabel(item.frequency)} • ${item.category}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: item.isActive,
                activeThumbColor: AppColors.primary,
                onChanged: (_) {
                  toggleActive(item);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoMini(
                  title: 'Số tiền',
                  value:
                      '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatVND(item.amount)}',
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoMini(
                  title: 'Đến hạn',
                  value: DateFormatter.formatDate(item.nextRunDate),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    openForm(recurring: item);
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Sửa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    deleteRecurring(item);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expenseSoft),
                  ),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Xóa'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMini({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Hằng ngày';
      case 'weekly':
        return 'Hằng tuần';
      case 'monthly':
      default:
        return 'Hằng tháng';
    }
  }
}

class _RecurringTransactionFormSheet extends StatefulWidget {
  final RecurringTransactionModel? recurring;
  final VoidCallback onSaved;

  const _RecurringTransactionFormSheet({
    required this.recurring,
    required this.onSaved,
  });

  @override
  State<_RecurringTransactionFormSheet> createState() =>
      _RecurringTransactionFormSheetState();
}

class _RecurringTransactionFormSheetState
    extends State<_RecurringTransactionFormSheet> {
  final RecurringTransactionService _service = RecurringTransactionService();
  final CategoryService _categoryService = CategoryService();

  late TextEditingController titleController;
  late TextEditingController amountController;
  late TextEditingController noteController;

  late String selectedType;
  late String selectedCategory;
  late String selectedFrequency;
  late DateTime selectedStartDate;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    final recurring = widget.recurring;

    titleController = TextEditingController(text: recurring?.title ?? '');

    amountController = TextEditingController(
      text: recurring == null
          ? ''
          : NumberFormat.decimalPattern('vi_VN').format(recurring.amount),
    );

    noteController = TextEditingController(text: recurring?.note ?? '');

    selectedType = recurring?.type ?? 'expense';
    selectedCategory = recurring?.category ?? '';
    selectedFrequency = recurring?.frequency ?? 'monthly';
    selectedStartDate = recurring?.startDate ?? DateTime.now();

    initializeDefaultCategories();
  }

  Future<void> initializeDefaultCategories() async {
    final user = AuthService().currentUser;

    if (user == null) return;

    await _categoryService.createDefaultCategoriesIfNeeded(user.uid);
  }

  Future<void> save() async {
    final user = AuthService().currentUser;

    if (user == null) {
      showMessage('Bạn chưa đăng nhập');
      return;
    }

    final title = titleController.text.trim();
    final amount = parseVndInput(amountController.text);
    final note = noteController.text.trim();

    if (title.isEmpty) {
      showMessage('Vui lòng nhập tên mẫu định kỳ');
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
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      if (widget.recurring == null) {
        final nextRunDate = _service.getInitialNextRunDate(
          startDate: selectedStartDate,
          frequency: selectedFrequency,
        );

        final recurring = RecurringTransactionModel(
          id: '',
          userId: user.uid,
          title: title,
          amount: amount,
          type: selectedType,
          category: selectedCategory,
          note: note,
          frequency: selectedFrequency,
          startDate: selectedStartDate,
          nextRunDate: nextRunDate,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await _service.addRecurringTransaction(recurring);
      } else {
        final nextRunDate = _service.getInitialNextRunDate(
          startDate: selectedStartDate,
          frequency: selectedFrequency,
        );

        final updated = widget.recurring!.copyWith(
          title: title,
          amount: amount,
          type: selectedType,
          category: selectedCategory,
          note: note,
          frequency: selectedFrequency,
          startDate: selectedStartDate,
          nextRunDate: nextRunDate,
          updatedAt: now,
        );

        await _service.updateRecurringTransaction(updated);
      }

      if (!mounted) return;

      widget.onSaved();
    } catch (e) {
      debugPrint('SAVE RECURRING ERROR: $e');
      showMessage('Lưu giao dịch định kỳ thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedStartDate,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
      helpText: 'Chọn ngày bắt đầu',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (pickedDate == null) return;

    setState(() {
      selectedStartDate = pickedDate;
    });
  }

  void changeType(String type, List<CategoryModel> categories) {
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
    final isEdit = widget.recurring != null;

    if (user == null) {
      return const SafeArea(child: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryService.getCategoriesByUser(user.uid),
      builder: (context, categorySnapshot) {
        final allCategories = categorySnapshot.data ?? [];

        final currentCategories = allCategories.where((item) {
          return item.type == selectedType;
        }).toList();

        syncSelectedCategory(currentCategories);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(30),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEdit
                          ? 'Sửa giao dịch định kỳ'
                          : 'Thêm giao dịch định kỳ',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Thiết lập các khoản lặp lại để giảm thao tác nhập liệu thủ công.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeChip(
                            title: 'Chi tiêu',
                            selected: selectedType == 'expense',
                            color: AppColors.expense,
                            onTap: () => changeType('expense', allCategories),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeChip(
                            title: 'Thu nhập',
                            selected: selectedType == 'income',
                            color: AppColors.income,
                            onTap: () => changeType('income', allCategories),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: titleController,
                      hintText: 'Tên mẫu: Tiền trọ, Internet, Lương...',
                      prefixIcon: Icons.repeat_rounded,
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
                    if (categorySnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (currentCategories.isEmpty)
                      _buildEmptyCategoryNotice()
                    else
                      DropdownButtonFormField<String>(
                        initialValue:
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
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFrequency,
                      borderRadius: BorderRadius.circular(18),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.sync_rounded),
                        hintText: 'Tần suất',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'daily',
                          child: Text('Hằng ngày'),
                        ),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Hằng tuần'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Hằng tháng'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                selectedFrequency = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: isSaving ? null : pickStartDate,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
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
                                DateFormatter.formatDate(selectedStartDate),
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
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: noteController,
                      hintText: 'Ghi chú nếu có',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      text: isEdit ? 'Lưu thay đổi' : 'Tạo mẫu định kỳ',
                      isLoading: isSaving,
                      onPressed: () {
                        if (isSaving) return;
                        save();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  Widget _buildTypeChip({
    required String title,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
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
}
