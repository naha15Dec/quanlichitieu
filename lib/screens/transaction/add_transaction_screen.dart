import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../core/utils/vnd_input_formatter.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionService _transactionService = TransactionService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String selectedType = 'expense';
  String selectedCategory = 'Ăn uống';
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

  Future<void> addTransaction() async {
    final user = AuthService().currentUser;

    if (user == null) {
      showMessage('Bạn chưa đăng nhập');
      return;
    }

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
      final transaction = TransactionModel(
        id: '',
        userId: user.uid,
        title: title,
        amount: amount,
        type: selectedType,
        category: selectedCategory,
        note: note,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _transactionService.addTransaction(transaction);

      if (!mounted) return;

      showMessage('Thêm giao dịch thành công');

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      showMessage('Thêm giao dịch thất bại');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm giao dịch')),
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
                text: 'Lưu giao dịch',
                isLoading: isLoading,
                onPressed: addTransaction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
