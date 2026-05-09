import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../models/budget_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/transaction_service.dart';
import '../../services/user_service.dart';
import '../budget/budget_screen.dart';
import '../recurring/recurring_transaction_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../transaction/transaction_list_screen.dart';
import '../notification/notification_center_screen.dart';
import '../chatbot/chatbot_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: StreamBuilder<UserModel?>(
              stream: UserService().getUserProfile(user.uid),
              builder: (context, userSnapshot) {
                final userProfile = userSnapshot.data;

                final displayName = _getDisplayName(
                  email: user.email ?? 'Người dùng',
                  fullName: userProfile?.fullName ?? '',
                );

                final avatarUrl = userProfile?.avatarUrl ?? '';

                return StreamBuilder<List<TransactionModel>>(
                  stream: TransactionService().getTransactionsByUser(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final transactions = snapshot.data ?? [];
                    final recentTransactions = transactions.take(5).toList();

                    final totalIncome = transactions
                        .where((item) => item.type == 'income')
                        .fold<double>(0, (sum, item) => sum + item.amount);

                    final totalExpense = transactions
                        .where((item) => item.type == 'expense')
                        .fold<double>(0, (sum, item) => sum + item.amount);

                    final balance = totalIncome - totalExpense;

                    final currentMonthExpense = _getCurrentMonthExpense(
                      transactions,
                    );
                    final currentMonthKey = _getCurrentMonthKey();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(
                            context: context,
                            displayName: displayName,
                            avatarUrl: avatarUrl,
                            balance: balance,
                            totalIncome: totalIncome,
                            totalExpense: totalExpense,
                            transactionCount: transactions.length,
                          ),

                          const SizedBox(height: 22),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: StreamBuilder<BudgetModel?>(
                              stream: BudgetService().getBudgetByMonth(
                                userId: user.uid,
                                monthKey: currentMonthKey,
                              ),
                              builder: (context, budgetSnapshot) {
                                final budget = budgetSnapshot.data;

                                return _buildBudgetOverviewCard(
                                  context: context,
                                  budget: budget,
                                  totalExpense: currentMonthExpense,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 22),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildQuickActions(context),
                          ),

                          const SizedBox(height: 24),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildRecentTransactionsSection(
                              context: context,
                              transactions: transactions,
                              recentTransactions: recentTransactions,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Positioned(
            right: 20,
            bottom: 20,
            child: _buildChatbotFloatingButton(context),
          ),
        ],
      ),
    );
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  double _getCurrentMonthExpense(List<TransactionModel> transactions) {
    final now = DateTime.now();

    return transactions
        .where((item) {
          return item.type == 'expense' &&
              item.date.year == now.year &&
              item.date.month == now.month;
        })
        .fold<double>(0, (sum, item) => sum + item.amount);
  }

  Widget _buildHeader({
    required BuildContext context,
    required String displayName,
    required String avatarUrl,
    required double balance,
    required double totalIncome,
    required double totalExpense,
    required int transactionCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(displayName: displayName, avatarUrl: avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Số dư hiện tại',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  CurrencyFormatter.formatVND(balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderStatItem(
                        icon: Icons.trending_up_rounded,
                        title: 'Thu nhập',
                        value: CurrencyFormatter.formatVND(totalIncome),
                        iconColor: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildHeaderStatItem(
                        icon: Icons.trending_down_rounded,
                        title: 'Chi tiêu',
                        value: CurrencyFormatter.formatVND(totalExpense),
                        iconColor: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transactionCount == 0
                        ? 'Bạn chưa có giao dịch nào trong hệ thống'
                        : 'Bạn đang có $transactionCount giao dịch được ghi nhận',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Widget _buildBudgetOverviewCard({
    required BuildContext context,
    required BudgetModel? budget,
    required double totalExpense,
  }) {
    final totalAvailable = budget?.totalAvailable ?? 0;
    final remaining = totalAvailable - totalExpense;
    final progress = totalAvailable <= 0 ? 0.0 : totalExpense / totalAvailable;
    final progressValue = progress.clamp(0.0, 1.0);

    String title = 'Chưa thiết lập ngân sách';
    String message = 'Tạo ngân sách tháng để theo dõi chi tiêu hiệu quả hơn.';
    IconData statusIcon = Icons.info_rounded;
    Color statusColor = AppColors.primary;

    if (totalAvailable > 0) {
      if (progress >= 1) {
        title = 'Đã vượt ngân sách';
        message = 'Bạn đã chi vượt ngân sách tháng này.';
        statusIcon = Icons.warning_rounded;
        statusColor = AppColors.expense;
      } else if (progress >= 0.8) {
        title = 'Sắp vượt ngân sách';
        message = 'Bạn đã sử dụng hơn 80% ngân sách tháng.';
        statusIcon = Icons.notifications_active_rounded;
        statusColor = AppColors.warning;
      } else {
        title = 'Ngân sách đang an toàn';
        message = 'Chi tiêu hiện tại vẫn nằm trong mức kiểm soát.';
        statusIcon = Icons.check_circle_rounded;
        statusColor = AppColors.secondary;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetScreen()),
        );
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
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
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ngân sách tháng này',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (totalAvailable <= 0)
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildBudgetMiniInfo(
                      title: 'Khả dụng',
                      value: CurrencyFormatter.formatVND(totalAvailable),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBudgetMiniInfo(
                      title: 'Đã chi',
                      value: CurrencyFormatter.formatVND(totalExpense),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBudgetMiniInfo(
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
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceSoft,
                  color: statusColor,
                ),
              ),

              const SizedBox(height: 9),

              Text(
                'Đã dùng ${(progress * 100).toStringAsFixed(1)}% ngân sách. $message',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetMiniInfo({required String title, required String value}) {
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

  Widget _buildAvatar({
    required String displayName,
    required String avatarUrl,
  }) {
    final firstLetter = displayName.trim().isEmpty
        ? 'U'
        : displayName.trim().characters.first.toUpperCase();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: avatarUrl.trim().isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildAvatarLetter(firstLetter);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;

                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  );
                },
              )
            : _buildAvatarLetter(firstLetter),
      ),
    );
  }

  Widget _buildAvatarLetter(String firstLetter) {
    return Center(
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem({
    required IconData icon,
    required String title,
    required String value,
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thao tác nhanh',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_rounded,
                title: 'Thêm giao dịch',
                subtitle: 'Ghi lại khoản mới',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Ngân sách',
                subtitle: 'Theo dõi tháng này',
                color: AppColors.warning,
                backgroundColor: AppColors.warningSoft,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BudgetScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.repeat_rounded,
                title: 'Định kỳ',
                subtitle: 'Tự động khoản lặp lại',
                color: AppColors.info,
                backgroundColor: AppColors.infoSoft,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecurringTransactionScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildActionCard(
                icon: Icons.list_alt_rounded,
                title: 'Danh sách',
                subtitle: 'Tìm kiếm và lọc',
                color: AppColors.secondary,
                backgroundColor: AppColors.secondaryLight,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionListScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection({
    required BuildContext context,
    required List<TransactionModel> transactions,
    required List<TransactionModel> recentTransactions,
  }) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Giao dịch gần đây',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: transactions.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionListScreen(),
                        ),
                      );
                    },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          _buildEmptyTransactionCard(context)
        else
          AppCard(
            child: Column(
              children: List.generate(recentTransactions.length, (index) {
                final item = recentTransactions[index];
                final isLast = index == recentTransactions.length - 1;

                return Column(
                  children: [
                    _buildTransactionItem(context, item),
                    if (!isLast) const Divider(height: 28),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyTransactionCard(BuildContext context) {
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
                Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có giao dịch nào',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thêm giao dịch đầu tiên để bắt đầu theo dõi chi tiêu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 170,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel item) {
    final isIncome = item.type == 'income';
    final color = isIncome ? AppColors.income : AppColors.expense;
    final icon = isIncome
        ? Icons.payments_rounded
        : _getExpenseIcon(item.category);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: item),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.trim().isEmpty ? 'Không có tiêu đề' : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.category.trim().isEmpty ? 'Khác' : item.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      DateFormatter.formatDate(item.date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatVND(item.amount)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 11) {
      return 'Chào buổi sáng 👋';
    }

    if (hour < 14) {
      return 'Chào buổi trưa 👋';
    }

    if (hour < 18) {
      return 'Chào buổi chiều 👋';
    }

    return 'Chào buổi tối 👋';
  }

  String _getDisplayName({required String email, required String fullName}) {
    final nameFromProfile = fullName.trim();

    if (nameFromProfile.isNotEmpty) {
      return nameFromProfile;
    }

    if (email.trim().isEmpty) {
      return 'Người dùng';
    }

    final name = email.split('@').first.trim();

    if (name.isEmpty) {
      return 'Người dùng';
    }

    return name;
  }

  IconData _getExpenseIcon(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('ăn') || lower.contains('food')) {
      return Icons.restaurant_rounded;
    }

    if (lower.contains('xe') ||
        lower.contains('xăng') ||
        lower.contains('di chuyển')) {
      return Icons.directions_car_rounded;
    }

    if (lower.contains('mua') || lower.contains('shopping')) {
      return Icons.shopping_bag_rounded;
    }

    if (lower.contains('nhà') || lower.contains('thuê')) {
      return Icons.home_rounded;
    }

    if (lower.contains('học') || lower.contains('giáo dục')) {
      return Icons.school_rounded;
    }

    if (lower.contains('sức khỏe') || lower.contains('y tế')) {
      return Icons.local_hospital_rounded;
    }

    if (lower.contains('giải trí')) {
      return Icons.movie_rounded;
    }

    return Icons.wallet_rounded;
  }

  Widget _buildChatbotFloatingButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, color: Colors.white, size: 21),
            SizedBox(width: 8),
            Text(
              'Trợ lý',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
