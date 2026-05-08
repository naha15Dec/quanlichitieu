import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String userId;
  final String monthKey;
  final double monthlyBudget;
  final double extraIncome;
  final double carryOver;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.monthKey,
    required this.monthlyBudget,
    required this.extraIncome,
    required this.carryOver,
    required this.createdAt,
    this.updatedAt,
  });

  double get totalAvailable => monthlyBudget + extraIncome + carryOver;

  factory BudgetModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return BudgetModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      monthKey: data['monthKey'] ?? '',
      monthlyBudget: ((data['monthlyBudget'] ?? 0) as num).toDouble(),
      extraIncome: ((data['extraIncome'] ?? 0) as num).toDouble(),
      carryOver: ((data['carryOver'] ?? 0) as num).toDouble(),
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: data['updatedAt'] == null
          ? null
          : _timestampToDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'monthKey': monthKey,
      'monthlyBudget': monthlyBudget,
      'extraIncome': extraIncome,
      'carryOver': carryOver,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return map;
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? monthKey,
    double? monthlyBudget,
    double? extraIncome,
    double? carryOver,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      monthKey: monthKey ?? this.monthKey,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      extraIncome: extraIncome ?? this.extraIncome,
      carryOver: carryOver ?? this.carryOver,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }
}
