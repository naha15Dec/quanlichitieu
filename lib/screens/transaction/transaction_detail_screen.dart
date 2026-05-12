import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_card.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import 'edit_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool isDeleting = false;

  Future<void> deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa giao dịch'),
          content: const Text(
            'Bạn có chắc muốn xóa giao dịch này không? Hành động này không thể hoàn tác.',
          ),
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

    setState(() {
      isDeleting = true;
    });

    try {
      await TransactionService().deleteTransaction(widget.transaction.id);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa giao dịch')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Xóa giao dịch thất bại')));
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  void openImagePreview(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReceiptImagePreviewScreen(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final isIncome = transaction.type == 'income';
    final color = isIncome ? AppColors.income : AppColors.expense;
    final softColor = isIncome ? AppColors.incomeSoft : AppColors.expenseSoft;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        child: Column(
          children: [
            _buildHeaderCard(
              transaction: transaction,
              isIncome: isIncome,
              color: color,
              softColor: softColor,
            ),
            const SizedBox(height: 18),
            _buildInfoCard(transaction, isIncome),
            const SizedBox(height: 18),
            _buildReceiptImagesCard(transaction),
            const SizedBox(height: 18),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required TransactionModel transaction,
    required bool isIncome,
    required Color color,
    required Color softColor,
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
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              isIncome
                  ? Icons.payments_rounded
                  : _getExpenseIcon(transaction.category),
              color: color,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isIncome ? 'Thu nhập' : 'Chi tiêu',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatVND(transaction.amount)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              transaction.category.trim().isEmpty
                  ? 'Danh mục: Khác'
                  : 'Danh mục: ${transaction.category}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(TransactionModel transaction, bool isIncome) {
    return AppCard(
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
          const SizedBox(height: 18),
          _buildInfoTile(
            icon: Icons.title_rounded,
            label: 'Tên giao dịch',
            value: transaction.title.trim().isEmpty
                ? 'Không có tiêu đề'
                : transaction.title,
          ),
          _buildInfoTile(
            icon: isIncome
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            label: 'Loại giao dịch',
            value: isIncome ? 'Thu nhập' : 'Chi tiêu',
          ),
          _buildInfoTile(
            icon: Icons.category_rounded,
            label: 'Danh mục',
            value: transaction.category.trim().isEmpty
                ? 'Khác'
                : transaction.category,
          ),
          _buildInfoTile(
            icon: Icons.calendar_month_rounded,
            label: 'Ngày giao dịch',
            value: DateFormatter.formatDate(transaction.date),
          ),
          _buildInfoTile(
            icon: Icons.notes_rounded,
            label: 'Ghi chú',
            value: transaction.note.trim().isEmpty
                ? 'Không có ghi chú'
                : transaction.note,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptImagesCard(TransactionModel transaction) {
    final images = transaction.receiptImages;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Ảnh giao dịch',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (images.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Giao dịch này chưa có ảnh giao dịch.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final imageUrl = images[index];

                  return InkWell(
                    onTap: () => openImagePreview(imageUrl),
                    borderRadius: BorderRadius.circular(18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        imageUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          return Container(
                            width: 110,
                            height: 110,
                            color: AppColors.surfaceSoft,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 110,
                            height: 110,
                            color: AppColors.expenseSoft,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.expense,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 28),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: isDeleting
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditTransactionScreen(
                          transaction: widget.transaction,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Sửa giao dịch'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: isDeleting ? null : deleteTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            icon: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_rounded),
            label: Text(isDeleting ? 'Đang xóa...' : 'Xóa giao dịch'),
          ),
        ),
      ],
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

class _ReceiptImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  const _ReceiptImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: const Text(
          'Ảnh giao dịch',
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
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Không thể tải ảnh giao dịch',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
