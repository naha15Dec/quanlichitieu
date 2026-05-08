import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';

class TransactionService {
  final CollectionReference<Map<String, dynamic>> _transactions =
      FirebaseFirestore.instance.collection('transactions');

  Future<void> addTransaction(TransactionModel transaction) async {
    final newTransaction = transaction.copyWith(
      createdAt: transaction.createdAt,
    );

    await _transactions.add(newTransaction.toMap());
  }

  Stream<List<TransactionModel>> getTransactionsByUser(String userId) {
    return _transactions.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      transactions.sort((a, b) => b.date.compareTo(a.date));

      return transactions;
    });
  }

  Stream<List<TransactionModel>> getRecentTransactionsByUser(
    String userId, {
    int limit = 5,
  }) {
    return _transactions.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      transactions.sort((a, b) => b.date.compareTo(a.date));

      return transactions.take(limit).toList();
    });
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final updatedTransaction = transaction.copyWith(updatedAt: DateTime.now());

    await _transactions.doc(transaction.id).update(updatedTransaction.toMap());
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactions.doc(transactionId).delete();
  }
}
