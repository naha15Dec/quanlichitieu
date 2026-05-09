import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';

class FinancialSummaryScreen extends StatelessWidget {
  const FinancialSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tóm tắt tài chính')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: TransactionService().getTransactionsByUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data ?? [];

          final weekData = _buildWeekSummary(transactions);
          final previousWeekData = _buildPreviousWeekSummary(transactions);
          final monthData = _buildMonthSummary(transactions);

          final insights = _buildInsights(
            weekData: weekData,
            previousWeekData: previousWeekData,
            monthData: monthData,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(weekData: weekData, monthData: monthData),
                const SizedBox(height: 20),
                _buildWeekSummaryCard(
                  weekData: weekData,
                  previousWeekData: previousWeekData,
                ),
                const SizedBox(height: 20),
                _buildMonthSummaryCard(monthData),
                const SizedBox(height: 20),
                _buildTopCategoryCard(
                  title: 'Danh mục nổi bật trong tuần',
                  categoryStats: weekData.categoryStats,
                  totalExpense: weekData.totalExpense,
                ),
                const SizedBox(height: 20),
                _buildTopCategoryCard(
                  title: 'Danh mục nổi bật trong tháng',
                  categoryStats: monthData.categoryStats,
                  totalExpense: monthData.totalExpense,
                ),
                const SizedBox(height: 20),
                _buildInsightCard(insights),
              ],
            ),
          );
        },
      ),
    );
  }

  static _SummaryData _buildWeekSummary(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final weekTransactions = transactions.where((item) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      return !date.isBefore(startOfWeek) && !date.isAfter(endOfWeek);
    }).toList();

    return _buildSummaryData(
      transactions: weekTransactions,
      startDate: startOfWeek,
      endDate: endOfWeek,
    );
  }

  static _SummaryData _buildPreviousWeekSummary(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final currentStartOfWeek = _startOfWeek(now);
    final previousStartOfWeek = currentStartOfWeek.subtract(
      const Duration(days: 7),
    );
    final previousEndOfWeek = previousStartOfWeek.add(const Duration(days: 6));

    final previousWeekTransactions = transactions.where((item) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      return !date.isBefore(previousStartOfWeek) &&
          !date.isAfter(previousEndOfWeek);
    }).toList();

    return _buildSummaryData(
      transactions: previousWeekTransactions,
      startDate: previousStartOfWeek,
      endDate: previousEndOfWeek,
    );
  }

  static _SummaryData _buildMonthSummary(List<TransactionModel> transactions) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final monthTransactions = transactions.where((item) {
      return item.date.year == now.year && item.date.month == now.month;
    }).toList();

    return _buildSummaryData(
      transactions: monthTransactions,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
  }

  static _SummaryData _buildSummaryData({
    required List<TransactionModel> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final totalIncome = transactions
        .where((item) => item.type == 'income')
        .fold<double>(0, (sum, item) => sum + item.amount);

    final totalExpense = transactions
        .where((item) => item.type == 'expense')
        .fold<double>(0, (sum, item) => sum + item.amount);

    final categoryStats = <String, double>{};

    for (final item in transactions.where((item) => item.type == 'expense')) {
      final category = item.category.trim().isEmpty ? 'Khác' : item.category;
      categoryStats[category] = (categoryStats[category] ?? 0) + item.amount;
    }

    final sortedEntries = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _SummaryData(
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transactionCount: transactions.length,
      categoryStats: Map.fromEntries(sortedEntries),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final currentDate = DateTime(date.year, date.month, date.day);
    return currentDate.subtract(Duration(days: currentDate.weekday - 1));
  }

  static List<String> _buildInsights({
    required _SummaryData weekData,
    required _SummaryData previousWeekData,
    required _SummaryData monthData,
  }) {
    final insights = <String>[];

    if (weekData.transactionCount == 0) {
      insights.add(
        'Tuần này chưa có giao dịch nào. Hãy ghi lại các khoản thu chi để hệ thống tóm tắt chính xác hơn.',
      );
    } else {
      insights.add(
        'Tuần này bạn có ${weekData.transactionCount} giao dịch, tổng chi là ${CurrencyFormatter.formatVND(weekData.totalExpense)}.',
      );
    }

    if (previousWeekData.totalExpense > 0 && weekData.totalExpense > 0) {
      final diff = weekData.totalExpense - previousWeekData.totalExpense;
      final percent = diff / previousWeekData.totalExpense * 100;

      if (diff > 0) {
        insights.add(
          'Chi tiêu tuần này cao hơn tuần trước khoảng ${percent.abs().toStringAsFixed(1)}%.',
        );
      } else if (diff < 0) {
        insights.add(
          'Chi tiêu tuần này thấp hơn tuần trước khoảng ${percent.abs().toStringAsFixed(1)}%. Đây là tín hiệu tích cực.',
        );
      } else {
        insights.add('Chi tiêu tuần này gần như tương đương tuần trước.');
      }
    }

    if (weekData.categoryStats.isNotEmpty) {
      final topCategory = weekData.categoryStats.entries.first;
      final ratio = weekData.totalExpense <= 0
          ? 0
          : topCategory.value / weekData.totalExpense * 100;

      insights.add(
        'Danh mục "${topCategory.key}" đang chiếm ${ratio.toStringAsFixed(1)}% chi tiêu tuần này.',
      );
    }

    if (monthData.totalIncome > 0) {
      final expenseRatio = monthData.totalExpense / monthData.totalIncome;

      if (expenseRatio >= 1) {
        insights.add(
          'Tổng chi tháng này đã bằng hoặc vượt tổng thu. Bạn nên kiểm tra lại các khoản chi lớn.',
        );
      } else if (expenseRatio >= 0.8) {
        insights.add(
          'Tháng này bạn đã dùng hơn 80% thu nhập. Nên hạn chế các khoản chi không cần thiết.',
        );
      } else {
        insights.add(
          'Tỷ lệ chi tiêu so với thu nhập tháng này đang ở mức tương đối ổn.',
        );
      }
    }

    return insights;
  }

  Widget _buildHeaderCard({
    required _SummaryData weekData,
    required _SummaryData monthData,
  }) {
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
            'Tổng hợp nhanh tình hình thu chi',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tóm tắt tài chính',
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
                  title: 'Chi tuần',
                  value: CurrencyFormatter.formatVND(weekData.totalExpense),
                  icon: Icons.calendar_view_week_rounded,
                  iconColor: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Chi tháng',
                  value: CurrencyFormatter.formatVND(monthData.totalExpense),
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppColors.expense,
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

  Widget _buildWeekSummaryCard({
    required _SummaryData weekData,
    required _SummaryData previousWeekData,
  }) {
    String compareMessage = 'Chưa có dữ liệu tuần trước để so sánh.';
    Color compareColor = AppColors.primary;
    IconData compareIcon = Icons.info_rounded;

    if (previousWeekData.totalExpense > 0) {
      final diff = weekData.totalExpense - previousWeekData.totalExpense;
      final percent = diff / previousWeekData.totalExpense * 100;

      if (diff > 0) {
        compareMessage =
            'Chi tiêu tăng ${percent.abs().toStringAsFixed(1)}% so với tuần trước.';
        compareColor = AppColors.expense;
        compareIcon = Icons.trending_up_rounded;
      } else if (diff < 0) {
        compareMessage =
            'Chi tiêu giảm ${percent.abs().toStringAsFixed(1)}% so với tuần trước.';
        compareColor = AppColors.income;
        compareIcon = Icons.trending_down_rounded;
      } else {
        compareMessage = 'Chi tiêu tương đương tuần trước.';
        compareColor = AppColors.warning;
        compareIcon = Icons.remove_rounded;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tóm tắt tuần này',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(weekData.startDate)} - ${_formatDate(weekData.endDate)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMiniItem(
                  title: 'Thu',
                  value: CurrencyFormatter.formatVND(weekData.totalIncome),
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMiniItem(
                  title: 'Chi',
                  value: CurrencyFormatter.formatVND(weekData.totalExpense),
                  color: AppColors.expense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMiniItem(
                  title: 'Số dư',
                  value: CurrencyFormatter.formatVND(weekData.balance),
                  color: weekData.balance >= 0
                      ? AppColors.income
                      : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: compareColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(compareIcon, color: compareColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  compareMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSummaryCard(_SummaryData monthData) {
    final averageDailyExpense = monthData.totalExpense / DateTime.now().day;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tóm tắt tháng này',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tháng ${monthData.startDate.month}/${monthData.startDate.year}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMiniItem(
                  title: 'Thu',
                  value: CurrencyFormatter.formatVND(monthData.totalIncome),
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMiniItem(
                  title: 'Chi',
                  value: CurrencyFormatter.formatVND(monthData.totalExpense),
                  color: AppColors.expense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMiniItem(
                  title: 'Giao dịch',
                  value: '${monthData.transactionCount}',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Trung bình mỗi ngày bạn chi khoảng ${CurrencyFormatter.formatVND(averageDailyExpense)} trong tháng này.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMiniItem({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoryCard({
    required String title,
    required Map<String, double> categoryStats,
    required double totalExpense,
  }) {
    if (categoryStats.isEmpty || totalExpense <= 0) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chưa có dữ liệu chi tiêu để thống kê danh mục.',
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

    final topEntries = categoryStats.entries.take(3).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(topEntries.length, (index) {
              final entry = topEntries[index];
              final percent = entry.value / totalExpense;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == topEntries.length - 1 ? 0 : 16,
                ),
                child: _buildCategoryProgressItem(
                  category: entry.key,
                  amount: entry.value,
                  percent: percent,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressItem({
    required String category,
    required double amount,
    required double percent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              CurrencyFormatter.formatVND(amount),
              style: const TextStyle(
                color: AppColors.expense,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 1),
            minHeight: 9,
            backgroundColor: AppColors.surfaceSoft,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${(percent * 100).toStringAsFixed(1)}% tổng chi tiêu',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(List<String> insights) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gợi ý từ hệ thống',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(insights.length, (index) {
              final insight = insights[index];

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: AppColors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (index != insights.length - 1) const Divider(height: 28),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}

class _SummaryData {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;
  final int transactionCount;
  final Map<String, double> categoryStats;

  const _SummaryData({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    required this.categoryStats,
  });

  double get balance => totalIncome - totalExpense;
}
