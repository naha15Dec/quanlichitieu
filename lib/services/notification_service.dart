import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int dailyExpenseReminderId = 1001;
  static const int budgetCheckReminderId = 1002;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: initSettings);

    await requestPermission();
  }

  Future<void> requestPermission() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      id: 999,
      title: 'Smart Expense',
      body: 'Thông báo đang hoạt động tốt.',
      notificationDetails: _notificationDetails(),
    );
  }

  Future<void> scheduleDailyExpenseReminder({
    required int hour,
    required int minute,
  }) async {
    await _scheduleDailyNotification(
      id: dailyExpenseReminderId,
      hour: hour,
      minute: minute,
      title: 'Đừng quên ghi chi tiêu hôm nay',
      body: 'Mở Smart Expense để cập nhật các khoản thu chi trong ngày nhé.',
    );
  }

  Future<void> scheduleBudgetCheckReminder({
    required int hour,
    required int minute,
  }) async {
    await _scheduleDailyNotification(
      id: budgetCheckReminderId,
      hour: hour,
      minute: minute,
      title: 'Kiểm tra ngân sách hôm nay',
      body: 'Xem lại mức chi tiêu để tránh vượt ngân sách tháng này.',
    );
  }

  Future<void> cancelDailyExpenseReminder() async {
    await _notifications.cancel(id: dailyExpenseReminderId);
  }

  Future<void> cancelBudgetCheckReminder() async {
    await _notifications.cancel(id: budgetCheckReminderId);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour: hour, minute: minute),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  NotificationDetails _notificationDetails() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'smart_expense_reminders',
          'Smart Expense Reminders',
          channelDescription: 'Nhắc nhở ghi chi tiêu và kiểm tra ngân sách',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }
}
