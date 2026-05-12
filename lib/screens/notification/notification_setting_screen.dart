import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../services/notification_service.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() =>
      _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  static const String expenseReminderKey = 'expense_reminder_enabled';
  static const String budgetReminderKey = 'budget_reminder_enabled';

  static const String expenseReminderHourKey = 'expense_reminder_hour';
  static const String expenseReminderMinuteKey = 'expense_reminder_minute';

  static const String budgetReminderHourKey = 'budget_reminder_hour';
  static const String budgetReminderMinuteKey = 'budget_reminder_minute';

  bool isLoading = true;
  bool expenseReminderEnabled = false;
  bool budgetReminderEnabled = false;

  TimeOfDay expenseReminderTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay budgetReminderTime = const TimeOfDay(hour: 19, minute: 30);

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final expenseHour = prefs.getInt(expenseReminderHourKey) ?? 20;
    final expenseMinute = prefs.getInt(expenseReminderMinuteKey) ?? 0;

    final budgetHour = prefs.getInt(budgetReminderHourKey) ?? 19;
    final budgetMinute = prefs.getInt(budgetReminderMinuteKey) ?? 30;

    setState(() {
      expenseReminderEnabled = prefs.getBool(expenseReminderKey) ?? false;
      budgetReminderEnabled = prefs.getBool(budgetReminderKey) ?? false;

      expenseReminderTime = TimeOfDay(hour: expenseHour, minute: expenseMinute);

      budgetReminderTime = TimeOfDay(hour: budgetHour, minute: budgetMinute);

      isLoading = false;
    });
  }

  Future<void> toggleExpenseReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      expenseReminderEnabled = value;
    });

    await prefs.setBool(expenseReminderKey, value);

    if (value) {
      await NotificationService.instance.scheduleDailyExpenseReminder(
        hour: expenseReminderTime.hour,
        minute: expenseReminderTime.minute,
      );

      showMessage(
        'Đã bật nhắc ghi chi tiêu lúc ${formatTime(expenseReminderTime)}',
      );
    } else {
      await NotificationService.instance.cancelDailyExpenseReminder();
      showMessage('Đã tắt nhắc ghi chi tiêu');
    }
  }

  Future<void> toggleBudgetReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      budgetReminderEnabled = value;
    });

    await prefs.setBool(budgetReminderKey, value);

    if (value) {
      await NotificationService.instance.scheduleBudgetCheckReminder(
        hour: budgetReminderTime.hour,
        minute: budgetReminderTime.minute,
      );

      showMessage(
        'Đã bật nhắc kiểm tra ngân sách lúc ${formatTime(budgetReminderTime)}',
      );
    } else {
      await NotificationService.instance.cancelBudgetCheckReminder();
      showMessage('Đã tắt nhắc kiểm tra ngân sách');
    }
  }

  Future<void> pickExpenseReminderTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: expenseReminderTime,
      helpText: 'Chọn giờ nhắc ghi chi tiêu',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (pickedTime == null) return;

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      expenseReminderTime = pickedTime;
    });

    await prefs.setInt(expenseReminderHourKey, pickedTime.hour);
    await prefs.setInt(expenseReminderMinuteKey, pickedTime.minute);

    if (expenseReminderEnabled) {
      await NotificationService.instance.cancelDailyExpenseReminder();
      await NotificationService.instance.scheduleDailyExpenseReminder(
        hour: pickedTime.hour,
        minute: pickedTime.minute,
      );
    }

    showMessage('Đã cập nhật giờ nhắc ghi chi tiêu');
  }

  Future<void> pickBudgetReminderTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: budgetReminderTime,
      helpText: 'Chọn giờ nhắc kiểm tra ngân sách',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (pickedTime == null) return;

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      budgetReminderTime = pickedTime;
    });

    await prefs.setInt(budgetReminderHourKey, pickedTime.hour);
    await prefs.setInt(budgetReminderMinuteKey, pickedTime.minute);

    if (budgetReminderEnabled) {
      await NotificationService.instance.cancelBudgetCheckReminder();
      await NotificationService.instance.scheduleBudgetCheckReminder(
        hour: pickedTime.hour,
        minute: pickedTime.minute,
      );
    }

    showMessage('Đã cập nhật giờ nhắc kiểm tra ngân sách');
  }

  Future<void> testNotification() async {
    await NotificationService.instance.showTestNotification();

    showMessage(
      'Đã gửi thông báo thử. Hãy kiểm tra thanh thông báo trên thiết bị.',
    );
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nhắc nhở')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildReminderCard(),
            const SizedBox(height: 20),
            _buildTestCard(),
          ],
        ),
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
          Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(height: 18),
          Text(
            'Nhắc nhở thông minh',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Thiết lập thông báo để ghi chi tiêu đều đặn và kiểm soát ngân sách tốt hơn.',
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

  Widget _buildReminderCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cài đặt nhắc nhở',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Các nhắc nhở được xử lý trên thiết bị, giúp bạn duy trì thói quen ghi chép chi tiêu.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildReminderItem(
            icon: Icons.edit_note_rounded,
            title: 'Nhắc ghi chi tiêu',
            subtitle: 'Mỗi ngày lúc ${formatTime(expenseReminderTime)}',
            value: expenseReminderEnabled,
            color: AppColors.primary,
            onChanged: toggleExpenseReminder,
            onTimeTap: pickExpenseReminderTime,
          ),
          const Divider(height: 30),
          _buildReminderItem(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Nhắc kiểm tra ngân sách',
            subtitle: 'Mỗi ngày lúc ${formatTime(budgetReminderTime)}',
            value: budgetReminderEnabled,
            color: AppColors.warning,
            onChanged: toggleBudgetReminder,
            onTimeTap: pickBudgetReminderTime,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
    required VoidCallback onTimeTap,
  }) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: InkWell(
            onTap: onTimeTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTestCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kiểm tra thông báo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bấm thử để kiểm tra thiết bị đã cấp quyền hiển thị thông báo cho ứng dụng hay chưa.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: testNotification,
              icon: const Icon(Icons.notifications_rounded),
              label: const Text('Gửi thông báo thử'),
            ),
          ),
        ],
      ),
    );
  }
}
