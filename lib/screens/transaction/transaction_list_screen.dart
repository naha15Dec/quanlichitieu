import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import 'photo_journal_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  Stream<List<TransactionModel>>? _transactionsStream;
  String? _streamUserId;

  String _keyword = '';
  String _selectedType = 'all';
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _prepareTransactionStream(String userId) {
    if (_transactionsStream != null && _streamUserId == userId) return;

    _streamUserId = userId;
    _transactionsStream = TransactionService().getTransactionsByUser(userId);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      setState(() {
        _keyword = value;
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();

    _searchController.clear();

    setState(() {
      _keyword = '';
    });
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> transactions,
  ) {
    return transactions.where((item) {
      final keyword = _keyword.trim().toLowerCase();

      final matchMonth =
          item.date.year == _selectedMonth.year &&
          item.date.month == _selectedMonth.month;

      final matchKeyword =
          keyword.isEmpty ||
          item.title.toLowerCase().contains(keyword) ||
          item.category.toLowerCase().contains(keyword) ||
          item.note.toLowerCase().contains(keyword);

      final matchType = _selectedType == 'all' || item.type == _selectedType;

      return matchMonth && matchKeyword && matchType;
    }).toList();
  }

  Future<void> _pickMonth() async {
    final pickedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MonthPickerSheet(initialMonth: _selectedMonth);
      },
    );

    if (pickedMonth == null) return;

    setState(() {
      _selectedMonth = DateTime(pickedMonth.year, pickedMonth.month);
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  String _monthTitle(DateTime date) {
    return 'Tháng ${date.month}/${date.year}';
  }

  void _openPhotoJournal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhotoJournalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    _prepareTransactionStream(user.uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Giao dịch')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data ?? [];
          final filteredTransactions = _filterTransactions(transactions);

          final monthTransactions = transactions.where((item) {
            return item.date.year == _selectedMonth.year &&
                item.date.month == _selectedMonth.month;
          }).toList();

          final totalIncome = filteredTransactions
              .where((item) => item.type == 'income')
              .fold<double>(0, (sum, item) => sum + item.amount);

          final totalExpense = filteredTransactions
              .where((item) => item.type == 'expense')
              .fold<double>(0, (sum, item) => sum + item.amount);

          final Map<String, List<TransactionModel>> groupedTransactions = {};

          for (final transaction in filteredTransactions) {
            final dateKey = DateFormatter.formatDate(transaction.date);
            groupedTransactions.putIfAbsent(dateKey, () => []);
            groupedTransactions[dateKey]!.add(transaction);
          }

          final groupedKeys = groupedTransactions.keys.toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(
                        totalIncome: totalIncome,
                        totalExpense: totalExpense,
                        count: filteredTransactions.length,
                        totalMonthCount: monthTransactions.length,
                      ),
                      const SizedBox(height: 18),
                      _buildMonthSelector(),
                      const SizedBox(height: 14),
                      _buildPhotoJournalEntry(),
                      const SizedBox(height: 14),
                      _buildSearchBox(),
                      const SizedBox(height: 14),
                      _buildTypeFilters(),
                    ],
                  ),
                ),
              ),
              if (transactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Chưa có giao dịch nào',
                    message:
                        'Hãy thêm giao dịch đầu tiên để bắt đầu theo dõi thu chi cá nhân.',
                  ),
                )
              else if (monthTransactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    icon: Icons.calendar_month_rounded,
                    title: 'Không có giao dịch trong tháng này',
                    message:
                        'Hãy đổi sang tháng khác hoặc thêm giao dịch mới cho ${_monthTitle(_selectedMonth)}.',
                  ),
                )
              else if (filteredTransactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không tìm thấy giao dịch',
                    message:
                        'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc giao dịch.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverList.builder(
                    itemCount: groupedKeys.length,
                    itemBuilder: (context, index) {
                      final dateKey = groupedKeys[index];
                      final items = groupedTransactions[dateKey]!;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildTransactionGroup(
                          context: context,
                          dateKey: dateKey,
                          items: items,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required double totalIncome,
    required double totalExpense,
    required int count,
    required int totalMonthCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
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
            _monthTitle(_selectedMonth),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count giao dịch',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == totalMonthCount
                ? 'Tổng giao dịch trong tháng'
                : 'Đang lọc từ $totalMonthCount giao dịch trong tháng',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  title: 'Thu nhập',
                  value: CurrencyFormatter.formatVND(totalIncome),
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
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

  Widget _buildSummaryItem({
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

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _goToPreviousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              onTap: _pickMonth,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _monthTitle(_selectedMonth),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _goToNextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoJournalEntry() {
    return InkWell(
      onTap: _openPhotoJournal,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhật ký ảnh',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Xem lại các giao dịch đã lưu bằng hình ảnh.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem tất cả',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Tìm trong ${_monthTitle(_selectedMonth).toLowerCase()}...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        suffixIcon: _keyword.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget _buildTypeFilters() {
    return Row(
      children: [
        _buildFilterChip(
          label: 'Tất cả',
          value: 'all',
          icon: Icons.grid_view_rounded,
        ),
        const SizedBox(width: 10),
        _buildFilterChip(
          label: 'Thu nhập',
          value: 'income',
          icon: Icons.arrow_downward_rounded,
        ),
        const SizedBox(width: 10),
        _buildFilterChip(
          label: 'Chi tiêu',
          value: 'expense',
          icon: Icons.arrow_upward_rounded,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedType == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = value;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionGroup({
    required BuildContext context,
    required String dateKey,
    required List<TransactionModel> items,
  }) {
    final dayTotalExpense = items
        .where((item) => item.type == 'expense')
        .fold<double>(0, (sum, item) => sum + item.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (dayTotalExpense > 0)
              Text(
                '- ${CurrencyFormatter.formatVND(dayTotalExpense)}',
                style: const TextStyle(
                  color: AppColors.expense,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  _buildTransactionItem(
                    item: item,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TransactionDetailScreen(transaction: item),
                        ),
                      );
                    },
                  ),
                  if (!isLast) const Divider(height: 28),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem({
    required TransactionModel item,
    required VoidCallback onTap,
  }) {
    final isIncome = item.type == 'income';
    final color = isIncome ? AppColors.income : AppColors.expense;
    final icon = isIncome
        ? Icons.payments_rounded
        : _getExpenseIcon(item.category);

    final hasPhoto = item.receiptImages.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  item.receiptImages.first,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildIconBox(color: color, icon: icon);
                  },
                ),
              )
            else
              _buildIconBox(color: color, icon: icon),
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
                      if (hasPhoto) ...[
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Icon(
                          Icons.image_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                      ],
                      if (item.note.trim().isNotEmpty) ...[
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Icon(
                          Icons.notes_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                      ],
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
      ),
    );
  }

  Widget _buildIconBox({required Color color, required IconData icon}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      child: Center(
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
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
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initialMonth;

  const _MonthPickerSheet({required this.initialMonth});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedYear--;
                    });
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$selectedYear',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: selectedYear >= now.year
                      ? null
                      : () {
                          setState(() {
                            selectedYear++;
                          });
                        },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected =
                    selectedYear == widget.initialMonth.year &&
                    month == widget.initialMonth.month;

                final isFutureMonth =
                    selectedYear > now.year ||
                    (selectedYear == now.year && month > now.month);

                return InkWell(
                  onTap: isFutureMonth
                      ? null
                      : () {
                          Navigator.pop(context, DateTime(selectedYear, month));
                        },
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isFutureMonth
                          ? AppColors.surfaceSoft
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Tháng $month',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isFutureMonth
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
