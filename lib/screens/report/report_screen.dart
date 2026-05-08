import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../models/budget_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/transaction_service.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

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
      appBar: AppBar(title: const Text('Báo cáo')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: TransactionService().getTransactionsByUser(user.uid),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = transactionSnapshot.data ?? [];

          final currentMonthTransactions = transactions.where((item) {
            return item.date.year == now.year && item.date.month == now.month;
          }).toList();

          final lastMonthDate = DateTime(now.year, now.month - 1);

          final lastMonthTransactions = transactions.where((item) {
            return item.date.year == lastMonthDate.year &&
                item.date.month == lastMonthDate.month;
          }).toList();

          final totalIncome = _sumByType(currentMonthTransactions, 'income');
          final totalExpense = _sumByType(currentMonthTransactions, 'expense');
          final balance = totalIncome - totalExpense;

          final lastMonthExpense = _sumByType(lastMonthTransactions, 'expense');

          final categoryStats = _calculateCategoryStats(
            currentMonthTransactions,
          );

          final monthlyStats = _calculateMonthlyExpenseStats(transactions);

          return StreamBuilder<BudgetModel?>(
            stream: BudgetService().getBudgetByMonth(
              userId: user.uid,
              monthKey: currentMonthKey,
            ),
            builder: (context, budgetSnapshot) {
              final budget = budgetSnapshot.data;

              final insights = _buildSmartInsights(
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                lastMonthExpense: lastMonthExpense,
                categoryStats: categoryStats,
                budget: budget,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(
                      totalIncome: totalIncome,
                      totalExpense: totalExpense,
                      balance: balance,
                      transactionCount: currentMonthTransactions.length,
                    ),
                    const SizedBox(height: 20),
                    _buildBudgetReportCard(
                      budget: budget,
                      totalExpense: totalExpense,
                    ),
                    const SizedBox(height: 20),
                    _buildPieChartSection(
                      categoryStats: categoryStats,
                      totalExpense: totalExpense,
                    ),
                    const SizedBox(height: 20),
                    _buildBarChartSection(monthlyStats),
                    const SizedBox(height: 20),
                    _buildComparisonCard(
                      totalExpense: totalExpense,
                      lastMonthExpense: lastMonthExpense,
                    ),
                    const SizedBox(height: 20),
                    _buildCategorySection(categoryStats, totalExpense),
                    const SizedBox(height: 20),
                    _buildInsightSection(insights),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static double _sumByType(List<TransactionModel> transactions, String type) {
    return transactions
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  static Map<String, double> _calculateCategoryStats(
    List<TransactionModel> transactions,
  ) {
    final Map<String, double> result = {};

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

  static List<_MonthlyExpenseData> _calculateMonthlyExpenseStats(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final result = <_MonthlyExpenseData>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final total = transactions
          .where((item) {
            return item.type == 'expense' &&
                item.date.year == month.year &&
                item.date.month == month.month;
          })
          .fold<double>(0, (sum, item) => sum + item.amount);

      result.add(
        _MonthlyExpenseData(
          month: month.month,
          year: month.year,
          amount: total,
        ),
      );
    }

    return result;
  }

  static List<String> _buildSmartInsights({
    required double totalIncome,
    required double totalExpense,
    required double lastMonthExpense,
    required Map<String, double> categoryStats,
    required BudgetModel? budget,
  }) {
    final insights = <String>[];

    if (totalExpense <= 0) {
      insights.add(
        'Tháng này chưa có dữ liệu chi tiêu. Hãy thêm giao dịch để hệ thống phân tích.',
      );
      return insights;
    }

    if (budget != null && budget.totalAvailable > 0) {
      final usedRatio = totalExpense / budget.totalAvailable;
      final remaining = budget.totalAvailable - totalExpense;

      if (usedRatio >= 1) {
        insights.add(
          'Bạn đã vượt ngân sách tháng này ${CurrencyFormatter.formatVND(remaining.abs())}. Nên kiểm tra lại các khoản chi lớn.',
        );
      } else if (usedRatio >= 0.8) {
        insights.add(
          'Bạn đã sử dụng hơn 80% ngân sách tháng. Hãy cân nhắc các khoản chi tiếp theo.',
        );
      } else {
        insights.add(
          'Bạn đã sử dụng ${(usedRatio * 100).toStringAsFixed(1)}% ngân sách tháng và còn lại ${CurrencyFormatter.formatVND(remaining)}.',
        );
      }
    } else {
      insights.add(
        'Bạn chưa thiết lập ngân sách tháng. Hãy tạo ngân sách để hệ thống theo dõi mức chi tiêu hiệu quả hơn.',
      );
    }

    if (totalIncome > 0) {
      final expenseRatio = totalExpense / totalIncome;

      if (expenseRatio >= 1) {
        insights.add(
          'Chi tiêu tháng này đã bằng hoặc vượt thu nhập. Bạn nên kiểm soát lại các khoản chi lớn.',
        );
      } else if (expenseRatio >= 0.8) {
        insights.add(
          'Bạn đã dùng hơn 80% thu nhập trong tháng này. Nên hạn chế các khoản chi không cần thiết.',
        );
      } else {
        insights.add('Tỷ lệ chi tiêu so với thu nhập đang ở mức khá ổn.');
      }
    }

    if (lastMonthExpense > 0) {
      final diff = totalExpense - lastMonthExpense;
      final percent = (diff / lastMonthExpense * 100).abs();

      if (diff > 0) {
        insights.add(
          'Chi tiêu tháng này cao hơn tháng trước khoảng ${percent.toStringAsFixed(1)}%.',
        );
      } else if (diff < 0) {
        insights.add(
          'Chi tiêu tháng này thấp hơn tháng trước khoảng ${percent.toStringAsFixed(1)}%.',
        );
      } else {
        insights.add('Chi tiêu tháng này gần như tương đương tháng trước.');
      }
    }

    if (categoryStats.isNotEmpty) {
      final top = categoryStats.entries.first;
      final ratio = totalExpense == 0 ? 0 : top.value / totalExpense * 100;

      insights.add(
        'Danh mục "${top.key}" đang chiếm ${ratio.toStringAsFixed(1)}% tổng chi tiêu tháng này.',
      );
    }

    return insights;
  }

  Widget _buildHeaderCard({
    required double totalIncome,
    required double totalExpense,
    required double balance,
    required int transactionCount,
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
            'Báo cáo tháng này',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatVND(balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$transactionCount giao dịch trong tháng',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Thu nhập',
                  value: CurrencyFormatter.formatVND(totalIncome),
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Chi tiêu',
                  value: CurrencyFormatter.formatVND(totalExpense),
                  icon: Icons.trending_down_rounded,
                  iconColor: AppColors.warning,
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

  Widget _buildBudgetReportCard({
    required BudgetModel? budget,
    required double totalExpense,
  }) {
    final totalAvailable = budget?.totalAvailable ?? 0;
    final remaining = totalAvailable - totalExpense;
    final progress = totalAvailable <= 0 ? 0.0 : totalExpense / totalAvailable;
    final progressValue = progress.clamp(0.0, 1.0);

    String title = 'Chưa thiết lập ngân sách';
    String message =
        'Bạn có thể tạo ngân sách tháng để hệ thống phân tích chi tiêu chính xác hơn.';
    IconData icon = Icons.info_rounded;
    Color color = AppColors.primary;

    if (totalAvailable > 0) {
      if (progress >= 1) {
        title = 'Đã vượt ngân sách';
        message =
            'Bạn đã vượt ngân sách ${CurrencyFormatter.formatVND(remaining.abs())}.';
        icon = Icons.warning_rounded;
        color = AppColors.expense;
      } else if (progress >= 0.8) {
        title = 'Sắp vượt ngân sách';
        message =
            'Bạn đã sử dụng ${(progress * 100).toStringAsFixed(1)}% ngân sách tháng này.';
        icon = Icons.notifications_active_rounded;
        color = AppColors.warning;
      } else {
        title = 'Ngân sách đang an toàn';
        message =
            'Bạn còn lại ${CurrencyFormatter.formatVND(remaining)} trong ngân sách tháng.';
        icon = Icons.check_circle_rounded;
        color = AppColors.secondary;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const Text(
                      'Theo dõi ngân sách',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (totalAvailable > 0) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildBudgetMiniItem(
                    title: 'Khả dụng',
                    value: CurrencyFormatter.formatVND(totalAvailable),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBudgetMiniItem(
                    title: 'Đã chi',
                    value: CurrencyFormatter.formatVND(totalExpense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBudgetMiniItem(
                    title: 'Còn lại',
                    value: CurrencyFormatter.formatVND(remaining),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 9,
                backgroundColor: AppColors.surfaceSoft,
                color: color,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Đã dùng ${(progress * 100).toStringAsFixed(1)}% ngân sách',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetMiniItem({required String title, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartSection({
    required Map<String, double> categoryStats,
    required double totalExpense,
  }) {
    final colors = [
      AppColors.primary,
      AppColors.expense,
      AppColors.warning,
      AppColors.income,
      AppColors.info,
      AppColors.secondary,
    ];

    final entries = categoryStats.entries.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Biểu đồ danh mục',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: categoryStats.isEmpty
              ? _buildEmptyChartState(
                  icon: Icons.pie_chart_rounded,
                  title: 'Chưa có dữ liệu biểu đồ',
                  message:
                      'Khi có giao dịch chi tiêu, biểu đồ danh mục sẽ hiển thị tại đây.',
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 42,
                          sectionsSpace: 3,
                          sections: List.generate(entries.length, (index) {
                            final entry = entries[index];
                            final percent = totalExpense == 0
                                ? 0.0
                                : entry.value / totalExpense * 100;

                            return PieChartSectionData(
                              value: entry.value,
                              title: '${percent.toStringAsFixed(0)}%',
                              color: colors[index % colors.length],
                              radius: 72,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Column(
                      children: List.generate(entries.length, (index) {
                        final entry = entries[index];
                        final percent = totalExpense == 0
                            ? 0.0
                            : entry.value / totalExpense * 100;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildChartLegendItem(
                            color: colors[index % colors.length],
                            label: entry.key,
                            value:
                                '${CurrencyFormatter.formatVND(entry.value)} • ${percent.toStringAsFixed(1)}%',
                          ),
                        );
                      }),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBarChartSection(List<_MonthlyExpenseData> monthlyStats) {
    final maxAmount = monthlyStats.fold<double>(
      0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chi tiêu 6 tháng gần nhất',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: maxAmount <= 0
              ? _buildEmptyChartState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Chưa có dữ liệu theo tháng',
                  message:
                      'Khi có giao dịch chi tiêu, biểu đồ cột 6 tháng gần nhất sẽ hiển thị tại đây.',
                )
              : SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      maxY: maxAmount * 1.25,
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: AppColors.border,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: maxAmount <= 0 ? 1 : maxAmount / 3,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) {
                                return const SizedBox.shrink();
                              }

                              return Text(
                                _shortMoney(value),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();

                              if (index < 0 || index >= monthlyStats.length) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'T${monthlyStats[index].month}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(monthlyStats.length, (index) {
                        final item = monthlyStats[index];

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: item.amount,
                              width: 18,
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.primary,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChartLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChartState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required double totalExpense,
    required double lastMonthExpense,
  }) {
    double percent = 0;
    String message = 'Chưa có dữ liệu tháng trước để so sánh.';
    IconData icon = Icons.info_rounded;
    Color color = AppColors.primary;

    if (lastMonthExpense > 0) {
      final diff = totalExpense - lastMonthExpense;
      percent = diff / lastMonthExpense * 100;

      if (diff > 0) {
        message =
            'Chi tiêu tăng ${percent.abs().toStringAsFixed(1)}% so với tháng trước.';
        icon = Icons.arrow_upward_rounded;
        color = AppColors.expense;
      } else if (diff < 0) {
        message =
            'Chi tiêu giảm ${percent.abs().toStringAsFixed(1)}% so với tháng trước.';
        icon = Icons.arrow_downward_rounded;
        color = AppColors.income;
      } else {
        message = 'Chi tiêu không thay đổi so với tháng trước.';
        icon = Icons.remove_rounded;
        color = AppColors.warning;
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
                const Text(
                  'So sánh tháng trước',
                  style: TextStyle(
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

  Widget _buildCategorySection(
    Map<String, double> categoryStats,
    double totalExpense,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chi tiêu theo danh mục',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        if (categoryStats.isEmpty)
          AppCard(
            child: _buildEmptyChartState(
              icon: Icons.pie_chart_rounded,
              title: 'Chưa có dữ liệu chi tiêu',
              message:
                  'Khi có giao dịch chi tiêu, hệ thống sẽ thống kê theo danh mục tại đây.',
            ),
          )
        else
          AppCard(
            child: Column(
              children: categoryStats.entries.take(6).map((entry) {
                final percent = totalExpense == 0
                    ? 0.0
                    : entry.value / totalExpense;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCategoryItem(
                    category: entry.key,
                    amount: entry.value,
                    percent: percent,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryItem({
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
                fontSize: 14,
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

  Widget _buildInsightSection(List<String> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Insights',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
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
        ),
      ],
    );
  }

  static String _shortMoney(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }

    return value.toStringAsFixed(0);
  }
}

class _MonthlyExpenseData {
  final int month;
  final int year;
  final double amount;

  const _MonthlyExpenseData({
    required this.month,
    required this.year,
    required this.amount,
  });
}
