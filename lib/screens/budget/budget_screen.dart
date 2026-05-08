import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/vnd_input_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/budget_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/transaction_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetService _budgetService = BudgetService();

  final TextEditingController monthlyBudgetController = TextEditingController();
  final TextEditingController extraIncomeController = TextEditingController();
  final TextEditingController carryOverController = TextEditingController();

  bool isSaving = false;
  bool hasFilledData = false;

  String get currentMonthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String get currentMonthTitle {
    final now = DateTime.now();
    return 'Tháng ${now.month}/${now.year}';
  }

  Future<void> saveBudget() async {
    final user = AuthService().currentUser;

    if (user == null) {
      showMessage('Bạn chưa đăng nhập');
      return;
    }

    final monthlyBudget = parseVndInput(monthlyBudgetController.text);
    final extraIncome = parseVndInput(extraIncomeController.text);
    final carryOver = parseVndInput(carryOverController.text);

    if (monthlyBudget <= 0) {
      showMessage('Vui lòng nhập ngân sách tháng lớn hơn 0');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      final budget = BudgetModel(
        id: '',
        userId: user.uid,
        monthKey: currentMonthKey,
        monthlyBudget: monthlyBudget,
        extraIncome: extraIncome,
        carryOver: carryOver,
        createdAt: now,
        updatedAt: now,
      );

      await _budgetService.saveBudget(budget);

      if (!mounted) return;

      showMessage('Lưu ngân sách thành công');
    } catch (e) {
      debugPrint('SAVE BUDGET ERROR: $e');
      showMessage('Lưu ngân sách thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void fillBudgetData(BudgetModel? budget) {
    if (hasFilledData || budget == null) return;

    final formatter = NumberFormat.decimalPattern('vi_VN');

    monthlyBudgetController.text = formatter.format(budget.monthlyBudget);
    extraIncomeController.text = formatter.format(budget.extraIncome);
    carryOverController.text = formatter.format(budget.carryOver);

    hasFilledData = true;
  }

  double getCurrentMonthExpense(List<TransactionModel> transactions) {
    final now = DateTime.now();

    return transactions
        .where((item) {
          return item.type == 'expense' &&
              item.date.year == now.year &&
              item.date.month == now.month;
        })
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  double getPreviousMonthExpense(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);

    return transactions
        .where((item) {
          return item.type == 'expense' &&
              item.date.year == previousMonth.year &&
              item.date.month == previousMonth.month;
        })
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  void applyBudgetSuggestion({
    required double previousMonthExpense,
    required double currentMonthExpense,
  }) {
    double suggestedBudget = 0;

    if (previousMonthExpense > 0) {
      suggestedBudget = previousMonthExpense * 1.1;
    } else if (currentMonthExpense > 0) {
      suggestedBudget = currentMonthExpense * 1.2;
    }

    if (suggestedBudget <= 0) {
      showMessage(
        'Chưa có đủ dữ liệu chi tiêu để gợi ý ngân sách. Hãy thêm giao dịch trước.',
      );
      return;
    }

    final roundedSuggestion = (suggestedBudget / 10000).ceil() * 10000;

    monthlyBudgetController.text = NumberFormat.decimalPattern(
      'vi_VN',
    ).format(roundedSuggestion);

    showMessage('Đã áp dụng ngân sách gợi ý');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    monthlyBudgetController.dispose();
    extraIncomeController.dispose();
    carryOverController.dispose();
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
      appBar: AppBar(title: const Text('Ngân sách')),
      body: StreamBuilder<BudgetModel?>(
        stream: _budgetService.getBudgetByMonth(
          userId: user.uid,
          monthKey: currentMonthKey,
        ),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final budget = budgetSnapshot.data;
          fillBudgetData(budget);

          return StreamBuilder<List<TransactionModel>>(
            stream: TransactionService().getTransactionsByUser(user.uid),
            builder: (context, transactionSnapshot) {
              final transactions = transactionSnapshot.data ?? [];
              final totalExpense = getCurrentMonthExpense(transactions);
              final previousMonthExpense = getPreviousMonthExpense(
                transactions,
              );

              final totalAvailable = budget?.totalAvailable ?? 0;
              final remaining = totalAvailable - totalExpense;
              final progress = totalAvailable <= 0
                  ? 0.0
                  : totalExpense / totalAvailable;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(
                      totalAvailable: totalAvailable,
                      totalExpense: totalExpense,
                      remaining: remaining,
                      progress: progress,
                    ),
                    const SizedBox(height: 20),
                    _buildStatusCard(
                      totalAvailable: totalAvailable,
                      totalExpense: totalExpense,
                      progress: progress,
                    ),
                    const SizedBox(height: 20),
                    _buildBudgetForm(
                      previousMonthExpense: previousMonthExpense,
                      currentMonthExpense: totalExpense,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard({
    required double totalAvailable,
    required double totalExpense,
    required double remaining,
    required double progress,
  }) {
    final progressValue = progress.clamp(0.0, 1.0);

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
          Text(
            currentMonthTitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ngân sách tháng',
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
                  title: 'Khả dụng',
                  value: CurrencyFormatter.formatVND(totalAvailable),
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Còn lại',
                  value: CurrencyFormatter.formatVND(remaining),
                  icon: Icons.savings_rounded,
                  iconColor: remaining >= 0
                      ? AppColors.secondary
                      : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              color: progress >= 1
                  ? AppColors.expense
                  : progress >= 0.8
                  ? AppColors.warning
                  : AppColors.secondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            totalAvailable <= 0
                ? 'Chưa thiết lập ngân sách tháng'
                : 'Đã dùng ${(progress * 100).toStringAsFixed(1)}% ngân sách',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required double totalAvailable,
    required double totalExpense,
    required double progress,
  }) {
    String title = 'Chưa có ngân sách';
    String message = 'Hãy thiết lập ngân sách tháng để theo dõi chi tiêu.';
    IconData icon = Icons.info_rounded;
    Color color = AppColors.primary;

    if (totalAvailable > 0) {
      if (progress >= 1) {
        title = 'Đã vượt ngân sách';
        message =
            'Bạn đã chi vượt ngân sách tháng. Nên kiểm tra lại các khoản chi lớn.';
        icon = Icons.warning_rounded;
        color = AppColors.expense;
      } else if (progress >= 0.8) {
        title = 'Sắp vượt ngân sách';
        message =
            'Bạn đã sử dụng hơn 80% ngân sách. Hãy cân nhắc các khoản chi tiếp theo.';
        icon = Icons.notifications_active_rounded;
        color = AppColors.warning;
      } else {
        title = 'Ngân sách đang an toàn';
        message = 'Chi tiêu hiện tại vẫn nằm trong mức ngân sách đã đặt.';
        icon = Icons.check_circle_rounded;
        color = AppColors.secondary;
      }
    }

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetForm({
    required double previousMonthExpense,
    required double currentMonthExpense,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thiết lập ngân sách',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập ngân sách tháng, thu nhập bổ sung và số dư tháng trước để hệ thống tính tổng tiền khả dụng.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestionCard(
            previousMonthExpense: previousMonthExpense,
            currentMonthExpense: currentMonthExpense,
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: monthlyBudgetController,
            hintText: 'Ngân sách tháng',
            prefixIcon: Icons.account_balance_wallet_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [VndInputFormatter()],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: extraIncomeController,
            hintText: 'Thu nhập bổ sung',
            prefixIcon: Icons.add_card_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [VndInputFormatter()],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: carryOverController,
            hintText: 'Số dư tháng trước',
            prefixIcon: Icons.savings_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [VndInputFormatter()],
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Lưu ngân sách',
            isLoading: isSaving,
            onPressed: () {
              if (isSaving) return;
              saveBudget();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required double previousMonthExpense,
    required double currentMonthExpense,
  }) {
    final hasPreviousData = previousMonthExpense > 0;
    final hasCurrentData = currentMonthExpense > 0;

    String description = 'Chưa có đủ dữ liệu để gợi ý ngân sách.';
    String sourceLabel = 'Cần thêm dữ liệu chi tiêu';
    double? suggestion;

    if (hasPreviousData) {
      suggestion = previousMonthExpense * 1.1;
      sourceLabel = 'Dựa trên chi tiêu tháng trước';
      description =
          'Tháng trước bạn đã chi ${CurrencyFormatter.formatVND(previousMonthExpense)}. Hệ thống gợi ý ngân sách tháng này khoảng ${CurrencyFormatter.formatVND(suggestion)}.';
    } else if (hasCurrentData) {
      suggestion = currentMonthExpense * 1.2;
      sourceLabel = 'Dựa trên chi tiêu hiện tại';
      description =
          'Hiện tại bạn đã chi ${CurrencyFormatter.formatVND(currentMonthExpense)}. Hệ thống gợi ý ngân sách tháng này khoảng ${CurrencyFormatter.formatVND(suggestion)}.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Gợi ý ngân sách thông minh',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sourceLabel,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: suggestion == null
                  ? null
                  : () {
                      applyBudgetSuggestion(
                        previousMonthExpense: previousMonthExpense,
                        currentMonthExpense: currentMonthExpense,
                      );
                    },
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Áp dụng gợi ý'),
            ),
          ),
        ],
      ),
    );
  }
}
