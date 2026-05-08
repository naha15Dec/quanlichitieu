import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransactionModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String type;
  final String category;
  final String note;
  final String frequency; // daily, weekly, monthly
  final DateTime startDate;
  final DateTime nextRunDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.frequency,
    required this.startDate,
    required this.nextRunDate,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory RecurringTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return RecurringTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      note: data['note'] ?? '',
      frequency: data['frequency'] ?? 'monthly',
      startDate: _timestampToDateTime(data['startDate']),
      nextRunDate: _timestampToDateTime(data['nextRunDate']),
      isActive: data['isActive'] ?? true,
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: data['updatedAt'] == null
          ? null
          : _timestampToDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'title': title.trim(),
      'amount': amount,
      'type': type.trim().isEmpty ? 'expense' : type.trim(),
      'category': category.trim(),
      'note': note.trim(),
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'nextRunDate': Timestamp.fromDate(nextRunDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return map;
  }

  RecurringTransactionModel copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    String? type,
    String? category,
    String? note,
    String? frequency,
    DateTime? startDate,
    DateTime? nextRunDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      isActive: isActive ?? this.isActive,
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
