import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget_model.dart';

class BudgetService {
  final CollectionReference<Map<String, dynamic>> _budgets = FirebaseFirestore
      .instance
      .collection('budgets');

  String buildBudgetId({required String userId, required String monthKey}) {
    return '${userId}_$monthKey';
  }

  Stream<BudgetModel?> getBudgetByMonth({
    required String userId,
    required String monthKey,
  }) {
    final budgetId = buildBudgetId(userId: userId, monthKey: monthKey);

    return _budgets.doc(budgetId).snapshots().map((doc) {
      final data = doc.data();

      if (!doc.exists || data == null) {
        return null;
      }

      return BudgetModel.fromFirestore(doc);
    });
  }

  Future<void> saveBudget(BudgetModel budget) async {
    final budgetId = buildBudgetId(
      userId: budget.userId,
      monthKey: budget.monthKey,
    );

    final docRef = _budgets.doc(budgetId);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.update({
        'monthlyBudget': budget.monthlyBudget,
        'extraIncome': budget.extraIncome,
        'carryOver': budget.carryOver,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      await docRef.set(
        budget
            .copyWith(createdAt: DateTime.now(), updatedAt: DateTime.now())
            .toMap(),
      );
    }
  }
}
