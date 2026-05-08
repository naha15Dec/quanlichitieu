import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';

class CategoryService {
  final CollectionReference<Map<String, dynamic>> _categories =
      FirebaseFirestore.instance.collection('categories');

  final List<Map<String, String>> defaultExpenseCategories = const [
    {'name': 'Ăn uống', 'type': 'expense', 'iconName': 'restaurant'},
    {'name': 'Mua sắm', 'type': 'expense', 'iconName': 'shopping'},
    {'name': 'Di chuyển', 'type': 'expense', 'iconName': 'transport'},
    {'name': 'Học tập', 'type': 'expense', 'iconName': 'school'},
    {'name': 'Giải trí', 'type': 'expense', 'iconName': 'entertainment'},
    {'name': 'Sức khỏe', 'type': 'expense', 'iconName': 'health'},
    {'name': 'Nhà cửa', 'type': 'expense', 'iconName': 'home'},
    {'name': 'Khác', 'type': 'expense', 'iconName': 'category'},
  ];

  final List<Map<String, String>> defaultIncomeCategories = const [
    {'name': 'Lương', 'type': 'income', 'iconName': 'salary'},
    {'name': 'Thưởng', 'type': 'income', 'iconName': 'bonus'},
    {'name': 'Làm thêm', 'type': 'income', 'iconName': 'work'},
    {'name': 'Đầu tư', 'type': 'income', 'iconName': 'investment'},
    {'name': 'Quà tặng', 'type': 'income', 'iconName': 'gift'},
    {'name': 'Khác', 'type': 'income', 'iconName': 'category'},
  ];

  Future<void> createDefaultCategoriesIfNeeded(String userId) async {
    final existing = await _categories
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    final allDefaults = [
      ...defaultExpenseCategories,
      ...defaultIncomeCategories,
    ];

    for (final item in allDefaults) {
      final docRef = _categories.doc();

      final category = CategoryModel(
        id: '',
        userId: userId,
        name: item['name'] ?? '',
        type: item['type'] ?? 'expense',
        iconName: item['iconName'] ?? 'category',
        createdAt: now,
        updatedAt: now,
      );

      batch.set(docRef, category.toMap());
    }

    await batch.commit();
  }

  Stream<List<CategoryModel>> getCategoriesByUser(String userId) {
    return _categories.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final categories = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();

      categories.sort((a, b) {
        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) return typeCompare;
        return a.name.compareTo(b.name);
      });

      return categories;
    });
  }

  Stream<List<CategoryModel>> getCategoriesByType({
    required String userId,
    required String type,
  }) {
    return _categories
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList();

          categories.sort((a, b) => a.name.compareTo(b.name));

          return categories;
        });
  }

  Future<bool> categoryNameExists({
    required String userId,
    required String name,
    required String type,
    String? exceptCategoryId,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    final snapshot = await _categories
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .get();

    for (final doc in snapshot.docs) {
      if (exceptCategoryId != null && doc.id == exceptCategoryId) {
        continue;
      }

      final data = doc.data();
      final existingName = (data['name'] ?? '').toString().trim().toLowerCase();

      if (existingName == normalizedName) {
        return true;
      }
    }

    return false;
  }

  Future<void> addCategory(CategoryModel category) async {
    final exists = await categoryNameExists(
      userId: category.userId,
      name: category.name,
      type: category.type,
    );

    if (exists) {
      throw Exception('Danh mục này đã tồn tại');
    }

    await _categories.add(category.toMap());
  }

  Future<void> updateCategory(CategoryModel category) async {
    final exists = await categoryNameExists(
      userId: category.userId,
      name: category.name,
      type: category.type,
      exceptCategoryId: category.id,
    );

    if (exists) {
      throw Exception('Danh mục này đã tồn tại');
    }

    final updated = category.copyWith(updatedAt: DateTime.now());

    await _categories.doc(category.id).update(updated.toMap());
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categories.doc(categoryId).delete();
  }

  bool isDefaultCategoryName(String name) {
    final allDefaults = [
      ...defaultExpenseCategories,
      ...defaultIncomeCategories,
    ];

    return allDefaults.any((item) => item['name'] == name);
  }
}
