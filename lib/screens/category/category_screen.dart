import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/category_model.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final CategoryService _categoryService = CategoryService();

  bool isInitializing = false;
  String selectedType = 'expense';

  Future<void> initDefaultCategories(String userId) async {
    setState(() {
      isInitializing = true;
    });

    try {
      await _categoryService.createDefaultCategoriesIfNeeded(userId);

      if (!mounted) return;

      showMessage('Đã khởi tạo danh mục mặc định');
    } catch (e) {
      showMessage('Khởi tạo danh mục thất bại');
    } finally {
      if (mounted) {
        setState(() {
          isInitializing = false;
        });
      }
    }
  }

  Future<void> deleteCategory(CategoryModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa danh mục'),
          content: Text(
            'Bạn có chắc muốn xóa danh mục "${category.name}" không?',
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

    try {
      await _categoryService.deleteCategory(category.id);

      if (!mounted) return;

      showMessage('Đã xóa danh mục');
    } catch (e) {
      showMessage('Xóa danh mục thất bại');
    }
  }

  void openForm({CategoryModel? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _CategoryFormSheet(
          category: category,
          initialType: selectedType,
          onSaved: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Bạn chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Danh mục')),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _categoryService.getCategoriesByUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? [];

          final filteredCategories = categories
              .where((item) => item.type == selectedType)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(
                  totalCount: categories.length,
                  expenseCount: categories
                      .where((item) => item.type == 'expense')
                      .length,
                  incomeCount: categories
                      .where((item) => item.type == 'income')
                      .length,
                ),
                const SizedBox(height: 20),
                _buildTypeFilter(),
                const SizedBox(height: 20),
                if (categories.isEmpty)
                  _buildEmptyState(user.uid)
                else
                  _buildCategoryList(filteredCategories),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          openForm();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildHeaderCard({
    required int totalCount,
    required int expenseCount,
    required int incomeCount,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cá nhân hóa phân loại thu chi',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Danh mục cá nhân',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Tổng',
                  value: '$totalCount',
                  icon: Icons.category_rounded,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Chi tiêu',
                  value: '$expenseCount',
                  icon: Icons.trending_down_rounded,
                  iconColor: AppColors.expense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderMiniCard(
                  title: 'Thu nhập',
                  value: '$incomeCount',
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.income,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeChip(
            title: 'Chi tiêu',
            selected: selectedType == 'expense',
            color: AppColors.expense,
            onTap: () {
              setState(() {
                selectedType = 'expense';
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeChip(
            title: 'Thu nhập',
            selected: selectedType == 'income',
            color: AppColors.income,
            onTap: () {
              setState(() {
                selectedType = 'income';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip({
    required String title,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String userId) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có danh mục',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn có thể khởi tạo danh mục mặc định hoặc tự tạo danh mục mới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              text: 'Tạo danh mục mặc định',
              isLoading: isInitializing,
              onPressed: () {
                if (isInitializing) return;
                initDefaultCategories(userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.filter_alt_off_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                selectedType == 'expense'
                    ? 'Chưa có danh mục chi tiêu'
                    : 'Chưa có danh mục thu nhập',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: categories.map((category) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildCategoryItem(category),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryItem(CategoryModel category) {
    final color = category.type == 'income'
        ? AppColors.income
        : AppColors.expense;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _getIconByName(category.iconName),
              color: color,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.type == 'income' ? 'Thu nhập' : 'Chi tiêu',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              openForm(category: category);
            },
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
          ),
          IconButton(
            onPressed: () {
              deleteCategory(category);
            },
            icon: const Icon(Icons.delete_rounded, color: AppColors.expense),
          ),
        ],
      ),
    );
  }

  IconData _getIconByName(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'salary':
        return Icons.payments_rounded;
      case 'bonus':
        return Icons.card_giftcard_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'gift':
        return Icons.redeem_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final CategoryModel? category;
  final String initialType;
  final VoidCallback onSaved;

  const _CategoryFormSheet({
    required this.category,
    required this.initialType,
    required this.onSaved,
  });

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final CategoryService _categoryService = CategoryService();
  final TextEditingController nameController = TextEditingController();

  String selectedType = 'expense';
  String selectedIconName = 'category';
  bool isSaving = false;

  final List<Map<String, dynamic>> iconOptions = const [
    {
      'label': 'Danh mục',
      'iconName': 'category',
      'icon': Icons.category_rounded,
    },
    {
      'label': 'Ăn uống',
      'iconName': 'restaurant',
      'icon': Icons.restaurant_rounded,
    },
    {
      'label': 'Mua sắm',
      'iconName': 'shopping',
      'icon': Icons.shopping_bag_rounded,
    },
    {
      'label': 'Di chuyển',
      'iconName': 'transport',
      'icon': Icons.directions_car_rounded,
    },
    {'label': 'Học tập', 'iconName': 'school', 'icon': Icons.school_rounded},
    {
      'label': 'Giải trí',
      'iconName': 'entertainment',
      'icon': Icons.movie_rounded,
    },
    {
      'label': 'Sức khỏe',
      'iconName': 'health',
      'icon': Icons.local_hospital_rounded,
    },
    {'label': 'Nhà cửa', 'iconName': 'home', 'icon': Icons.home_rounded},
    {'label': 'Lương', 'iconName': 'salary', 'icon': Icons.payments_rounded},
    {'label': 'Công việc', 'iconName': 'work', 'icon': Icons.work_rounded},
  ];

  @override
  void initState() {
    super.initState();

    final category = widget.category;

    selectedType = category?.type ?? widget.initialType;
    selectedIconName = category?.iconName ?? 'category';
    nameController.text = category?.name ?? '';
  }

  Future<void> save() async {
    final user = AuthService().currentUser;

    if (user == null) {
      showMessage('Bạn chưa đăng nhập');
      return;
    }

    final name = nameController.text.trim();

    if (name.isEmpty) {
      showMessage('Vui lòng nhập tên danh mục');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      if (widget.category == null) {
        final category = CategoryModel(
          id: '',
          userId: user.uid,
          name: name,
          type: selectedType,
          iconName: selectedIconName,
          createdAt: now,
          updatedAt: now,
        );

        await _categoryService.addCategory(category);
      } else {
        final updated = widget.category!.copyWith(
          name: name,
          type: selectedType,
          iconName: selectedIconName,
          updatedAt: now,
        );

        await _categoryService.updateCategory(updated);
      }

      if (!mounted) return;

      widget.onSaved();
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');

      if (message.contains('Danh mục này đã tồn tại')) {
        showMessage('Danh mục này đã tồn tại');
      } else {
        showMessage('Lưu danh mục thất bại');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
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
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(30),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEdit ? 'Sửa danh mục' : 'Thêm danh mục',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tạo danh mục riêng để phân loại giao dịch phù hợp với thói quen cá nhân.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeChip(
                        title: 'Chi tiêu',
                        selected: selectedType == 'expense',
                        color: AppColors.expense,
                        onTap: () {
                          setState(() {
                            selectedType = 'expense';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeChip(
                        title: 'Thu nhập',
                        selected: selectedType == 'income',
                        color: AppColors.income,
                        onTap: () {
                          setState(() {
                            selectedType = 'income';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: nameController,
                  hintText: 'Tên danh mục',
                  prefixIcon: Icons.category_rounded,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Chọn biểu tượng',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: iconOptions.map((item) {
                    final iconName = item['iconName'] as String;
                    final icon = item['icon'] as IconData;
                    final label = item['label'] as String;
                    final isSelected = selectedIconName == iconName;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedIconName = iconName;
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                AppButton(
                  text: isEdit ? 'Lưu thay đổi' : 'Tạo danh mục',
                  isLoading: isSaving,
                  onPressed: () {
                    if (isSaving) return;
                    save();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String title,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
