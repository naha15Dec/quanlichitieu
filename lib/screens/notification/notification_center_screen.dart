import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../models/budget_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/recurring_transaction_service.dart';
import '../../services/transaction_service.dart';
import '../budget/budget_screen.dart';
import '../recurring/recurring_transaction_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_list_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thông báo')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: TransactionService().getTransactionsByUser(user.uid),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = transactionSnapshot.data ?? [];

          return StreamBuilder<BudgetModel?>(
            stream: BudgetService().getBudgetByMonth(
              userId: user.uid,
              monthKey: currentMonthKey,
            ),
            builder: (context, budgetSnapshot) {
              final budget = budgetSnapshot.data;

              return StreamBuilder<List<RecurringTransactionModel>>(
                stream: RecurringTransactionService()
                    .getRecurringTransactionsByUser(user.uid),
                builder: (context, recurringSnapshot) {
                  final recurringItems = recurringSnapshot.data ?? [];

                  final notifications = _buildNotifications(
                    transactions: transactions,
                    budget: budget,
                    recurringItems: recurringItems,
                  );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(notifications.length),
                        const SizedBox(height: 20),
                        if (notifications.isEmpty)
                          _buildEmptyState()
                        else
                          _buildNotificationList(
                            context: context,
                            notifications: notifications,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<_AppNotification> _buildNotifications({
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
    required List<RecurringTransactionModel> recurringItems,
  }) {
    final notifications = <_AppNotification>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTransactions = transactions.where((item) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      return date == today;
    }).toList();

    if (todayTransactions.isEmpty) {
      notifications.add(
        _AppNotification(
          title: 'Chưa ghi chi tiêu hôm nay',
          message:
              'Bạn chưa có giao dịch nào trong ngày hôm nay. Hãy cập nhật để báo cáo chính xác hơn.',
          type: _NotificationType.transaction,
          icon: Icons.edit_note_rounded,
          color: AppColors.primary,
          actionLabel: 'Thêm giao dịch',
          createdLabel: 'Hôm nay',
        ),
      );
    }

    final currentMonthTransactions = transactions.where((item) {
      return item.date.year == now.year && item.date.month == now.month;
    }).toList();

    final currentMonthExpense = _sumByType(currentMonthTransactions, 'expense');

    if (budget == null || budget.totalAvailable <= 0) {
      notifications.add(
        _AppNotification(
          title: 'Chưa thiết lập ngân sách tháng',
          message:
              'Bạn chưa có ngân sách cho tháng này. Hãy tạo ngân sách để theo dõi mức chi tiêu tốt hơn.',
          type: _NotificationType.budget,
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.warning,
          actionLabel: 'Tạo ngân sách',
          createdLabel: 'Tháng này',
        ),
      );
    } else {
      final progress = currentMonthExpense / budget.totalAvailable;
      final remaining = budget.totalAvailable - currentMonthExpense;

      if (progress >= 1) {
        notifications.add(
          _AppNotification(
            title: 'Bạn đã vượt ngân sách',
            message:
                'Chi tiêu tháng này đã vượt ngân sách ${CurrencyFormatter.formatVND(remaining.abs())}. Hãy kiểm tra lại các khoản chi lớn.',
            type: _NotificationType.budget,
            icon: Icons.warning_rounded,
            color: AppColors.expense,
            actionLabel: 'Xem ngân sách',
            createdLabel: 'Quan trọng',
          ),
        );
      } else if (progress >= 0.8) {
        notifications.add(
          _AppNotification(
            title: 'Sắp vượt ngân sách',
            message:
                'Bạn đã sử dụng ${(progress * 100).toStringAsFixed(1)}% ngân sách tháng này.',
            type: _NotificationType.budget,
            icon: Icons.notifications_active_rounded,
            color: AppColors.warning,
            actionLabel: 'Xem ngân sách',
            createdLabel: 'Tháng này',
          ),
        );
      } else if (currentMonthExpense > 0) {
        notifications.add(
          _AppNotification(
            title: 'Ngân sách đang an toàn',
            message:
                'Bạn đã dùng ${(progress * 100).toStringAsFixed(1)}% ngân sách và còn lại ${CurrencyFormatter.formatVND(remaining)}.',
            type: _NotificationType.budget,
            icon: Icons.check_circle_rounded,
            color: AppColors.secondary,
            actionLabel: 'Xem ngân sách',
            createdLabel: 'Tháng này',
          ),
        );
      }
    }

    final dueRecurringItems = recurringItems.where((item) {
      if (!item.isActive) return false;

      final nextRun = DateTime(
        item.nextRunDate.year,
        item.nextRunDate.month,
        item.nextRunDate.day,
      );

      return !nextRun.isAfter(today);
    }).toList();

    if (dueRecurringItems.isNotEmpty) {
      notifications.add(
        _AppNotification(
          title: 'Có giao dịch định kỳ đến hạn',
          message:
              'Bạn có ${dueRecurringItems.length} mẫu giao dịch định kỳ đã đến hạn. Hãy tạo giao dịch để cập nhật sổ chi tiêu.',
          type: _NotificationType.recurring,
          icon: Icons.repeat_rounded,
          color: AppColors.info,
          actionLabel: 'Xem định kỳ',
          createdLabel: 'Đến hạn',
        ),
      );
    } else if (recurringItems.where((item) => item.isActive).isNotEmpty) {
      final nextItems = recurringItems.where((item) => item.isActive).toList()
        ..sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));

      final nearest = nextItems.first;

      notifications.add(
        _AppNotification(
          title: 'Giao dịch định kỳ sắp tới',
          message:
              'Mẫu "${nearest.title}" sẽ đến hạn vào ${DateFormatter.formatDate(nearest.nextRunDate)}.',
          type: _NotificationType.recurring,
          icon: Icons.event_available_rounded,
          color: AppColors.primary,
          actionLabel: 'Xem định kỳ',
          createdLabel: 'Sắp tới',
        ),
      );
    }

    final lastMonthDate = DateTime(now.year, now.month - 1);

    final lastMonthTransactions = transactions.where((item) {
      return item.date.year == lastMonthDate.year &&
          item.date.month == lastMonthDate.month;
    }).toList();

    final lastMonthExpense = _sumByType(lastMonthTransactions, 'expense');

    if (lastMonthExpense > 0 && currentMonthExpense > 0) {
      final diff = currentMonthExpense - lastMonthExpense;
      final percent = diff / lastMonthExpense * 100;

      if (percent >= 15) {
        notifications.add(
          _AppNotification(
            title: 'Chi tiêu tăng so với tháng trước',
            message:
                'Tháng này bạn đang chi cao hơn tháng trước khoảng ${percent.abs().toStringAsFixed(1)}%.',
            type: _NotificationType.insight,
            icon: Icons.trending_up_rounded,
            color: AppColors.expense,
            actionLabel: 'Xem báo cáo',
            createdLabel: 'Insight',
          ),
        );
      } else if (percent <= -15) {
        notifications.add(
          _AppNotification(
            title: 'Chi tiêu giảm tích cực',
            message:
                'Tháng này bạn đang chi thấp hơn tháng trước khoảng ${percent.abs().toStringAsFixed(1)}%.',
            type: _NotificationType.insight,
            icon: Icons.trending_down_rounded,
            color: AppColors.secondary,
            actionLabel: 'Xem báo cáo',
            createdLabel: 'Insight',
          ),
        );
      }
    }

    final categoryStats = _calculateCategoryStats(currentMonthTransactions);

    if (categoryStats.isNotEmpty && currentMonthExpense > 0) {
      final top = categoryStats.entries.first;
      final ratio = top.value / currentMonthExpense * 100;

      if (ratio >= 40) {
        notifications.add(
          _AppNotification(
            title: 'Một danh mục chiếm tỷ lệ cao',
            message:
                'Danh mục "${top.key}" đang chiếm ${ratio.toStringAsFixed(1)}% tổng chi tiêu tháng này.',
            type: _NotificationType.insight,
            icon: Icons.pie_chart_rounded,
            color: AppColors.warning,
            actionLabel: 'Xem báo cáo',
            createdLabel: 'Insight',
          ),
        );
      }
    }

    return notifications;
  }

  double _sumByType(List<TransactionModel> transactions, String type) {
    return transactions
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  Map<String, double> _calculateCategoryStats(
    List<TransactionModel> transactions,
  ) {
    final result = <String, double>{};

    final expenseTransactions = transactions.where(
      (item) => item.type == 'expense',
    );

    for (final item in expenseTransactions) {
      final category = item.category.trim().isEmpty ? 'Khác' : item.category;
      result[category] = (result[category] ?? 0) + item.amount;
    }

    final sortedEntries = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  Widget _buildHeaderCard(int notificationCount) {
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
          const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            'Trung tâm thông báo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notificationCount == 0
                ? 'Hiện chưa có thông báo cần chú ý.'
                : 'Bạn có $notificationCount thông báo được tạo từ dữ liệu tài chính hiện tại.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Không có thông báo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Khi có ngân sách sắp vượt, giao dịch định kỳ đến hạn hoặc insight mới, hệ thống sẽ hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList({
    required BuildContext context,
    required List<_AppNotification> notifications,
  }) {
    return Column(
      children: notifications.map((notification) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildNotificationItem(
            context: context,
            notification: notification,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required _AppNotification notification,
  }) {
    return InkWell(
      onTap: () => _handleNotificationTap(context, notification),
      borderRadius: BorderRadius.circular(24),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                notification.icon,
                color: notification.color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: notification.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          notification.createdLabel,
                          style: TextStyle(
                            color: notification.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        notification.actionLabel,
                        style: TextStyle(
                          color: notification.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: notification.color,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    _AppNotification notification,
  ) {
    switch (notification.type) {
      case _NotificationType.transaction:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        );
        break;

      case _NotificationType.budget:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetScreen()),
        );
        break;

      case _NotificationType.recurring:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecurringTransactionScreen()),
        );
        break;

      case _NotificationType.insight:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionListScreen()),
        );
        break;
    }
  }
}

enum _NotificationType { transaction, budget, recurring, insight }

class _AppNotification {
  final String title;
  final String message;
  final _NotificationType type;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final String createdLabel;

  const _AppNotification({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.createdLabel,
  });
}
