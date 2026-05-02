import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_service.dart';
import '../../core/utils/vnd_input_formatter.dart';
import 'package:intl/intl.dart';

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

  bool isLoading = false;

  final List<String> categories = [
    'Ăn uống',
    'Mua sắm',
    'Di chuyển',
    'Học tập',
    'Giải trí',
    'Lương',
    'Khác',
  ];

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
    selectedCategory = widget.transaction.category;
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
      final updatedTransaction = TransactionModel(
        id: widget.transaction.id,
        userId: widget.transaction.userId,
        title: title,
        amount: amount,
        type: selectedType,
        category: selectedCategory,
        note: note,
        date: widget.transaction.date,
        createdAt: widget.transaction.createdAt,
      );

      await _transactionService.updateTransaction(updatedTransaction);

      if (!mounted) return;

      showMessage('Cập nhật giao dịch thành công');

      await Future.delayed(const Duration(milliseconds: 800));

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
    if (!categories.contains(selectedCategory)) {
      selectedCategory = 'Khác';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sửa giao dịch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Loại giao dịch',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Chi tiêu'),
                      selected: selectedType == 'expense',
                      onSelected: (_) {
                        setState(() {
                          selectedType = 'expense';
                        });
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Thu nhập'),
                      selected: selectedType == 'income',
                      onSelected: (_) {
                        setState(() {
                          selectedType = 'income';
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              AppTextField(
                controller: titleController,
                hintText: 'Tên giao dịch',
                prefixIcon: Icons.edit_outlined,
              ),

              const SizedBox(height: 16),

              AppTextField(
                controller: amountController,
                hintText: 'Số tiền',
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [VndInputFormatter()],
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                  hintText: 'Danh mục',
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              AppTextField(
                controller: noteController,
                hintText: 'Ghi chú',
                prefixIcon: Icons.note_alt_outlined,
              ),

              const SizedBox(height: 24),

              AppButton(
                text: 'Lưu thay đổi',
                isLoading: isLoading,
                onPressed: updateTransaction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
