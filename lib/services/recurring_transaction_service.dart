import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class RecurringTransactionService {
  final CollectionReference<Map<String, dynamic>> _recurringTransactions =
      FirebaseFirestore.instance.collection('recurring_transactions');

  Future<void> addRecurringTransaction(
    RecurringTransactionModel recurring,
  ) async {
    await _recurringTransactions.add(recurring.toMap());
  }

  Stream<List<RecurringTransactionModel>> getRecurringTransactionsByUser(
    String userId,
  ) {
    return _recurringTransactions
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => RecurringTransactionModel.fromFirestore(doc))
              .toList();

          items.sort((a, b) => a.nextRunDate.compareTo(b.nextRunDate));

          return items;
        });
  }

  Future<void> updateRecurringTransaction(
    RecurringTransactionModel recurring,
  ) async {
    final updated = recurring.copyWith(updatedAt: DateTime.now());

    await _recurringTransactions.doc(recurring.id).update(updated.toMap());
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _recurringTransactions.doc(id).delete();
  }

  Future<int> generateDueTransactions({
    required String userId,
    required List<RecurringTransactionModel> recurringItems,
  }) async {
    int createdCount = 0;
    final today = _dateOnly(DateTime.now());

    for (final item in recurringItems) {
      if (!item.isActive) continue;
      if (item.userId != userId) continue;

      DateTime nextRun = _dateOnly(item.nextRunDate);

      while (!nextRun.isAfter(today)) {
        final transaction = TransactionModel(
          id: '',
          userId: item.userId,
          title: item.title,
          amount: item.amount,
          type: item.type,
          category: item.category,
          note: item.note.trim().isEmpty
              ? 'Tự động tạo từ giao dịch định kỳ'
              : item.note,
          date: nextRun,
          createdAt: DateTime.now(),
        );

        await TransactionService().addTransaction(transaction);

        createdCount++;
        nextRun = _getNextRunDate(nextRun, item.frequency);
      }

      await _recurringTransactions.doc(item.id).update({
        'nextRunDate': Timestamp.fromDate(nextRun),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    return createdCount;
  }

  DateTime getInitialNextRunDate({
    required DateTime startDate,
    required String frequency,
  }) {
    DateTime nextRun = _dateOnly(startDate);
    final today = _dateOnly(DateTime.now());

    while (nextRun.isBefore(today)) {
      nextRun = _getNextRunDate(nextRun, frequency);
    }

    return nextRun;
  }

  DateTime _getNextRunDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));

      case 'weekly':
        return current.add(const Duration(days: 7));

      case 'monthly':
      default:
        return DateTime(current.year, current.month + 1, current.day);
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
