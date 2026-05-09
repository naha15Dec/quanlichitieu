import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../models/budget_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/chatbot_service.dart';
import '../../services/recurring_transaction_service.dart';
import '../../services/transaction_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ChatbotService chatbotService = ChatbotService();

  final List<ChatMessageModel> messages = [
    ChatMessageModel(
      text:
          'Chào bạn 👋 Mình là trợ lý tài chính của Smart Expense. Bạn có thể hỏi mình về chi tiêu, thu nhập, ngân sách, danh mục chi nhiều nhất hoặc giao dịch định kỳ.',
      isUser: false,
      createdAt: DateTime.now(),
    ),
  ];

  final List<String> suggestions = const [
    'Tháng này tôi chi bao nhiêu?',
    'Tôi còn bao nhiêu ngân sách?',
    'Danh mục nào chi nhiều nhất?',
    'Tuần này tôi chi bao nhiêu?',
    'Có giao dịch định kỳ nào đến hạn không?',
    'Bạn làm được gì?',
  ];

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void sendMessage({
    required String text,
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
    required List<RecurringTransactionModel> recurringItems,
  }) {
    final message = text.trim();

    if (message.isEmpty) return;

    setState(() {
      messages.add(
        ChatMessageModel(
          text: message,
          isUser: true,
          createdAt: DateTime.now(),
        ),
      );
    });

    messageController.clear();

    final response = chatbotService.generateResponse(
      message: message,
      transactions: transactions,
      budget: budget,
      recurringItems: recurringItems,
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      setState(() {
        messages.add(
          ChatMessageModel(
            text: response,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        );
      });

      scrollToBottom();
    });

    scrollToBottom();
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trợ lý tài chính')),
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
              monthKey: getCurrentMonthKey(),
            ),
            builder: (context, budgetSnapshot) {
              final budget = budgetSnapshot.data;

              return StreamBuilder<List<RecurringTransactionModel>>(
                stream: RecurringTransactionService()
                    .getRecurringTransactionsByUser(user.uid),
                builder: (context, recurringSnapshot) {
                  final recurringItems = recurringSnapshot.data ?? [];

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 18),
                            _buildSuggestionSection(
                              transactions: transactions,
                              budget: budget,
                              recurringItems: recurringItems,
                            ),
                            const SizedBox(height: 18),
                            ...messages.map(_buildMessageBubble),
                          ],
                        ),
                      ),
                      _buildInputBar(
                        transactions: transactions,
                        budget: budget,
                        recurringItems: recurringItems,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.smart_toy_rounded, color: Colors.white, size: 42),
          SizedBox(height: 18),
          Text(
            'Trợ lý tài chính',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Hỏi nhanh về thu chi, ngân sách, danh mục chi nhiều nhất và giao dịch định kỳ.',
            style: TextStyle(
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

  Widget _buildSuggestionSection({
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
    required List<RecurringTransactionModel> recurringItems,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gợi ý câu hỏi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions.map((question) {
              return InkWell(
                onTap: () {
                  sendMessage(
                    text: question,
                    transactions: transactions,
                    budget: budget,
                    recurringItems: recurringItems,
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
          boxShadow: isUser
              ? []
              : const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar({
    required List<TransactionModel> transactions,
    required BudgetModel? budget,
    required List<RecurringTransactionModel> recurringItems,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) {
                  sendMessage(
                    text: value,
                    transactions: transactions,
                    budget: budget,
                    recurringItems: recurringItems,
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Hỏi về tài chính của bạn...',
                  prefixIcon: const Icon(Icons.chat_rounded),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                sendMessage(
                  text: messageController.text,
                  transactions: transactions,
                  budget: budget,
                  recurringItems: recurringItems,
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
